/// Generation command: /genraw silent generation, the result goes into the pipe.
library;

import '../slash_command.dart';

/// Registers generation commands (idempotent).
void registerGenerationSlashCommands() {
  SlashCommandRegistry.register(SlashCommand(
    name: 'genraw',
    callback: (args) async {
      final prompt = args.unnamedAsString();
      if (prompt.trim().isEmpty) return '';
      final out = await args.env?.generateRaw?.call(prompt);
      return out ?? '';
    },
  ));
}
