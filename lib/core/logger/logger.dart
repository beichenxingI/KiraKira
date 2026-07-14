import 'log_entry.dart';
import 'log_storage.dart';

enum LogLevel { debug, info, warning, error }

class KiraLogger {
  static final KiraLogger _instance = KiraLogger._();
  factory KiraLogger() => _instance;
  KiraLogger._();

  final LogStorage _storage = LogStorage();
  bool _enabled = true;

  void setEnabled(bool enabled) => _enabled = enabled;
  bool get isEnabled => _enabled;

  Future<void> init() => _storage.init();

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warning(String tag, String message) => _log(LogLevel.warning, tag, message);
  void error(String tag, String message, [StackTrace? stack]) => _log(LogLevel.error, tag, message, stack);

  void menu(String label) => info('MENU', '点击菜单: $label');
  void route(String path) => info('ROUTE', '导航到: $path');

  void _log(LogLevel level, String tag, String message, [StackTrace? stack]) {
    if (!_enabled) return;
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level.name.toUpperCase(),
      tag: tag,
      message: message,
      stackTrace: stack?.toString(),
    );
    _storage.write(entry);
  }

  Future<List<LogEntry>> read({int limit = 200}) => _storage.read(limit: limit);
  Future<void> clear() => _storage.clear();
  Future<void> flush() => _storage.dispose();
}
