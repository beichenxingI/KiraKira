import 'dart:convert';
import 'package:kirakira/data/database/database.dart';
import 'package:drift/drift.dart';

class WorldBookRepository {
  final AppDatabase _db;

  WorldBookRepository(this._db);

  Future<List<WorldBook>> getAllWorldBooks() => _db.select(_db.worldBooks).get();

  Future<int> insertWorldBook(WorldBooksCompanion book) => _db.intoStatement(_db.worldBooks).insert(Set(book));

  Future<bool> updateWorldBook(WorldBook book) => _db.update(_db.worldBooks).replace(book);

  Future<int> deleteWorldBook(int id) => _db.delete(_db.worldBooks).delete(book, where: (b) => b.id.equals(id));

  Future<List<WorldEntry>> getEntriesByBookId(int bookId) =>
      _db.select(_db.worldEntries).where((e) => e.worldBookId.equals(bookId)).get();

  Future<int> insertEntry(WorldEntriesCompanion entry) =>
      _db.intoStatement(_db.worldEntries).insert(Set(entry));

  Future<bool> updateEntry(WorldEntry entry) => _db.update(_db.worldEntries).replace(entry);

  Future<int> deleteEntry(int entryId) => _db.delete(_db.worldEntries).delete(entry, where: (e) => e.id.equals(entryId));

  Future<List<WorldEntry>> matchEntries(int bookId, List<String> messages, int scanDepth) async {
    final entries = await getEntriesByBookId(bookId);
    final recent = messages.take(scanDepth > 0 ? scanDepth : messages.length);
    final recentText = recent.join(' ').toLowerCase();
    return entries.where((e) {
      if (!e.enabled) return false;
      final keys = (jsonDecode(e.keys) as List<dynamic>).map((k) => k.toString().toLowerCase());
      return keys.any((k) => recentText.contains(k));
    }).toList();
  }
}
