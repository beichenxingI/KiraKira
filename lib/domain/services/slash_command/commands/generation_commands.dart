/// [P6-4] 生成命令(P0):/genraw 静默生成,结果进管道。
library;

import '../slash_command.dart';

/// 注册生成命令(幂等)。
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
