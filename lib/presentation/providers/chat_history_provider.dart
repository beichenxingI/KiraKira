// lib/presentation/providers/chat_history_provider.dart
/// 聊天回忆页"每页条数"(返工条目6):键 chat_history_page_size,
/// 模板照抄 character_grid_provider.dart。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final chatHistoryPageSizeProvider =
    StateNotifierProvider<ChatHistoryPageSizeNotifier, int>((ref) {
  return ChatHistoryPageSizeNotifier();
});

class ChatHistoryPageSizeNotifier extends StateNotifier<int> {
  ChatHistoryPageSizeNotifier() : super(20) {
    _load();
  }

  static const String _key = 'chat_history_page_size';

  /// 可选档位(列表条数)
  static const List<int> kChoices = [10, 20, 30, 50];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_key) ?? 20;
    state = kChoices.contains(v) ? v : 20;
  }

  Future<void> set(int value) async {
    if (!kChoices.contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
    state = value;
  }
}
