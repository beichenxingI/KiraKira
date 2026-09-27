import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/announcement.dart';
import 'package:kirakira/domain/services/announcement_service.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import '../splash/announcement_dialog.dart';

/// 公告中心：Tab 布局（更新公告 + 日常公告）
///
/// 手动入口用。无视已读记录，主动拉取并展示。
/// 居中卡片 + PiuPiu 动画由 showKiraDialog 提供。
class AnnouncementCenterDialog extends ConsumerStatefulWidget {
  const AnnouncementCenterDialog({super.key});

  @override
  ConsumerState<AnnouncementCenterDialog> createState() =>
      _AnnouncementCenterDialogState();
}

class _AnnouncementCenterDialogState
    extends ConsumerState<AnnouncementCenterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Announcement> _updateHistory = []; // 更新公告（当前最新一条）
  List<Announcement> _dailyList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _loading = true);

    try {
      // 拉取更新公告（作为列表的第一条）
      final (updateAnnouncement, _) = await AnnouncementService().fetchUpdate();
      if (updateAnnouncement != null && updateAnnouncement.hasContent) {
        _updateHistory = [updateAnnouncement];
      }

      // 拉取日常公告
      _dailyList = await AnnouncementService().fetchDaily();
    } catch (_) {
      // 静默失败
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoreDialogShell(
      title: '公告中心',
      icon: Icons.campaign,
      maxWidth: 550,
      disableScroll: true, // TabBarView 的 Expanded 需要有界高度
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                  text: '更新公告',
                  icon: Icon(Icons.rocket_launch, size: 20)),
              Tab(
                  text: '日常公告',
                  icon: Icon(Icons.auto_awesome, size: 20)),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpdateList(),
                      _buildDailyList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateList() {
    if (_updateHistory.isEmpty) {
      return const Center(
          child: Text('暂无更新公告', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _updateHistory.length,
      itemBuilder: (context, i) => _buildAnnouncementCard(_updateHistory[i]),
    );
  }

  Widget _buildDailyList() {
    if (_dailyList.isEmpty) {
      return const Center(
          child: Text('暂无日常公告', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dailyList.length,
      itemBuilder: (context, i) => _buildAnnouncementCard(_dailyList[i]),
    );
  }

  Widget _buildAnnouncementCard(Announcement a) {
    final isUpdate = a.type == AnnouncementType.update;
    final color = isUpdate ? DesignTokens.statusWarning : DesignTokens.primary;

    return Card(
      color: DesignTokens.darkSurface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => showAnnouncementDialog(context, a),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isUpdate ? Icons.rocket_launch : Icons.auto_awesome,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (a.publishTime != null)
                      Text(
                        _formatDate(a.publishTime!),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

/// 入口函数：打开公告中心
Future<void> showAnnouncementCenter(BuildContext context) {
  return showKiraDialog(
    context: context,
    dialog: const AnnouncementCenterDialog(),
  );
}
