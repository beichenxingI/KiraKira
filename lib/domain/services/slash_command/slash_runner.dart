/// [P6-3] 斜杠命令执行器:解析 + 依次执行,处理管道/pipe 注入/闭包/abort/break。
/// 语义对齐 ST SlashCommandClosure.executeDirect。
library;

import 'dart:convert';

import 'slash_ast.dart';
import 'slash_command.dart';
import 'slash_parser.dart';
import 'slash_scope.dart';

/// 执行结果(对齐 ST SlashCommandClosureResult)。
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

/// 全局宏解析钩子:runner 先替换 {{pipe}}/{{var::}}/{{timesIndex}},
/// 再把剩余文本交给此钩子处理({{getvar::}} 等 ST 变量宏)。
/// 由宿主(webview_chat_stage)注入,通常接 VariablesService.processVariableMacrosSync。
typedef SlashMacroResolver = String Function(String input);

class SlashRunner {
  SlashRunner._();

  static SlashMacroResolver? globalMacroResolver;

  /// 执行入口。返回管道结果,绝不抛异常(错误封装在 isError)。
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

  /// 执行一个闭包。
  /// [parentScope] 的 pipe 会带入;闭包形参按 [providedArgs] 位置绑定。
  static Future<SlashResult> executeClosure(
    SlashClosureNode closure, {
    SlashScope? parentScope,
    SlashEnv? env,
    SlashAbortController? abort,
    List<Object?>? providedArgs,
  }) async {
    final scope = SlashScope();
    if (parentScope != null) {
      scope.parent = parentScope;
      scope.pipe = parentScope.pipe;
    }
    final ctx = SlashExecContext(abort);

    // 闭包形参绑定:调用方提供的按位置,其余用声明时的默认值
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

      // 命名参数:解析值(闭包立即执行则求值,否则原样)
      for (final a in ex.namedArgumentList) {
        args.named[a.name] =
            await _resolveValue(a.value, scope, env, ctx.abortController);
      }

      // 无名参数
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

      // 执行
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

      // /break:断当前闭包,break 已由回调把值写入 pipe
      if (ctx.breakRequested) {
        breaked = true;
      }

      // 管道更新(闭包结果经 /run 等已是字符串;回调返回值字符串化)
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

  // ── 内部 ──

  /// 解析参数值:立即闭包求值,延迟闭包原样传,字符串做宏替换。
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

  /// 宏替换:{{pipe}} → {{var::name}}/{{var::name::index}} → 域内宏 → 全局钩子。
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

    // 域内宏(如 {{timesIndex}})
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
