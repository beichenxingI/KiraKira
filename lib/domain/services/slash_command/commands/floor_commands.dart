/// [P6-5.3] 楼层操作命令:/messages /hide /unhide /swipe。
/// 索引语义:支持负数(-1=最后一条,TH 惯例 len+1+idx)。
library;

import '../slash_command.dart';

/// 解析楼层索引:数字直接用;负数按 TH 惯例换算;缺省默认最后一条。
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
      // named: message=楼层 swipe=swipe序号;unnamed[0]: left/right 相对切换
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
        // 相对切换由宿主读当前 swipe 后计算;这里传 -1/-2 约定由宿主翻译
        await env!.swipeTo!(messageIdx, dir == 'left' ? -2 : -1);
        return '';
      }
      // 无参:默认右切(新 swipe)
      await env!.swipeTo!(messageIdx, -1);
      return '';
    },
  ));
}
