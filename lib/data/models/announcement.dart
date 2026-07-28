/// 公告数据模型
///
/// 对应远程 announcement.json 的结构。字段全部可选降级：
/// 任何字段缺失或为空都不影响解析，UI层自行判断是否展示。
class Announcement {
  final String version; // 公告版本号，用于判断是否已读
  final String title; // 公告标题
  final String content; // 公告正文，支持 \n 换行
  final String imageUrl; // 顶部横幅图，空则不显示
  final String downloadUrl; // 新版下载地址，空则不显示下载按钮
  final bool forceUpdate; // 是否强制更新（我们始终 false，保持开源友好）
  final String minAppVersion; // 最低兼容版本

  const Announcement({
    this.version = '',
    this.title = '',
    this.content = '',
    this.imageUrl = '',
    this.downloadUrl = '',
    this.forceUpdate = false,
    this.minAppVersion = '',
  });

  /// 从远程 JSON 解析，任何字段缺失都安全降级为默认值
  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      version: (json['version'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      forceUpdate: json['forceUpdate'] == true,
      minAppVersion: (json['minAppVersion'] ?? '').toString(),
    );
  }

  /// 是否有可展示的内容（标题或正文非空才弹窗）
  bool get hasContent => title.trim().isNotEmpty || content.trim().isNotEmpty;

  /// 是否有配图
  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// 是否有下载链接
  bool get hasDownload => downloadUrl.trim().isNotEmpty;
}