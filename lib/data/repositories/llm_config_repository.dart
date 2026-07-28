import 'package:drift/drift.dart' as drift;
import '../database/database.dart';

class LlmConfigRepository {
  final AppDatabase _db;
  LlmConfigRepository(this._db);

  Future<List<LlmConfig>> getAll() {
    return (_db.select(_db.llmConfigs)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<LlmConfig?> getById(String id) {
    return (_db.select(_db.llmConfigs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<LlmConfig?> getDefault() {
    return (_db.select(_db.llmConfigs)..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();
  }

  Future<void> upsert(LlmConfigsCompanion config) {
    return _db.into(_db.llmConfigs).insertOnConflictUpdate(config);
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.llmConfigs)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setDefault(String id) {
    return _db.transaction(() async {
      await _db.update(_db.llmConfigs).write(
            const LlmConfigsCompanion(isDefault: drift.Value(false)),
          );
      await (_db.update(_db.llmConfigs)..where((t) => t.id.equals(id))).write(
        const LlmConfigsCompanion(isDefault: drift.Value(true)),
      );
    });
  }
}
