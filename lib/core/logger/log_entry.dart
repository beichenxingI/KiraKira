class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  String toLine() {
    final ts = timestamp.toIso8601String();
    final st = stackTrace != null ? '\n$stackTrace' : '';
    return '[$ts] [$level] [$tag] $message$st';
  }

  static LogEntry? fromLine(String line) {
    try {
      final tsEnd = line.indexOf(']');
      if (tsEnd < 0) return null;
      final ts = DateTime.parse(line.substring(1, tsEnd));
      final lvlEnd = line.indexOf(']', tsEnd + 1);
      if (lvlEnd < 0) return null;
      final lvl = line.substring(tsEnd + 3, lvlEnd);
      final tagEnd = line.indexOf(']', lvlEnd + 1);
      if (tagEnd < 0) return null;
      final tag = line.substring(lvlEnd + 3, tagEnd);
      final msg = line.substring(tagEnd + 2);
      return LogEntry(timestamp: ts, level: lvl, tag: tag, message: msg);
    } catch (_) {
      return null;
    }
  }
}
