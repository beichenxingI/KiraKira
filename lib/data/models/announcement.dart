/// Announcement data model.
///
/// Dual track: update (update announcements, deduplicated by hash) and daily
/// (daily announcements, deduplicated by id plus time-window filtering).
/// Maps to the remote announcement.json structure. All fields are optional
/// with graceful degradation: missing or empty fields never break parsing;
/// the UI layer decides whether to display.
enum AnnouncementType {
  update, // Update announcement
  daily, // Daily announcement
}

class Announcement {
  final String id; // Unique id (update announcements use the first 8 hash chars, daily use the JSON id)
  final AnnouncementType type; // Type
  final String version; // Reserved field (used by update announcements, empty for daily)
  final String title; // Announcement title
  final String content; // Announcement body, Markdown format
  final String imageUrl; // Top banner image, hidden when empty
  final String downloadUrl; // New version download URL, download button hidden when empty
  final bool forceUpdate; // Reserved but unused
  final String minAppVersion; // Reserved but unused
  final DateTime? publishTime; // Daily announcements only
  final DateTime? expireTime; // Daily announcements only
  final int priority; // Daily announcement sort weight (default 0, higher = higher priority)

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

  /// Parse from remote JSON; any missing field safely degrades to a default value.
  ///
  /// [computedHash] is used by update announcements to build the id
  /// ('update-' + first 8 hash chars). Daily announcements require the JSON id,
  /// falling back to a timestamp when missing.
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

  /// Whether there is displayable content (dialog only when title or body is non-empty)
  bool get hasContent => title.trim().isNotEmpty || content.trim().isNotEmpty;

  /// Whether an image is present
  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// Whether a download link is present
  bool get hasDownload => downloadUrl.trim().isNotEmpty;

  /// Whether the daily announcement has expired
  bool get isExpired =>
      expireTime != null && DateTime.now().isAfter(expireTime!);
}
