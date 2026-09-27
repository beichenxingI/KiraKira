import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/data/models/announcement.dart';

/// 计算公告内容的 SHA256 哈希（用于判断内容是否变化）
///
/// 必须对 JSON Map 进行稳定排序后再编码，避免字段顺序变化导致哈希不同。
/// 移除不影响内容的死字段（forceUpdate/minAppVersion）。
String computeAnnouncementHash(Map<String, dynamic> json) {
  // 1. 深拷贝并移除不影响内容的字段
  final normalized = Map<String, dynamic>.from(json);
  normalized.remove('forceUpdate');
  normalized.remove('minAppVersion');

  // 2. 稳定排序：按 key 字母序重建 Map
  final sortedKeys = normalized.keys.toList()..sort();
  final sortedMap = <String, dynamic>{};
  for (final key in sortedKeys) {
    sortedMap[key] = normalized[key];
  }

  // 3. JSON 编码（无缩进，紧凑格式）
  final jsonString = jsonEncode(sortedMap);

  // 4. UTF-8 编码 → SHA256
  final bytes = utf8.encode(jsonString);
  final digest = sha256.convert(bytes);

  return digest.toString(); // 64 位十六进制字符串
}

/// 公告拉取服务
///
/// 双轨：update（单对象，多源竞速）/ daily（数组，多源竞速）。
/// 多源并发请求多个镜像，第一个成功的结果胜出，全部失败返回空，绝不阻塞进入 app。
/// 源地址集中在 _updateSources / _dailySources，失效时改一行即可。
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
    // 国内主源：Gitee（访问快，实测可用）
    'https://gitee.com/kirakira-config/kirakira-announcements/raw/main/announcement.json',
    // 国外主源：GitHub raw 直连
    'https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // 备用：gh-proxy 公益加速（可能失效，失效改此行）
    'https://gh-proxy.com/https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // 待配置：Cloudflare Pages
    // 'https://kirakira-announcements.pages.dev/announcement.json',
  ];

  static const List<String> _dailySources = [
    'https://gitee.com/kirakira-config/kirakira-announcements/raw/main/releases/announcements_daily.json',
    'https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/releases/announcements_daily.json',
    'https://gh-proxy.com/https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/releases/announcements_daily.json',
  ];

  /// 拉取更新公告（单对象）。
  /// 返回 (Announcement?, String? hash)，hash 用于已读判断。
  /// 多源竞速：第一个成功者胜出，全部失败返回 (null, null)。
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

  /// 拉取日常公告（数组）。
  /// 返回 List<Announcement>，已过期的自动过滤，按 priority 降序排序。
  /// 多源竞速：第一个成功者胜出，全部失败返回 []。
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
          // 按 priority 降序排序
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
