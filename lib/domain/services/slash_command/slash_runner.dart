/// Slash command executor: parse + sequential execution, handling pipes,
/// pipe injection, closures, abort and break.
/// Semantics match ST SlashCommandClosure.executeDirect.
library;

import 'dart:convert';

import 'slash_ast.dart';
import 'slash_command.dart';
import 'slash_parser.dart';
import 'slash_scope.dart';

/// Execution result (matches ST SlashCommandClosureResult).
class SlashResult {
  const SlashResult({
    this.pipe = '',
    this.isAborted = false,
    this.isBreak = false,
    this.isError = false,
    this.errorMessage,
  });

  final String pipe;
  final bool isAborted;
  final bool isBreak;
  final bool isError;
  final String? errorMessage;

  Map<String, dynamic> toMap() => {
        'pipe': pipe,
        'isAborted': isAborted,
        'isBreak': isBreak,
        'isError': isError,
        'errorMessage': errorMessage,
      };
}

/// Global macro resolution hook: the runner first replaces {{pipe}}/{{var::}}/{{timesIndex}},
/// then hands the remaining text to this hook (ST variable macros such as {{getvar::}}).
/// Injected by the host (webview_chat_stage), usually bound to
/// VariablesService.processVariableMacrosSync.
typedef SlashMacroResolver = String Function(String input);

class SlashRunner {
  SlashRunner._();

  static SlashMacroResolver? globalMacroResolver;

  /// Execution entry point. Returns the pipe result and never throws
  /// (errors are wrapped in isError).
  static Future<SlashResult> execute(
    String text, {
    SlashScope? scope,
    String? pipeIn,
    SlashEnv? env,
  }) async {
    if (text.trim().isEmpty) {
      return SlashResult(pipe: pipeIn ?? '');
    }
    try {
      final root = SlashParser(text).parse();
      final s = SlashScope()..pipe = pipeIn;
      if (scope != null) s.parent = scope;
      return await executeClosure(root, parentScope: s, env: env);
    } catch (e) {
      return SlashResult(pipe: pipeIn ?? '', isError: true, errorMessage: e.toString());
    }
  }

  /// Executes a closure.
  /// [parentScope]'s pipe is carried in; closure formal parameters are bound
  /// by position from [providedArgs]; [initialMacros] pre-seeds scope macros
  /// (e.g. {{timesIndex}} from /times).
  static Future<SlashResult> executeClosure(
    SlashClosureNode closure, {
    SlashScope? parentScope,
    SlashEnv? env,
    SlashAbortController? abort,
    List<Object?>? providedArgs,
    Map<String, Object?>? initialMacros,
  }) async {
    final scope = SlashScope();
    if (parentScope != null) {
      scope.parent = parentScope;
      scope.pipe = parentScope.pipe;
    }
    if (initialMacros != null) {
      scope.macros.addAll(initialMacros);
    }
    final ctx = SlashExecContext(abort);

    // Closure parameter binding: caller-provided values by position, others use declared defaults
    for (var i = 0; i < closure.argumentList.length; i++) {
      final arg = closure.argumentList[i];
      Object? v;
      if (providedArgs != null && i < providedArgs.length) {
        v = providedArgs[i];
      } else if (arg.value is SlashClosureNode) {
        v = arg.value;
      } else {
        v = _substituteMacros(arg.value.toString(), scope);
      }
      scope.letVariable(arg.name, v);
    }

    var breaked = false;
    var isFirst = true;

    for (final ex in closure.executorList) {
      if (ctx.abortController.aborted || breaked) break;

      final cmd = SlashCommandRegistry.get(ex.name);
      if (cmd == null) {
        return SlashResult(
          pipe: _pipeToString(scope.pipe),
          isAborted: ctx.abortController.aborted,
          isBreak: breaked,
          isError: true,
          errorMessage: 'Unknown command: /${ex.name}',
        );
      }

      final args = SlashArgs(scope: scope, ctx: ctx, env: env);

      // Named arguments: resolve values (immediate closures are evaluated, others passed as-is)
      for (final a in ex.namedArgumentList) {
        args.named[a.name] =
            await _resolveValue(a.value, scope, env, ctx.abortController);
      }

      // Unnamed arguments
      if (ex.unnamedArgumentList.isEmpty) {
        if (!isFirst && ex.injectPipe) {
          args.unnamed = [_pipeToString(scope.pipe)];
          args.hasUnnamedArg = true;
        }
      } else {
        final parts = <Object?>[];
        for (final a in ex.unnamedArgumentList) {
          parts.add(
              await _resolveValue(a.value, scope, env, ctx.abortController));
        }
        if (!cmd.splitUnnamedArgument) {
          if (parts.length == 1) {
            args.unnamed = parts;
          } else if (!parts.any((p) => p is SlashClosureNode)) {
            args.unnamed = [parts.map(_valueToString).join('')];
          } else {
            args.unnamed = parts;
          }
        } else {
          args.unnamed = parts;
        }
        args.hasUnnamedArg = args.unnamed.isNotEmpty;
      }

      // Execute
      Object? result;
      try {
        result = await cmd.callback(args);
      } catch (e) {
        return SlashResult(
          pipe: _pipeToString(scope.pipe),
          isAborted: ctx.abortController.aborted,
          isBreak: breaked,
          isError: true,
          errorMessage: '/${ex.name}: $e',
        );
      }

      // /break: stops the current closure; the callback already wrote the value to pipe
      if (ctx.breakRequested) {
        breaked = true;
      }

      // Pipe update (closure results via /run etc. are already strings; callback return values are stringified)
      if (result is SlashResult) {
        scope.pipe = result.pipe;
        if (result.isAborted) ctx.abortController.abort(result.errorMessage ?? 'aborted');
        if (result.isBreak) breaked = true;
      } else {
        scope.pipe = result;
      }

      if (ctx.abortController.aborted) {
        return SlashResult(
          pipe: _pipeToString(scope.pipe),
          isAborted: true,
          isBreak: breaked,
        );
      }
      isFirst = false;
    }

    return SlashResult(
      pipe: _pipeToString(scope.pipe),
      isAborted: ctx.abortController.aborted,
      isBreak: breaked,
    );
  }

