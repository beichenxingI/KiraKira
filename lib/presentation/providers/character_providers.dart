import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';

// Note: characterRepositoryProvider is defined in character_repository.dart

/// Selected character state
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

/// Character list provider
final characterListProvider = AsyncNotifierProvider<CharacterListNotifier, List<Character>>(() {
  return CharacterListNotifier();
});

/// Character list notifier
class CharacterListNotifier extends AsyncNotifier<List<Character>> {
  @override
  Future<List<Character>> build() async {
    final repo = ref.watch(characterRepositoryProvider);
    return repo.getAllCharacters();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(characterRepositoryProvider);
      return repo.getAllCharacters();
    });
  }

  Future<Character> addCharacter(Character character) async {
    final repo = ref.read(characterRepositoryProvider);
    final createdCharacter = await repo.createCharacter(character);
    // 条目1:新建角色同步生成绑定空世界书(角色正则集存 extensions,天然自带空集)
    // A2修复:仅当角色卡【不带内嵌世界书】时才建壳——导入带书的卡不再产生
    // 空壳遮蔽真书(消费侧已改非空优先,此处从源头不再制造空壳)。
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
        // 建书失败不阻断建卡;编辑器 WorldBook tab 仍有手动新建入口
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