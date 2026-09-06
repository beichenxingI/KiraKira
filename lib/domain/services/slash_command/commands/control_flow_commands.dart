/// [P6-4] 控制流命令族(P1):if/else/while/times/let/var/run。
/// 比较与循环语义对齐 ST variables.js 的 parseBooleanOperands/evalBoolean/MAX_LOOPS。
library;

import 'dart:convert';

import 'package:kirakira/domain/services/variables_service.dart';

import '../slash_ast.dart';
import '../slash_command.dart';
import '../slash_parser.dart';
import '../slash_runner.dart';
import 'variable_commands.dart' show slashPipeString;

const int _maxLoops = 100;

/// 操作数解析(ST parseBooleanOperands.getOperand):
/// 数字字面量 → 作用域变量 → chat变量 → global变量 → 字符串字面量。
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

/// ST evalBoolean 移植。
bool evalBooleanRule(String? rule, Object? a, Object? b) {
  if (a == null) return false;
  final aNum = a is num;
  final bNum = b is num;
  final r = rule ?? 'eq';

  if (b == null) {
    // 无右值:真值检查(rule 只能缺省或 not)
    final resultOnTruthy = r != 'not';
    final s = a.toString().toLowerCase();
    if (s == 'true' || s == 'on') return resultOnTruthy;
    if (s == 'false' || s == 'off' || s == '') return !resultOnTruthy;
    if (a is num) return a != 0 ? resultOnTruthy : !resultOnTruthy;
    return a.toString().isNotEmpty ? resultOnTruthy : !resultOnTruthy;
  }

  if (aNum && bNum) {
    final x = a as num;
    final y = b as num;
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
        break; // 数字回退字符串比较(如 12345 含 45)
      default:
        return false;
    }
  }

  // 大小写不敏感字符串比较
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

/// 执行 then/else/循环体:闭包 → executeClosure;字符串 → 当子脚本执行。
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
  if (text.trim().isEmpty) return SlashResult();
  return SlashRunner.execute(text,
      scope: args.scope, env: args.env, pipeIn: slashPipeString(args.scope.pipe));
}

/// 注册控制流命令(幂等)。
void registerControlFlowSlashCommands() {
  // ── /if left= right= rule= {:then:}(else={:...:} 或第二闭包) ──
  SlashCommandRegistry.register(SlashCommand(
    name: 'if',
    splitUnnamedArgument: true,
    callback: (args) async {
      final a = _resolveOperand(args.namedString('left'), args);
      final b = _resolveOperand(args.namedString('right'), args);
      final result = evalBooleanRule(args.namedString('rule'), a, b);

      Object? thenBody = args.unnamed.isNotEmpty ? args.unnamed.first : null;
      // 兼容 ST 官方命名参数 else= 与社区双闭包写法 {:then:} {:else:}
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

  // ── /else {:body:}(配合 /if 的糖;独立执行时执行体或透传) ──
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

  // ── /while left= right= rule= guard=off {:body:} ──
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
        // 条件每轮重读(操作数按变量名解析,非宏快照)
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

  // ── /times n {:body:}({{timesIndex}} 供体内使用) ──
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

  // ── /let key=v(当前域) ──
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

  // ── /var key=v(沿父链 set;无值则 get) ──
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

  // ── /run closure|子脚本(aliases: call, exec) ──
  SlashCommandRegistry.register(SlashCommand(
    name: 'run',
    aliases: ['call', 'exec'],
    callback: (args) async {
      if (args.unnamed.isEmpty) return '';
      final target = args.unnamed.first;
      if (target is SlashClosureNode) {
        final provided = args.unnamed.skip(1).toList(); // 位置参数按序绑形参
        final r = await SlashRunner.executeClosure(target,
            parentScope: args.scope,
            env: args.env,
            abort: args.ctx.abortController,
            providedArgs: provided);
        return r.pipe;
      }
      // 字符串:子脚本执行
      final text = target.toString();
      if (text.trim().isEmpty) return '';
      final r = await SlashRunner.execute(text,
          scope: args.scope,
          env: args.env,
          pipeIn: slashPipeString(args.scope.pipe));
      return r.pipe;
    },
  ));

  // ── closure-serialize / closure-deserialize ──
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
      // 解析回闭包;平台无闭包管道类型,序列化回原文供后续传递
      final cl = SlashParser(args.unnamed.first.toString()).parse();
      return cl.rawText;
    },
  ));
}
