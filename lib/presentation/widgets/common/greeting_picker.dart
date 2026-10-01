import 'package:flutter/material.dart';
import '../../../data/models/character.dart';
import 'app_dialog.dart';

/// Result of the greeting picker.
/// Returns null when the user cancels; returns the selected greeting text as a string.
Future<String?> showGreetingPicker(
  BuildContext context,
  Character character,
) {
  // Primary greeting + all non-empty alternate greetings
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

/// Builds preview text: strips HTML tags and common macros, then takes the first 20 characters.
String _preview(String raw) {
  var s = raw
      .replaceAll(RegExp(r'<[^>]*>'), '') // strip HTML tags
      .replaceAll(RegExp(r'\{\{[^}]*\}\}'), '') // strip {{macros}}
      .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
      .trim();
  if (s.length > 20) s = '${s.substring(0, 20)}...';
  return s;
}