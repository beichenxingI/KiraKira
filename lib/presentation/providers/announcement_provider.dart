import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/announcement.dart';

/// 待展示的公告。转圈页拉取后写入，主界面读取后弹窗并清空。
/// null 表示无公告可展示（未拉到、已读过、或已弹过）。
final pendingAnnouncementProvider =
    StateProvider<Announcement?>((ref) => null);