/// Variable command family. Semantics match ST variables.js.
/// Reads/writes go through SlashEnv hooks (the host handles persistence and
/// engine sync); local-only reads go through VariablesService.
library;

import 'dart:convert';

import 'package:kirakira/domain/services/variables_service.dart';

import '../slash_command.dart';
import '../slash_ast.dart';

/// Pipe stringification: Map/List to JSON, everything else to toString.
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

/// Registers variable commands (idempotent).
void registerVariableSlashCommands() {
  final svc = VariablesService.instance;

  // Chat-local variables
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

  // Global variables
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

  // listvar: list of local variable names (JSON array)
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
