import 'package:kirakira/data/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/domain/services/announcement_service.dart';
import 'package:kirakira/presentation/providers/announcement_provider.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// Storage key for the read-announcement hash (written after the dialog is closed)
const String _kSeenHashKey = 'seen_announcement_hash';

/// Temporarily stores the hash fetched during startup; written as read after the dialog closes
const String _kPendingHashKey = '_pending_announcement_hash';

/// Legacy version-number key (deprecated; removed on first launch to avoid confusion)
const String _kLegacyVersionKey = 'seen_announcement_version';

/// Splash screen.
///
/// Initial route. Fetches announcements in the background while staying at
/// least 1.5s (covers initialization), then navigates to the main screen.
/// Unread announcements are written to pendingAnnouncementProvider and shown
/// by the main screen. Every failure is silent and never blocks app entry.
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
    // Start the announcement fetch in parallel with the minimum stay, then await its result separately to keep the two futures distinct
    final announcementFuture = _resolveAnnouncement();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final announcement = await announcementFuture;

    if (!mounted) return;

    ref.read(pendingAnnouncementProvider.notifier).state = announcement;

    context.go('/');
  }

  /// Fetches the announcement and decides whether to show it; returns it or null.
  ///
  /// Hash comparison: shown only when the content changed. The read marker is
  /// not written here but after the dialog closes (handled by the main_page caller).
  /// Also migrates away the legacy seen_announcement_version key.
  Future<Announcement?> _resolveAnnouncement() async {
    try {
      final (a, hash) = await AnnouncementService().fetchUpdate();

      if (a == null || hash == null || !a.hasContent) {
        KiraLogger().info('公告', '无可展示内容，跳过');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();

      // Migration: remove the legacy version key (first run only)
      if (prefs.containsKey(_kLegacyVersionKey)) {
        await prefs.remove(_kLegacyVersionKey);
      }

      final seenHash = prefs.getString(_kSeenHashKey);
      if (seenHash == hash) {
        KiraLogger().info('公告', '哈希 ${hash.substring(0, 8)} 已读，跳过');
        return null;
      }

      // Do not write the read marker here; store the hash temporarily for use after the dialog closes
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
                  // TODO(token, pending approval): brandPurple(0xFFa78bfa) is the brand bright purple;
                  // use primary until the token is approved
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