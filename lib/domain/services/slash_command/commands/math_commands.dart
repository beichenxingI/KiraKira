/// [P6-4/P2] 数学命令族:计算/统计/随机。语义对齐 ST variables.js 数学段。
/// 操作数解析与 /if 同源:数字字面量 → 作用域变量 → chat变量 → global变量 → 字面量。
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:kirakira/domain/services/variables_service.dart';

import '../slash_ast.dart';
import '../slash_command.dart';

num _numOf(Object? v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

/// 数字 pipe 化:整数值去小数点(ST 的 String(Number(x)) 语义)。
String numToString(num v) {
  if (v.isFinite && v % 1 == 0) {
    final i = v.toInt();
    return i.toString();
  }
  return v.toString();
}

/// 操作数解析(与 /if 同序),供数学命令用。
Object? _resolveOperand(Object? raw, SlashArgs args) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return '';
  final n = s.trim().isNotEmpty ? num.tryParse(s) : null;
  if (n != null) return n;
  if (args.scope.existsVariable(s)) return args.scope.getVariable(s) ?? '';
  final svc = VariablesService.instance;
  final chatId = args.env?.chatId;
  if (chatId != null && svc.existsLocalVariable(chatId, s)) {
    return svc.getLocalVariable(chatId, s);
  }
  if (svc.existsGlobalVariable(s)) return svc.getGlobalVariable(s);
  return raw;
}

/// 值列表:split 无名参数逐个解析;单项若是 JSON 数组则展开。
List<num> _numberList(SlashArgs args) {
  final resolved =
      args.unnamed.map((e) => _resolveOperand(e, args)).toList();
  if (resolved.length == 1 && resolved.first is String) {
    try {
      final decoded = jsonDecode(resolved.first as String);
      if (decoded is List) {
        return decoded.map((e) => _numOf(e)).toList();
      }
    } catch (_) {}
  }
  return resolved.map(_numOf).toList();
}

void _registerBinary(
    String name, num Function(num a, num b) op, bool divLike) {
  SlashCommandRegistry.register(SlashCommand(
    name: name,
    splitUnnamedArgument: true,
    callback: (args) async {
      final list = _numberList(args);
      if (list.isEmpty) return '0';
      if (list.length == 1) return numToString(op(0, list.first));
      var acc = list.first;
      for (var i = 1; i < list.length; i++) {
        if (divLike && list[i] == 0) return ''; // 除零保护
        acc = op(acc, list[i]);
      }
      return numToString(acc);
    },
  ));
}

void _registerUnary(String name, num Function(num v) op) {
  SlashCommandRegistry.register(SlashCommand(
    name: name,
    callback: (args) async {
      final list = _numberList(args);
      if (list.isEmpty) return '0';
      return numToString(op(list.first));
    },
  ));
}

/// 注册数学命令(幂等)。
void registerMathSlashCommands() {
  _registerBinary('add', (a, b) => a + b, false);
  _registerBinary('sub', (a, b) => a - b, false);
  _registerBinary('mul', (a, b) => a * b, false);
  _registerBinary('div', (a, b) => a / b, true);
  _registerBinary('mod', (a, b) => b == 0 ? 0 : a.remainder(b), false);
  _registerBinary('pow', (a, b) => math.pow(a, b), false);
  _registerBinary('max', (a, b) => math.max(a, b), false);
  _registerBinary('min', (a, b) => math.min(a, b), false);

  _registerUnary('abs', (v) => v.abs());
  _registerUnary('round', (v) => v.roundToDouble());
  _registerUnary('sqrt', (v) => v < 0 ? double.nan : math.sqrt(v));
  _registerUnary('log', (v) => v <= 0 ? double.nan : math.log(v));
  _registerUnary('sin', (v) => math.sin(v));
  _registerUnary('cos', (v) => math.cos(v));

  // /len:字符串字符数 / 列表项数 / 字典键数
  SlashCommandRegistry.register(SlashCommand(
    name: 'len',
    aliases: ['length'],
    callback: (args) async {
      if (args.unnamed.isEmpty) return '0';
      final v = args.unnamed.first;
      if (v is SlashClosureNode) return v.rawText.length.toString();
      final s = v.toString();
      if (s.startsWith('[') || s.startsWith('{')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List || decoded is Map) {
            return decoded.length.toString();
          }
        } catch (_) {}
      }
      return s.length.toString();
    },
  ));

  // /sort:列表排序(JSON 数组)
  SlashCommandRegistry.register(SlashCommand(
    name: 'sort',
    callback: (args) async {
      if (args.unnamed.isEmpty) return '[]';
      try {
        final decoded = jsonDecode(args.unnamed.first.toString());
        if (decoded is List) {
          final nums = decoded.whereType<num>().toList();
          if (nums.length == decoded.length) {
            nums.sort();
            return jsonEncode(nums);
          }
          final strs = decoded.map((e) => e.toString()).toList()..sort();
          return jsonEncode(strs);
        }
      } catch (_) {}
      return args.unnamed.first.toString();
    },
  ));

  // /keysort:字典键排序(JSON 对象 → 排序后的键数组)
  SlashCommandRegistry.register(SlashCommand(
    name: 'keysort',
    callback: (args) async {
      if (args.unnamed.isEmpty) return '[]';
      try {
        final decoded = jsonDecode(args.unnamed.first.toString());
        if (decoded is Map) {
          final keys = decoded.keys.map((e) => e.toString()).toList()..sort();
          return jsonEncode(keys);
        }
      } catch (_) {}
      return '[]';
    },
  ));

  // /rand from= to= round=
  SlashCommandRegistry.register(SlashCommand(
    name: 'rand',
    callback: (args) async {
      final from = num.tryParse(args.namedString('from') ?? '0') ?? 0;
      var to = num.tryParse(args.namedString('to') ?? '') ?? 1;
      // ST 语义:to 缺省时用无名参数,再缺省 1
      if (args.namedString('to') == null && args.unnamed.isNotEmpty) {
        to = _numOf(_resolveOperand(args.unnamed.first, args));
      }
      final lo = from <= to ? from : to;
      final hi = from <= to ? to : from;
      var v = lo + (hi - lo) * math.Random().nextDouble();
      switch (args.namedString('round')) {
        case 'ceil':
          v = v.ceilToDouble();
          break;
        case 'floor':
          v = v.floorToDouble();
          break;
        case 'round':
          v = v.roundToDouble();
          break;
      }
      return numToString(v);
    },
  ));
}
