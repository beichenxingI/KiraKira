import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:flutter/foundation.dart';

/// isolate 参数打包（compute 只能传一个参数）
class _MatchParams {
  final List<WorldInfoEntry> entries;
  final String contextText;
  final int maxRecursionDepth;
  _MatchParams(this.entries, this.contextText, this.maxRecursionDepth);
}

/// 纯匹配计算——不碰数据库/ref，可在 isolate 里跑
List<WorldInfoEntry> _matchEntriesPure(_MatchParams p) {
  final entries = p.entries;
  final allMatched = <WorldInfoEntry>[];
  final processedIds = <String>{};
  var currentContext = p.contextText;
  var recursionDepth = 0;

  while (recursionDepth <= p.maxRecursionDepth) {
    final lowerContext = currentContext.toLowerCase();
    final newMatches = <WorldInfoEntry>[];

    for (final entry in entries) {
      if (!entry.enabled) continue;
      if (entry.keys.isEmpty) continue;
      if (processedIds.contains(entry.id)) continue;
      if (entry.preventRecursion && recursionDepth > 0) continue;

      final searchText = entry.caseSensitive ? currentContext : lowerContext;

      bool keyMatched = false;
      for (final key in entry.keys) {
        if (key.trim().isEmpty) continue;
        final searchKey = entry.caseSensitive ? key : key.toLowerCase();
        if (entry.matchWholeWords) {
          keyMatched =
              RegExp(r'\b' + RegExp.escape(searchKey) + r'\b').hasMatch(searchText);
        } else {
          keyMatched = searchText.contains(searchKey);
        }
        if (keyMatched) break;
      }
      if (!keyMatched) continue;

      if (entry.selective && entry.secondaryKeys.isNotEmpty) {
        bool secondaryMatched = false;
        for (final key in entry.secondaryKeys) {
          final searchKey = entry.caseSensitive ? key : key.toLowerCase();
          if (searchText.contains(searchKey)) {
            secondaryMatched = true;
            break;
          }
        }
        if (!secondaryMatched) continue;
      }

      if (entry.probability < 100) {
        final random = DateTime.now().millisecondsSinceEpoch % 100;
        if (random >= entry.probability) continue;
      }

      newMatches.add(entry);
    }

    if (newMatches.isEmpty) break;

    for (final entry in newMatches) {
      processedIds.add(entry.id);
      allMatched.add(entry);
      currentContext = '$currentContext\n${entry.content}';
    }
    recursionDepth++;
  }

  // 常量项
  for (final entry in entries) {
    final isConstant = entry.constant || entry.keys.isEmpty;
    if (isConstant && entry.enabled && !processedIds.contains(entry.id)) {
      allMatched.add(entry);
      processedIds.add(entry.id);
    }
  }

  allMatched.sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));
  return allMatched;
}

/// Provider for WorldInfo repository (properly initialized)
final worldInfoRepositoryProvider = Provider<WorldInfoRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WorldInfoRepository(db);
});

/// All world infos provider
final allWorldInfosProvider = FutureProvider<List<WorldInfo>>((ref) async {
  final repo = ref.watch(worldInfoRepositoryProvider);
  return repo.getAllWorldInfos();
});

/// Global world infos provider
final globalWorldInfosProvider = FutureProvider<List<WorldInfo>>((ref) async {
  final repo = ref.watch(worldInfoRepositoryProvider);
  return repo.getGlobalWorldInfos();
});

/// World infos for a specific character
final characterWorldInfosProvider = FutureProvider.family<List<WorldInfo>, String>((ref, characterId) async {
  final repo = ref.watch(worldInfoRepositoryProvider);
  return repo.getWorldInfosForCharacter(characterId);
});

/// Active world info IDs for the current chat
final activeWorldInfoIdsProvider = StateProvider<List<String>>((ref) => []);

/// World info notifier for CRUD operations
class WorldInfoNotifier extends StateNotifier<AsyncValue<List<WorldInfo>>> {
  final WorldInfoRepository _repository;
  final Ref _ref;

  WorldInfoNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _loadWorldInfos();
  }

  Future<void> _loadWorldInfos() async {
    // 仅首次加载显示 loading；刷新时保留旧数据，避免界面闪回转圈
    if (state is! AsyncData) {
      state = const AsyncValue.loading();
    }
    try {
      final worldInfos = await _repository.getAllWorldInfos();
      state = AsyncValue.data(worldInfos);
      // 同步失效派生 provider，让角色详情/编辑页跟着刷新（世界书、条目编辑后立即可见）
      _ref.invalidate(characterWorldInfosProvider);
      _ref.invalidate(allWorldInfosProvider);
      _ref.invalidate(globalWorldInfosProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadWorldInfos();
  }

  Future<WorldInfo> createWorldInfo({
    required String name,
    String? description,
    bool isGlobal = false,
    String? characterId,
  }) async {
    final worldInfo = await _repository.createWorldInfo(
      name: name,
      description: description,
      isGlobal: isGlobal,
      characterId: characterId,
    );
    await _loadWorldInfos();
    return worldInfo;
  }

  Future<void> updateWorldInfo(WorldInfo worldInfo) async {
    await _repository.updateWorldInfo(worldInfo);
    await _loadWorldInfos();
  }

  Future<void> deleteWorldInfo(String id) async {
    await _repository.deleteWorldInfo(id);
    await _loadWorldInfos();
  }

  Future<WorldInfoEntry> addEntry({
    required String worldInfoId,
    required List<String> keys,
    required String content,
    List<String>? secondaryKeys,
    String? comment,
    WorldInfoPosition? position,
    bool? constant,
    bool? selective,
    int? insertionOrder,
  }) async {
    final entry = await _repository.addEntry(
      worldInfoId: worldInfoId,
      keys: keys,
      content: content,
      secondaryKeys: secondaryKeys,
      comment: comment,
      position: position,
      constant: constant,
      selective: selective,
      insertionOrder: insertionOrder,
    );
    await _loadWorldInfos();
    return entry;
  }

  Future<void> updateEntry(WorldInfoEntry entry) async {
    await _repository.updateEntry(entry);
    await _loadWorldInfos();
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    await _loadWorldInfos();
  }
}

/// Provider for world info notifier
final worldInfoNotifierProvider = StateNotifierProvider<WorldInfoNotifier, AsyncValue<List<WorldInfo>>>((ref) {
  final repo = ref.watch(worldInfoRepositoryProvider);
  return WorldInfoNotifier(repo, ref);
});

/// Service for finding matching world info entries
class WorldInfoMatcher {
  final WorldInfoRepository _repository;

  WorldInfoMatcher(this._repository);

  /// Find all matching entries for the given context
  /// Supports recursion - entries can trigger other entries
  Future<List<WorldInfoEntry>> findMatchingEntries({
    required String contextText,
    required List<String> worldInfoIds,
    int maxRecursionDepth = 3,
    int tokenBudget = 2000, // Maximum tokens for world info
  }) async {
    // 数据库读取留在主线程（异步 IO，不卡）
    final allEntries = <WorldInfoEntry>[];
    for (final worldInfoId in worldInfoIds) {
      allEntries.addAll(await _repository.getEntriesForWorldInfo(worldInfoId));
    }

    // 纯计算丢进后台 isolate，主线程全程不卡
    return compute(
      _matchEntriesPure,
      _MatchParams(allEntries, contextText, maxRecursionDepth),
    );
  }
  Map<WorldInfoPosition, List<WorldInfoEntry>> groupByPosition(List<WorldInfoEntry> entries) {
    final grouped = <WorldInfoPosition, List<WorldInfoEntry>>{};
    
    for (final entry in entries) {
      grouped.putIfAbsent(entry.position, () => []).add(entry);
    }
    
    return grouped;
  }
}

/// Provider for world info matcher
final worldInfoMatcherProvider = Provider<WorldInfoMatcher>((ref) {
  final repo = ref.watch(worldInfoRepositoryProvider);
  return WorldInfoMatcher(repo);
});