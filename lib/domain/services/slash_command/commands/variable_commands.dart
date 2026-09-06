/// [P6-4] 变量命令族(P0)。语义对齐 ST variables.js。
/// 读写走 SlashEnv 钩子(宿主负责持久化+引擎同步),本地只读走 VariablesService。
library;

import 'dart:convert';

import 'package:kirakira/domain/services/variables_service.dart';

import '../slash_command.dart';
import '../slash_ast.dart';

/// pipe 字符串化:Map/List 转 JSON,其余 toString。
String slashPipeString(Object? v) {
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

/// 注册变量命令(幂等)。
void registerVariableSlashCommands() {
  final svc = VariablesService.instance;

  // ── chat 局部变量 ──
  SlashCommandRegistry.register(SlashCommand(
    name: 'setvar',
    aliases: ['setchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ?? args.namedString('name') ?? '';
      if (key.isEmpty) return '';
      final value = args.unnamed.isNotEmpty ? args.unnamed.first : '';
      final index = args.namedString('index');
      await args.env?.onSetVar?.call('chat', key, value,
          index: index, asType: args.namedString('as'));
      return slashPipeString(value);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'getvar',
    aliases: ['getchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      final index = args.namedString('index');
      final chatId = args.env?.chatId;
      if (key.isEmpty || chatId == null) return '';
      return slashPipeString(
          svc.getLocalVariable(chatId, key, index: index));
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'addvar',
    aliases: ['addchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ?? '';
      if (key.isEmpty) return '';
      final value = args.unnamed.isNotEmpty ? args.unnamed.first : '';
      final chatId = args.env?.chatId;
      if (chatId == null) return '';
      final next = svc.addLocalVariable(chatId, key, value);
      await args.env?.onSetVar?.call('chat', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'incvar',
    aliases: ['incchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      final chatId = args.env?.chatId;
      if (key.isEmpty || chatId == null) return '';
      final next = svc.incrementLocalVariable(chatId, key);
      await args.env?.onSetVar?.call('chat', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'decvar',
    aliases: ['decchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      final chatId = args.env?.chatId;
      if (key.isEmpty || chatId == null) return '';
      final next = svc.decrementLocalVariable(chatId, key);
      await args.env?.onSetVar?.call('chat', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'flushvar',
    aliases: ['flushchatvar'],
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      await args.env?.onDeleteVar?.call('chat', key.trim());
      return '';
    },
  ));

  // ── global 全局变量 ──
  SlashCommandRegistry.register(SlashCommand(
    name: 'setglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ?? args.namedString('name') ?? '';
      if (key.isEmpty) return '';
      final value = args.unnamed.isNotEmpty ? args.unnamed.first : '';
      final index = args.namedString('index');
      await args.env?.onSetVar?.call('global', key, value,
          index: index, asType: args.namedString('as'));
      return slashPipeString(value);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'getglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      final index = args.namedString('index');
      if (key.isEmpty) return '';
      return slashPipeString(svc.getGlobalVariable(key, index: index));
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'addglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ?? '';
      if (key.isEmpty) return '';
      final value = args.unnamed.isNotEmpty ? args.unnamed.first : '';
      final next = await svc.addGlobalVariable(key, value);
      await args.env?.onSetVar?.call('global', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'incglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      if (key.isEmpty) return '';
      final next = await svc.incrementGlobalVariable(key);
      await args.env?.onSetVar?.call('global', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'decglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      if (key.isEmpty) return '';
      final next = await svc.decrementGlobalVariable(key);
      await args.env?.onSetVar?.call('global', key, next);
      return slashPipeString(next);
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'flushglobalvar',
    callback: (args) async {
      final key = args.namedString('key') ??
          (args.unnamed.isNotEmpty ? args.unnamed.first.toString() : '');
      await args.env?.onDeleteVar?.call('global', key.trim());
      return '';
    },
  ));

  // ── listvar:局部变量名清单(JSON 数组) ──
  SlashCommandRegistry.register(SlashCommand(
    name: 'listvar',
    aliases: ['listchatvar'],
    callback: (args) async {
      final chatId = args.env?.chatId;
      if (chatId == null) return '[]';
      final names = svc.getAllLocalVariables(chatId).keys.toList();
      return slashPipeString(names);
    },
  ));
}
