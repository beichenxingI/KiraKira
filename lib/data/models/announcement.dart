/// 公告数据模型
///
/// 双轨：update（更新公告，按哈希去重）/ daily（日常公告，按 id 去重 + 时效过滤）。
/// 对应远程 announcement.json 的结构。字段全部可选降级：
/// 任何字段缺失或为空都不影响解析，UI层自行判断是否展示。
enum AnnouncementType {
  update, // 更新公告
  daily, // 日常公告
}

class Announcement {
  final String id; // 唯一标识（更新公告用哈希前8位，日常公告用 JSON 的 id）
  final AnnouncementType type; // 类型
  final String version; // 保留字段（更新公告用，日常公告为空）
  final String title; // 公告标题
  final String content; // 公告正文，Markdown 格式
  final String imageUrl; // 顶部横幅图，空则不显示
  final String downloadUrl; // 新版下载地址，空则不显示下载按钮
  final bool forceUpdate; // 保留但不使用
  final String minAppVersion; // 保留但不使用
  final DateTime? publishTime; // 日常公告专用
  final DateTime? expireTime; // 日常公告专用
  final int priority; // 日常公告排序权重（默认0，越大越优先）

  const Announcement({
    this.id = '',
    this.type = AnnouncementType.update,
    this.version = '',
    this.title = '',
    this.content = '',
    this.imageUrl = '',
    this.downloadUrl = '',
    this.forceUpdate = false,
    this.minAppVersion = '',
    this.publishTime,
    this.expireTime,
    this.priority = 0,
  });

  /// 从远程 JSON 解析，任何字段缺失都安全降级为默认值。
  ///
  /// [computedHash]：更新公告用于计算 id（'update-' + 哈希前8位）。
  /// 日常公告必须有 JSON 的 id，缺失时用时间戳兜底。
  factory Announcement.fromJson(Map<String, dynamic> json,
      {String? computedHash}) {
    final typeStr = json['type'] as String?;
    final type = typeStr == 'daily'
        ? AnnouncementType.daily
        : AnnouncementType.update;

    String id;
    if (type == AnnouncementType.update) {
      id = computedHash != null && computedHash.length >= 8
          ? 'update-${computedHash.substring(0, 8)}'
          : 'update-unknown';
    } else {
      id = (json['id'] as String?) ??
          'daily-${DateTime.now().millisecondsSinceEpoch}';
    }

    return Announcement(
      id: id,
      type: type,
      version: (json['version'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      forceUpdate: json['forceUpdate'] == true,
      minAppVersion: (json['minAppVersion'] ?? '').toString(),
      publishTime: json['publishTime'] != null
          ? DateTime.tryParse(json['publishTime'].toString())
          : null,
      expireTime: json['expireTime'] != null
          ? DateTime.tryParse(json['expireTime'].toString())
          : null,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  /// 是否有可展示的内容（标题或正文非空才弹窗）
  bool get hasContent => title.trim().isNotEmpty || content.trim().isNotEmpty;

  /// 是否有配图
  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// 是否有下载链接
  bool get hasDownload => downloadUrl.trim().isNotEmpty;

  /// 日常公告是否已过期
  bool get isExpired =>
      expireTime != null && DateTime.now().isAfter(expireTime!);
}
