/// Message operation commands: /messages /hide /unhide /swipe.
/// Index semantics: negative numbers supported (-1 = last message,
/// TH convention len+1+idx).
library;

import '../slash_command.dart';

/// Resolves a message index: numbers used as-is; negatives converted per TH
/// convention; defaults to the last message.
int? _resolveIndex(String? raw, int count) {
  if (count <= 0) return null;
  if (raw == null || raw.trim().isEmpty) return count - 1;
  final n = int.tryParse(raw.trim());
  if (n == null) return null;
  final idx = n < 0 ? count + n : n;
  if (idx < 0 || idx >= count) return null;
  return idx;
}

void registerFloorSlashCommands() {
  SlashCommandRegistry.register(SlashCommand(
    name: 'messages',
    callback: (args) async {
      return (args.env?.messageCount?.call() ?? 0).toString();
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'hide',
    callback: (args) async {
      final count = args.env?.messageCount?.call() ?? 0;
      final idx = _resolveIndex(
          args.unnamed.isNotEmpty ? args.unnamed.first.toString() : null,
          count);
      if (idx == null) return '';
      await args.env?.setMessageHidden?.call(idx, true);
      return '';
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'unhide',
    callback: (args) async {
      final count = args.env?.messageCount?.call() ?? 0;
      final idx = _resolveIndex(
          args.unnamed.isNotEmpty ? args.unnamed.first.toString() : null,
          count);
      if (idx == null) return '';
      await args.env?.setMessageHidden?.call(idx, false);
      return '';
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'swipe',
    callback: (args) async {
      final count = args.env?.messageCount?.call() ?? 0;
      if (count == 0) return '';
      // named: message=floor index, swipe=swipe number; unnamed[0]: left/right relative switching
      final messageIdx = _resolveIndex(args.namedString('message'), count) ??
          count - 1;
      final swipeArg = args.namedString('swipe');
      final dir = (args.unnamed.isNotEmpty
              ? args.unnamed.first.toString().toLowerCase()
              : '')
          .trim();
      final env = args.env;
      if (env?.swipeTo == null) return '';
      if (swipeArg != null) {
        final si = int.tryParse(swipeArg);
        if (si != null && si >= 0) {
          await env!.swipeTo!(messageIdx, si);
          return '';
        }
      }
      if (dir == 'left' || dir == 'right') {
        // Relative switching is computed by the host after reading the current swipe; -1/-2 are passed here as conventions the host translates
        await env!.swipeTo!(messageIdx, dir == 'left' ? -2 : -1);
        return '';
      }
      // No arguments: default to swiping right (new swipe)
      await env!.swipeTo!(messageIdx, -1);
      return '';
    },
  ));
}
