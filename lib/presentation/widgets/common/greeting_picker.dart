import 'package:flutter/material.dart';
import '../../../data/models/character.dart';
import 'app_dialog.dart';

/// 开场白选择结果。
/// 返回 null 表示用户取消；返回字符串表示选中的开场白正文。
Future<String?> showGreetingPicker(
  BuildContext context,
  Character character,
) {
  // 主开场白 + 所有非空备用开场白
  final greetings = <String>[
    if (character.firstMessage.isNotEmpty) character.firstMessage,
    ...character.alternateGreetings.where((g) => g.trim().isNotEmpty),
  ];

  return showAppDialog<String>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('选择开场白'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: greetings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, index) {
              final text = greetings[index];
              final isPrimary = index == 0 &&
                  character.firstMessage.isNotEmpty;
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  isPrimary ? '主开场白' : '备用开场白 $index',
                  style: theme.textTheme.labelMedium,
                ),
                subtitle: Text(
                  _preview(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(ctx).pop(text),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

/// 生成预览文本：清掉 HTML 标签和常见宏，再取前 20 字。
String _preview(String raw) {
  var s = raw
      .replaceAll(RegExp(r'<[^>]*>'), '') // 去 HTML 标签
      .replaceAll(RegExp(r'\{\{[^}]*\}\}'), '') // 去 {{宏}}
      .replaceAll(RegExp(r'\s+'), ' ') // 折叠空白
      .trim();
  if (s.length > 20) s = '${s.substring(0, 20)}...';
  return s;
}