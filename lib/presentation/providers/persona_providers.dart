import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/persona.dart';
import 'package:kirakira/data/repositories/persona_repository.dart';

/// All personas provider
final allPersonasProvider = FutureProvider<List<Persona>>((ref) async {
  final repo = ref.watch(personaRepositoryProvider);
  await repo.ensureDefaultPersonaExists();
  return repo.getAllPersonas();
});

/// Current active persona provider
final activePersonaIdProvider = StateProvider<String?>((ref) => null);

/// Active persona provider
final activePersonaProvider = FutureProvider<Persona?>((ref) async {
  final activeId = ref.watch(activePersonaIdProvider);
  final repo = ref.watch(personaRepositoryProvider);
  
  if (activeId != null) {
    return repo.getPersona(activeId);
  }
  
  // Return default persona if no active persona is set
  return repo.getDefaultPersona();
});
/// 按角色解析生效人设：手动选 > 角色绑定 > 默认。
/// characterId 为空时退回"手动选 > 默认"。
final personaForCharacterProvider =
    FutureProvider.family<Persona?, String?>((ref, characterId) async {
  final repo = ref.watch(personaRepositoryProvider);

  // 第1级：用户在当前会话手动选中的人设，优先级最高
  final activeId = ref.watch(activePersonaIdProvider);
  if (activeId != null) {
    final manual = await repo.getPersona(activeId);
    if (manual != null) return manual;
  }

  // 第2级：当前角色绑定的人设
  if (characterId != null) {
    final all = await repo.getAllPersonas();
    for (final p in all) {
      if (p.isConnectedToCharacter(characterId)) {
        return p;
      }
    }
  }

  // 第3级：默认人设
  return repo.getDefaultPersona();
});

/// Persona management notifier
class PersonaNotifier extends StateNotifier<AsyncValue<List<Persona>>> {
  final PersonaRepository _repository;
  final Ref _ref;

  PersonaNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _loadPersonas();
  }

  Future<void> _loadPersonas() async {
    state = const AsyncValue.loading();
    try {
      await _repository.ensureDefaultPersonaExists();
      final personas = await _repository.getAllPersonas();
      state = AsyncValue.data(personas);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadPersonas();
  }

  Future<void> createPersona({
    required String name,
    String description = '',
    String? avatarPath,
  }) async {
    final now = DateTime.now();
    final persona = Persona(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      avatarPath: avatarPath,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.createPersona(persona);
    await _loadPersonas();
  }

  Future<void> updatePersona(Persona persona) async {
    final updated = persona.copyWith(updatedAt: DateTime.now());
    await _repository.updatePersona(updated);
    await _loadPersonas();
  }

  Future<void> deletePersona(String id) async {
    // Don't allow deleting the default persona
    final persona = await _repository.getPersona(id);
    if (persona?.isDefault == true) {
      throw Exception('Cannot delete the default persona');
    }

    await _repository.deletePersona(id);
    
    // If the deleted persona was active, reset to default
    final activeId = _ref.read(activePersonaIdProvider);
    if (activeId == id) {
      _ref.read(activePersonaIdProvider.notifier).state = null;
    }
    
    await _loadPersonas();
  }

  Future<void> setDefaultPersona(String id) async {
    await _repository.setDefaultPersona(id);
    await _loadPersonas();
  }

  Future<void> setActivePersona(String id) async {
    _ref.read(activePersonaIdProvider.notifier).state = id;
  }
}

/// Provider for persona notifier
final personaNotifierProvider = StateNotifierProvider<PersonaNotifier, AsyncValue<List<Persona>>>((ref) {
  final repo = ref.watch(personaRepositoryProvider);
  return PersonaNotifier(repo, ref);
});