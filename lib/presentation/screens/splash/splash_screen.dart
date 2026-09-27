import 'package:kirakira/data/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/domain/services/announcement_service.dart';
import 'package:kirakira/presentation/providers/announcement_provider.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// 已读公告哈希的存储键（弹窗关闭后写入）
const String _kSeenHashKey = 'seen_announcement_hash';

/// 拉取阶段临时存储哈希，供弹窗关闭后写入已读
const String _kPendingHashKey = '_pending_announcement_hash';

/// 旧版本号 key（已弃用，首次启动时删除避免混淆）
const String _kLegacyVersionKey = 'seen_announcement_version';

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
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final announcement = await announcementFuture;

    if (!mounted) return;

    ref.read(pendingAnnouncementProvider.notifier).state = announcement;

    context.go('/');
  }

  /// 拉取并判断是否需要展示，返回待弹公告或 null
  ///
  /// 哈希对比：内容变化才弹。不在此处写已读标记，
  /// 改在弹窗关闭后写（由 main_page 调用方处理）。
  /// 同时迁移删除旧的 seen_announcement_version key。
  Future<Announcement?> _resolveAnnouncement() async {
    try {
      final (a, hash) = await AnnouncementService().fetchUpdate();

      if (a == null || hash == null || !a.hasContent) {
        KiraLogger().info('公告', '无可展示内容，跳过');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();

      // 迁移：删除旧版本号 key（仅首次执行）
      if (prefs.containsKey(_kLegacyVersionKey)) {
        await prefs.remove(_kLegacyVersionKey);
      }

      final seenHash = prefs.getString(_kSeenHashKey);
      if (seenHash == hash) {
        KiraLogger().info('公告', '哈希 ${hash.substring(0, 8)} 已读，跳过');
        return null;
      }

      // ⚠️ 关键：不在这里写已读标记！临时存储哈希，供弹窗关闭后使用
      await prefs.setString(_kPendingHashKey, hash);
      KiraLogger().info('公告', '待展示 哈希 ${hash.substring(0, 8)}');
      return a;
    } catch (e) {
      KiraLogger().error('公告', '处理异常: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.darkBackground,
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
                  // TODO(token·待批准): brandPurple(0xFFa78bfa) 品牌亮紫,
                  // 未批准前用 primary(宪法 §一 主色)
                  color: DesignTokens.primary,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'KiraKira',
              style: TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSize2xl,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXl),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  DesignTokens.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}