import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/regex_script_repository.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';

// Note: characterRepositoryProvider is defined in character_repository.dart

/// Selected character state
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

/// Character list provider
/// autoDispose drops the cache when the list page exits, so re-entering always
/// re-queries the database with no manual invalidation; eliminates stale caches
/// on the statistics and worldbook pages.
final characterListProvider = AsyncNotifierProvider.autoDispose<CharacterListNotifier, List<Character>>(() {
  return CharacterListNotifier();
});

/// Character list notifier
class CharacterListNotifier extends AutoDisposeAsyncNotifier<List<Character>> {
  @override
  Future<List<Character>> build() async {
    final repo = ref.watch(characterRepositoryProvider);
    final list = await repo.getAllCharacters();
    _sortPinnedFirst(list);
    return list;
  }

  Future<void> refresh() async {
    // Keep previous data so the list page does not flash a skeleton on every save/delete
    state = await AsyncValue.guard(() async {
      final repo = ref.read(characterRepositoryProvider);
      final list = await repo.getAllCharacters();
      _sortPinnedFirst(list);
      return list;
    });
  }

  /// Sort: pinned first (pinnedAt descending), then the rest by creation time descending
  static void _sortPinnedFirst(List<Character> list) {
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isPinned && b.isPinned) {
        return (b.pinnedAt ?? DateTime(0)).compareTo(a.pinnedAt ?? DateTime(0));
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<Character> addCharacter(Character character) async {
    final repo = ref.read(characterRepositoryProvider);
    final createdCharacter = await repo.createCharacter(character);

    // On import, write extensions['regex_scripts'] into its own table.
    // After phase 2 the regex consumers only read the table; if the import does
    // not write it, the only fallback is the dual-read on first Provider load
    // (ST-format card fallback parsing fails, so all regexes are lost).
    try {
      final rawList = createdCharacter.extensions['regex_scripts'];
      if (rawList is List && rawList.isNotEmpty) {
        await ref
            .read(regexScriptRepositoryProvider)
            .importCharacterScriptsFromRaw(createdCharacter.id, rawList);
      }
    } catch (e) {
      // A table write failure must not block character creation; the original
      // extensions data is kept and dual-read covers loading
      debugPrint('[Phase2] 导入正则写表失败(extensions 保留): $e');
    }

    // Creating a character also generates its bound empty worldbook (the
    // character regex set lives in extensions, which naturally carries an empty set).
    // Only create the shell when the card has no embedded worldbook: importing a
    // card that ships with a book no longer produces an empty shell that shadows
    // the real book (consumers already prefer non-empty; this avoids creating
    // shells at the source).
    final hasEmbeddedBook =
        createdCharacter.characterBook != null &&
        createdCharacter.characterBook!.entries.isNotEmpty;
    if (!hasEmbeddedBook) {
      try {
        await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(
              name:
                  '${createdCharacter.name.isEmpty ? '未命名角色' : createdCharacter.name} 的世界书',
              isGlobal: false,
              characterId: createdCharacter.id,
            );
      } catch (_) {
        // Failing to create the worldbook must not block character creation;
        // the editor's WorldBook tab still offers a manual create entry
      }
    }
    await refresh();
    return createdCharacter;
  }

  Future<void> updateCharacter(Character character) async {
    final repo = ref.read(characterRepositoryProvider);
    await repo.updateCharacter(character);
    await refresh();
  }

  Future<void> deleteCharacter(String id) async {
    final repo = ref.read(characterRepositoryProvider);
    await repo.deleteCharacter(id);
    await refresh();
  }
}

/// Selected character provider
final selectedCharacterProvider = FutureProvider<Character?>((ref) async {
  final id = ref.watch(selectedCharacterIdProvider);
  if (id == null) return null;
  
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(id);
});

/// Character search provider
final characterSearchProvider = FutureProvider.family<List<Character>, String>((ref, query) async {
  if (query.isEmpty) return [];
  
  final repo = ref.watch(characterRepositoryProvider);
  return repo.searchCharacters(query);
});