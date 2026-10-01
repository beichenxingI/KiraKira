/// UI interaction command: /buttons selection, the chosen item goes into the pipe.
library;

import 'dart:convert';

import '../slash_command.dart';

/// Registers UI interaction commands (idempotent).
void registerUiSlashCommands() {
  SlashCommandRegistry.register(SlashCommand(
    name: 'buttons',
    callback: (args) async {
      dynamic labelsRaw = args.named['labels'];
      if (labelsRaw == null && args.unnamed.isNotEmpty) {
        labelsRaw = args.unnamed.first;
      }
      var labels = <String>[];
      if (labelsRaw is String) {
        try {
          final decoded = jsonDecode(labelsRaw);
          if (decoded is List) {
            labels = decoded.map((e) => e.toString()).toList();
          } else {
            labels = [labelsRaw];
          }
        } catch (_) {
          labels = [labelsRaw];
        }
      }
      if (labels.isEmpty) return '';
      final chosen = await args.env?.showButtons?.call(labels);
      return chosen ?? '';
    },
  ));
}
