import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/data/models/announcement.dart';

/// 公告拉取服务
///
/// 多源竞速：并发请求多个镜像，第一个成功的结果胜出，
/// 全部失败返回 null，绝不阻塞进入 app。
/// 源地址集中在 _sources，失效时改一行即可。
class AnnouncementService {
  final Dio _dio;

  AnnouncementService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              responseType: ResponseType.plain,
            ));

  static const List<String> _sources = [
    // 国内主源：Gitee（访问快，实测可用）
    'https://gitee.com/kirakira-config/kirakira-announcements/raw/main/announcement.json',
    // 国外主源：GitHub raw 直连
    'https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // 备用：gh-proxy 公益加速（可能失效，失效改此行）
    'https://gh-proxy.com/https://raw.githubusercontent.com/beichenxingI/kirakira-announcements/main/announcement.json',
    // 待配置：Cloudflare Pages
    // 'https://kirakira-announcements.pages.dev/announcement.json',
  ];

  /// 多源竞速拉取，第一个成功者胜出，全部失败返回 null
  Future<Announcement?> fetch() {
    final completer = Completer<Announcement?>();
    var pending = _sources.length;
    KiraLogger().info('公告', '开始拉取，共 ${_sources.length} 个源');

    for (final url in _sources) {
      _fetchFrom(url).then((a) {
        KiraLogger().info('公告', '成功: $url  version=${a.version}');
        if (!completer.isCompleted) completer.complete(a);
      }).catchError((e) {
        pending--;
        KiraLogger().error('公告', '失败($pending剩余): $url  $e');
        if (pending == 0 && !completer.isCompleted) {
          KiraLogger().error('公告', '所有源均失败');
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  Future<Announcement> _fetchFrom(String url) async {
    final resp = await _dio.get<String>(url);
    final body = resp.data;
    if (body == null || body.trim().isEmpty) {
      throw const FormatException('空响应');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Announcement.fromJson(decoded);
    }
    throw const FormatException('公告格式无法解析');
  }
}