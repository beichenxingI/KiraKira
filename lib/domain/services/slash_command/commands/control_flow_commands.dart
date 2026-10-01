/// Control flow command family: if/else/while/times/let/var/run.
/// Comparison and loop semantics match ST variables.js
/// parseBooleanOperands/evalBoolean/MAX_LOOPS.
library;

import 'dart:convert';

import 'package:kirakira/domain/services/variables_service.dart';

import '../slash_ast.dart';
import '../slash_command.dart';
import '../slash_parser.dart';
import '../slash_runner.dart';
import 'variable_commands.dart' show slashPipeString;

const int _maxLoops = 100;

/// Operand resolution (ST parseBooleanOperands.getOperand):
/// number literal to scope variable to chat variable to global variable to string literal.
Object? _resolveOperand(String? raw, SlashArgs args) {
  if (raw == null) return null;
  if (raw.isEmpty) return '';
  final n = raw.trim().isNotEmpty ? num.tryParse(raw) : null;
  if (n != null) return n;

  if (args.scope.existsVariable(raw)) {
    return args.scope.getVariable(raw) ?? '';
  }
  final svc = VariablesService.instance;
  final chatId = args.env?.chatId;
  if (chatId != null && svc.existsLocalVariable(chatId, raw)) {
    return svc.getLocalVariable(chatId, raw);
  }
  if (svc.existsGlobalVariable(raw)) {
    return svc.getGlobalVariable(raw);
  }
  return raw;
}

/// Port of ST evalBoolean.
bool evalBooleanRule(String? rule, Object? a, Object? b) {
  if (a == null) return false;
  final aNum = a is num;
  final bNum = b is num;
  final r = rule ?? 'eq';

  if (b == null) {
    // No right value: truthiness check (rule can only be default or not)
    final resultOnTruthy = r != 'not';
    final s = a.toString().toLowerCase();
    if (s == 'true' || s == 'on') return resultOnTruthy;
    if (s == 'false' || s == 'off' || s == '') return !resultOnTruthy;
    if (a is num) return a != 0 ? resultOnTruthy : !resultOnTruthy;
    return a.toString().isNotEmpty ? resultOnTruthy : !resultOnTruthy;
  }

  if (aNum && bNum) {
    final x = a;
    final y = b;
    switch (r) {
      case 'gt':
        return x > y;
      case 'gte':
        return x >= y;
      case 'lt':
        return x < y;
      case 'lte':
        return x <= y;
      case 'eq':
        return x == y;
      case 'neq':
        return x != y;
      case 'in':
      case 'nin':
        break; // numbers fall back to string comparison (e.g. 12345 contains 45)
      default:
        return false;
    }
  }

  // Case-insensitive string comparison
  final as = a is String ? a.toLowerCase() : slashOperandToString(a);
  final bs = b is String ? b.toLowerCase() : slashOperandToString(b);
  switch (r) {
    case 'in':
      return as.contains(bs);
    case 'nin':
      return !as.contains(bs);
    case 'eq':
      return as == bs;
    case 'neq':
      return as != bs;
    case 'gt':
      return _numOf(a) > _numOf(b);
    case 'gte':
      return _numOf(a) >= _numOf(b);
    case 'lt':
      return _numOf(a) < _numOf(b);
    case 'lte':
      return _numOf(a) <= _numOf(b);
    default:
      return false;
  }
}

num _numOf(Object? v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);

String slashOperandToString(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  try {
    return jsonEncode(v).toLowerCase();
  } catch (_) {
    return v.toString().toLowerCase();
  }
}

/// Runs then/else/loop bodies: closures via executeClosure; strings executed as sub-scripts.
Future<SlashResult> _runBody(
  Object? body,
  SlashArgs args, {
  Map<String, Object?>? macros,
}) async {
  if (body is SlashClosureNode) {
    return SlashRunner.executeClosure(body,
        parentScope: args.scope,
        env: args.env,
        abort: args.ctx.abortController,
        initialMacros: macros);
  }
  final text = body?.toString() ?? '';
  if (text.trim().isEmpty) return const SlashResult();
  return SlashRunner.execute(text,
      scope: args.scope, env: args.env, pipeIn: slashPipeString(args.scope.pipe));
}