  // Internals

  /// Resolves an argument value: immediate closures are evaluated, deferred
  /// closures are passed as-is, strings get macro substitution.
  static Future<Object?> _resolveValue(
    Object v,
    SlashScope scope,
    SlashEnv? env,
    SlashAbortController abort,
  ) async {
    if (v is SlashClosureNode) {
      if (v.executeNow) {
        final r = await executeClosure(v,
            parentScope: SlashScope()..parent = scope,
            env: env,
            abort: abort);
        return r.pipe;
      }
      return v;
    }
    return _substituteMacros(v.toString(), scope);
  }

  /// Macro substitution: {{pipe}} to {{var::name}}/{{var::name::index}} to
  /// scope macros to global hook.
  static String _substituteMacros(String text, SlashScope scope) {
    if (!text.contains('{{')) {
      return text;
    }
    var result = text;

    result = result.replaceAllMapped(
        RegExp(r'{{\s*pipe\s*}}', caseSensitive: false), (_) {
      return _pipeToString(scope.pipe);
    });

    result = result.replaceAllMapped(
      RegExp(r'{{\s*var::([^}]+?)::([^}]+?)\s*}}', caseSensitive: false),
      (m) => _scopeVarLookup(scope, m.group(1)!.trim(), m.group(2)!.trim()),
    );
    result = result.replaceAllMapped(
      RegExp(r'{{\s*var::([^}:]+?)\s*}}', caseSensitive: false),
      (m) => _scopeVarLookup(scope, m.group(1)!.trim(), null),
    );

    // Scope-local macros (e.g. {{timesIndex}})
    result = result.replaceAllMapped(
        RegExp(r'{{\s*(\w+)\s*}}', caseSensitive: false), (m) {
      final v = scope.getMacro(m.group(1)!);
      return v == null ? m.group(0)! : _valueToString(v);
    });

    final resolver = globalMacroResolver;
    if (resolver != null) {
      try {
        result = resolver(result);
      } catch (_) {}
    }
    return result;
  }

  static String _scopeVarLookup(SlashScope scope, String name, String? index) {
    if (!scope.existsVariable(name)) return '';
    var v = scope.getVariable(name);
    if (index != null) {
      final numIndex = int.tryParse(index);
      try {
        final decoded = v is String ? jsonDecode(v) : v;
        if (decoded is List && numIndex != null) {
          v = numIndex < decoded.length ? decoded[numIndex] : '';
        } else if (decoded is Map) {
          v = decoded[index];
        }
      } catch (_) {}
    }
    return _valueToString(v);
  }

  static String _valueToString(Object? v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    if (v is SlashClosureNode) return v.rawText;
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }

  static String _pipeToString(Object? v) => _valueToString(v);
}
