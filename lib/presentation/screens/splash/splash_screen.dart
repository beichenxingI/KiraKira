import 'package:kirakira/data/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/domain/services/announcement_service.dart';
import 'package:kirakira/presentation/providers/announcement_provider.dart';

/// 已读公告版本的存储键
const String _kSeenKey = 'seen_announcement_version';

/// 启动转圈页
///
/// 作为初始路由。后台并行拉取公告 + 最短停留 1.5 秒（覆盖初始化时间），
/// 完成后跳主界面。拉到的未读公告写入 pendingAnnouncementProvider，
/// 由主界面读取弹窗。任何失败都静默，绝不阻塞进入 app。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // 先并行等最短停留，再单独取公告结果，避免类型混用
    final announcementFuture = _resolveAnnouncement();
    await Future.delayed(const Duration(milliseconds: 1500));
    final announcement = await announcementFuture;

    if (!mounted) return;

    ref.read(pendingAnnouncementProvider.notifier).state = announcement;

    context.go('/');
  }

  /// 拉取并判断是否需要展示，返回待弹公告或 null
  Future<Announcement?> _resolveAnnouncement() async {
    try {
      final a = await AnnouncementService().fetch();
      if (a == null || !a.hasContent) {
        KiraLogger().info('公告', '无可展示内容，跳过');
        return null;
      }
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getString(_kSeenKey);
      if (seen == a.version) {
        KiraLogger().info('公告', '版本 ${a.version} 已读过，跳过');
        return null;
      }
      await prefs.setString(_kSeenKey, a.version);
      KiraLogger().info('公告', '待展示 版本 ${a.version}');
      return a;
    } catch (e) {
      KiraLogger().error('公告', '处理异常: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _breathe.drive(Tween(begin: 0.4, end: 1.0)),
              child: ScaleTransition(
                scale: _breathe.drive(Tween(begin: 0.9, end: 1.1)),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFa78bfa),
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'KiraKira',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  const Color(0xFFa78bfa).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}