/// Registers control flow commands (idempotent).
void registerControlFlowSlashCommands() {
  // /if left= right= rule= {:then:} (else={:...:} or a second closure)
  SlashCommandRegistry.register(SlashCommand(
    name: 'if',
    splitUnnamedArgument: true,
    callback: (args) async {
      final a = _resolveOperand(args.namedString('left'), args);
      final b = _resolveOperand(args.namedString('right'), args);
      final result = evalBooleanRule(args.namedString('rule'), a, b);

      final Object? thenBody = args.unnamed.isNotEmpty ? args.unnamed.first : null;
      // Compatible with ST's official named argument else= and the community double-closure form {:then:} {:else:}
      Object? elseBody = args.named['else'];
      if (args.unnamed.length > 1) {
        elseBody = args.unnamed.elementAt(1);
      }

      if (result && thenBody != null) {
        final r = await _runBody(thenBody, args);
        return r.pipe;
      }
      if (!result && elseBody != null) {
        final r = await _runBody(elseBody, args);
        return r.pipe;
      }
      return '';
    },
  ));

  // /else {:body:} (sugar for /if; when run standalone, executes the body or passes the pipe through)
  SlashCommandRegistry.register(SlashCommand(
    name: 'else',
    splitUnnamedArgument: true,
    callback: (args) async {
      final body = args.unnamed.isNotEmpty ? args.unnamed.first : null;
      if (body != null) {
        final r = await _runBody(body, args);
        return r.pipe;
      }
      return slashPipeString(args.scope.pipe);
    },
  ));

  // /while left= right= rule= guard=off {:body:}
  SlashCommandRegistry.register(SlashCommand(
    name: 'while',
    splitUnnamedArgument: true,
    callback: (args) async {
      final guardOff =
          (args.namedString('guard') ?? 'off').toLowerCase() == 'on';
      final iterations = guardOff ? 1 << 30 : _maxLoops;
      final body = args.unnamed.isNotEmpty ? args.unnamed.first : null;
      var last = '';
      for (var i = 0; i < iterations; i++) {
        // Condition re-read each iteration (operands resolved by variable name, not macro snapshots)
        final a = _resolveOperand(args.namedString('left'), args);
        final b = _resolveOperand(args.namedString('right'), args);
        if (!evalBooleanRule(args.namedString('rule'), a, b)) break;
        if (body == null) break;
        final r = await _runBody(body, args);
        last = r.pipe;
        if (r.isAborted || r.isBreak) break;
      }
      return last;
    },
  ));

  // /times n {:body:} ({{timesIndex}} available to the body)
  SlashCommandRegistry.register(SlashCommand(
    name: 'times',
    splitUnnamedArgument: true,
    splitUnnamedArgumentCount: 1,
    callback: (args) async {
      final repeats = int.tryParse(
              args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '0') ??
          0;
      final guardOff =
          (args.namedString('guard') ?? 'off').toLowerCase() == 'on';
      final limit = guardOff ? 1 << 30 : _maxLoops;
      final iterations = repeats < 0 ? 0 : (repeats > limit ? limit : repeats);
      Object? body;
      if (args.unnamed.length > 1) body = args.unnamed.elementAt(1);
      var last = '';
      for (var i = 0; i < iterations; i++) {
        if (body == null) break;
        final r = await _runBody(body, args, macros: {'timesIndex': i});
        last = r.pipe;
        if (r.isAborted || r.isBreak) break;
      }
      return last;
    },
  ));

  // /let key=v (current scope)
  SlashCommandRegistry.register(SlashCommand(
    name: 'let',
    splitUnnamedArgument: true,
    splitUnnamedArgumentCount: 1,
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      if (key.isEmpty) return '';
      if (args.hasUnnamedArg && args.unnamed.length > 1) {
        final v = args.unnamed.elementAt(1);
        args.scope.letVariable(key, v);
        return slashPipeString(v);
      }
      args.scope.letVariable(key);
      return '';
    },
  ));

  // /var key=v (set along the parent chain; get when no value given)
  SlashCommandRegistry.register(SlashCommand(
    name: 'var',
    splitUnnamedArgument: true,
    splitUnnamedArgumentCount: 1,
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      if (key.isEmpty) return '';
      if (args.hasUnnamedArg && args.unnamed.length > 1) {
        final v = args.unnamed.elementAt(1);
        args.scope.setVariable(key, v);
        return slashPipeString(v);
      }
      return slashPipeString(args.scope.getVariable(key));
    },
  ));

  // /run closure|sub-script (aliases: call, exec)
  SlashCommandRegistry.register(SlashCommand(
    name: 'run',
    aliases: ['call', 'exec'],
    callback: (args) async {
      if (args.unnamed.isEmpty) return '';
      final target = args.unnamed.first;
      if (target is SlashClosureNode) {
        final provided = args.unnamed.skip(1).toList(); // positional arguments bind formal parameters in order
        final r = await SlashRunner.executeClosure(target,
            parentScope: args.scope,
            env: args.env,
            abort: args.ctx.abortController,
            providedArgs: provided);
        return r.pipe;
      }
      // String: execute as a sub-script
      final text = target.toString();
      if (text.trim().isEmpty) return '';
      final r = await SlashRunner.execute(text,
          scope: args.scope,
          env: args.env,
          pipeIn: slashPipeString(args.scope.pipe));
      return r.pipe;
    },
  ));

  // closure-serialize / closure-deserialize
  SlashCommandRegistry.register(SlashCommand(
    name: 'closure-serialize',
    callback: (args) async {
      if (args.unnamed.isEmpty) return '';
      final v = args.unnamed.first;
      if (v is SlashClosureNode) return v.rawText;
      return v.toString();
    },
  ));
  SlashCommandRegistry.register(SlashCommand(
    name: 'closure-deserialize',
    callback: (args) async {
      if (args.unnamed.isEmpty) return '';
      // Parse back into a closure; the platform has no closure pipe type, so serialize back to raw text for further passing
      final cl = SlashParser(args.unnamed.first.toString()).parse();
      return cl.rawText;
    },
  ));
}
