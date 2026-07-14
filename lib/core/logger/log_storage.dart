import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'log_entry.dart';

class LogStorage {
  static const _maxEntries = 2000;
  static const _maxFileSize = 2 * 1024 * 1024; // 2 MB
  final List<LogEntry> _buffer = [];
  File? _file;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _file = File(p.join(logDir.path, 'kirakira.log'));
    _initialized = true;
  }

  Future<void> write(LogEntry entry) async {
    await init();
    _buffer.add(entry);
    if (_buffer.length >= 50) await _flush();
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty || _file == null) return;
    final lines = _buffer.map((e) => e.toLine()).join('\n') + '\n';
    _buffer.clear();
    try {
      await _file!.writeAsString(lines, mode: FileMode.append);
      await _rotateIfNeeded();
    } catch (_) {}
  }

  Future<List<LogEntry>> read({int limit = 200}) async {
    await _flush();
    if (_file == null || !await _file!.exists()) return [];
    try {
      final content = await _file!.readAsString();
      final lines = content.split('\n');
      final entries = <LogEntry>[];
      for (final line in lines.reversed) {
        if (line.trim().isEmpty) continue;
        final entry = LogEntry.fromLine(line);
        if (entry != null) entries.add(entry);
        if (entries.length >= limit) break;
      }
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() async {
    await _flush();
    _buffer.clear();
    if (_file != null && await _file!.exists()) {
      try { await _file!.delete(); } catch (_) {}
    }
  }

  Future<void> _rotateIfNeeded() async {
    if (_file == null || !await _file!.exists()) return;
    try {
      final len = await _file!.length();
      if (len > _maxFileSize) {
        final backup = '${_file!.path}.old';
        final old = File(backup);
        if (await old.exists()) await old.delete();
        await _file!.rename(backup);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _flush();
  }
}
