/// Math command family: arithmetic/statistics/random. Semantics match the math
/// section of ST variables.js.
/// Operand resolution shares the same source as /if: number literal to scope
/// variable to chat variable to global variable to literal.
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

/// Numeric pipe: integer values drop the decimal point (ST's String(Number(x)) semantics).
String numToString(num v) {
  if (v.isFinite && v % 1 == 0) {
    final i = v.toInt();
    return i.toString();
  }
  return v.toString();
}

/// Operand resolution (same order as /if), used by math commands.
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

/// Number list: split unnamed arguments resolved one by one; a single JSON array item is expanded.
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
        if (divLike && list[i] == 0) return ''; // divide-by-zero guard
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

/// Registers math commands (idempotent).
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

  // /len: string character count / list item count / dict key count
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

  // /sort: list sorting (JSON array)
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

  // /keysort: dict key sorting (JSON object to sorted key array)
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
      // ST semantics: when to is absent, use the unnamed argument, then default 1
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
