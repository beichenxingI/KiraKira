import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/data/models/announcement.dart';

/// Computes the SHA256 hash of announcement content (to detect content changes)
///
/// The JSON map must be stably sorted before encoding to avoid hash differences
/// from field order changes. Dead fields that do not affect content
/// (forceUpdate/minAppVersion) are removed.
String computeAnnouncementHash(Map<String, dynamic> json) {
  // 1. Deep copy and remove fields that do not affect content
  final normalized = Map<String, dynamic>.from(json);
  normalized.remove('forceUpdate');
  normalized.remove('minAppVersion');

  // 2. Stable sort: rebuild the map with keys in alphabetical order
  final sortedKeys = normalized.keys.toList()..sort();
  final sortedMap = <String, dynamic>{};
  for (final key in sortedKeys) {
    sortedMap[key] = normalized[key];
  }

  // 3. JSON encode (compact, no indentation)
  final jsonString = jsonEncode(sortedMap);

  // 4. UTF-8 encode, then SHA256
  final bytes = utf8.encode(jsonString);
  final digest = sha256.convert(bytes);

  return digest.toString(); // 64-char hex string
}

/// Announcement fetch service.
///
/// Two tracks: update (single object, multi-source racing) and daily (array, multi-source racing).
/// Concurrent requests hit multiple mirrors; the first success wins, all failures return empty,
/// and entry into the app is never blocked. Source URLs are centralized in _updateSources / _dailySources.
class AnnouncementService {
  final Dio _dio;

  AnnouncementService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              responseType: ResponseType.plain,
            ));

  static const List<String> _updateSources = [
    // Main domestic source: Gitee (fast access, verified working)
    'https://gitee.com/kirakira-config/kirakira-announcements/raw/main/announcement.json',
    // Main international source: GitHub raw direct
    'https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // Fallback: gh-proxy acceleration proxy (may become unavailable; update this line if it fails)
    'https://gh-proxy.com/https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // Not yet configured: Cloudflare Pages
    // 'https://kirakira-announcements.pages.dev/announcement.json',
  ];

  static const List<String> _dailySources = [
    'https://gitee.com/kirakira-config/kirakira-announcements/raw/main/releases/announcements_daily.json',
    'https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/releases/announcements_daily.json',
    'https://gh-proxy.com/https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/releases/announcements_daily.json',
  ];

  /// Fetch update announcements (single object).
  /// Returns (Announcement?, String? hash); the hash is used for read tracking.
  /// Multi-source racing: the first success wins, all failures return (null, null).
  Future<(Announcement?, String?)> fetchUpdate() {
    final completer = Completer<(Announcement?, String?)>();
    var pending = _updateSources.length;
    KiraLogger().info('公告', '拉取更新公告，共 ${_updateSources.length} 个源');

    for (final url in _updateSources) {
      _fetchFrom(url).then((jsonString) {
        if (completer.isCompleted) return;
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final hash = computeAnnouncementHash(json);
          final announcement =
              Announcement.fromJson(json, computedHash: hash);
          if (!announcement.hasContent) {
            throw const FormatException('公告内容为空');
          }
          KiraLogger()
              .info('公告', '更新公告成功: $url  hash=${hash.substring(0, 8)}');
          completer.complete((announcement, hash));
        } catch (e) {
          pending--;
          KiraLogger().error('公告', '更新公告解析失败($pending剩余): $url  $e');
          if (pending == 0 && !completer.isCompleted) {
            KiraLogger().error('公告', '更新公告所有源均失败');
            completer.complete((null, null));
          }
        }
      }).catchError((Object e) {
        pending--;
        KiraLogger().error('公告', '更新公告失败($pending剩余): $url  $e');
        if (pending == 0 && !completer.isCompleted) {
          KiraLogger().error('公告', '更新公告所有源均失败');
          completer.complete((null, null));
        }
      });
    }

    return completer.future;
  }

  /// Fetch daily announcements (array).
  /// Returns List<Announcement> with expired ones filtered out, sorted by priority descending.
  /// Multi-source racing: the first success wins, all failures return [].
  Future<List<Announcement>> fetchDaily() {
    final completer = Completer<List<Announcement>>();
    var pending = _dailySources.length;
    KiraLogger().info('公告', '拉取日常公告，共 ${_dailySources.length} 个源');

    for (final url in _dailySources) {
      _fetchFrom(url).then((jsonString) {
        if (completer.isCompleted) return;
        try {
          final decoded = jsonDecode(jsonString);
          if (decoded is! List) {
            throw const FormatException('日常公告格式错误：期望数组');
          }
          final announcements = decoded
              .cast<Map<String, dynamic>>()
              .map((json) => Announcement.fromJson(json))
              .where((a) => a.hasContent && !a.isExpired)
              .toList();
          // Sort by priority descending
          announcements.sort((a, b) => b.priority.compareTo(a.priority));
          KiraLogger().info('公告', '日常公告成功: $url  共 ${announcements.length} 条');
          completer.complete(announcements);
        } catch (e) {
          pending--;
          KiraLogger().error('公告', '日常公告解析失败($pending剩余): $url  $e');
          if (pending == 0 && !completer.isCompleted) {
            KiraLogger().error('公告', '日常公告所有源均失败');
            completer.complete([]);
          }
        }
      }).catchError((Object e) {
        pending--;
        KiraLogger().error('公告', '日常公告失败($pending剩余): $url  $e');
        if (pending == 0 && !completer.isCompleted) {
          KiraLogger().error('公告', '日常公告所有源均失败');
          completer.complete([]);
        }
      });
    }

    return completer.future;
  }

  Future<String> _fetchFrom(String url) async {
    final resp = await _dio.get<String>(url);
    final body = resp.data;
    if (body == null || body.trim().isEmpty) {
      throw const FormatException('空响应');
    }
    return body;
  }
}
