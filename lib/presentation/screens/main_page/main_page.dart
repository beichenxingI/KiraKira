import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kirakira/presentation/providers/home_background_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/providers/home_music_service.dart';
import 'package:kirakira/presentation/widgets/home/time_greeting.dart';
import 'package:kirakira/presentation/widgets/home/video_background.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/screens/splash/announcement_dialog.dart';
import 'package:kirakira/presentation/providers/announcement_provider.dart';
import 'daily_oracle_sheet.dart';
import 'announcement_center_dialog.dart';
import 'package:kirakira/presentation/screens/terms_dialog.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});
  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  HeadlessInAppWebView? _warmupWebView;

  @override
  void initState() {
    super.initState();
    // Trigger global music service initialization (it manages playback and app lifecycle itself)
    ref.read(homeMusicServiceProvider);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() => _now = DateTime.now()); },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Warm up the WebView engine so opening the chat screen skips its initialization time
      _warmupWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: '<html></html>'),
      );
      await _warmupWebView!.run();

      // Pre-decode character avatars into the cache in the background
      _preloadCharacterAvatars();

      // First launch: show the disclaimer first; continue only after the user agrees
      if (!mounted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      debugPrint('[协议] 到达调用点, 已同意标志=${prefs.getBool('agreed_terms_v1')}');
      await maybeShowTermsDialog(context, prefs);
      debugPrint('[协议] maybeShowTermsDialog 返回');

      // Show the announcement fetched by the splash screen (if any), then mark it read and clear it to avoid repeats
      if (!mounted) return;
      final pending = ref.read(pendingAnnouncementProvider);
      if (pending != null) {
        await showAnnouncementDialog(context, pending);
        // Write the read hash after the dialog closes (not at fetch time, so an unseen announcement is not marked read)
        final pendingHash = prefs.getString('_pending_announcement_hash');
        if (pendingHash != null) {
          await prefs.setString('seen_announcement_hash', pendingHash);
          await prefs.remove('_pending_announcement_hash');
        }
        ref.read(pendingAnnouncementProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _warmupWebView?.dispose();
    super.dispose();
  }

  void _preloadCharacterAvatars() async {
    final characters = await ref.read(characterListProvider.future);
    for (final c in characters) {
      final avatarPath = c.assets?.avatarPath;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        try {
          final resolved = await PathUtils.toAbsolutePath(avatarPath);
          final file = File(resolved);
          if (await file.exists() && mounted) {
            await precacheImage(
              ResizeImage(FileImage(file), width: 300),
              context,
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(_now);
    final homeBg = ref.watch(homeBackgroundProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // System chrome: status bar style follows the theme (dark background uses light icons, light background uses dark icons)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(        children: [
          // 1. Background layer: video / image-GIF / default gradient
          Positioned.fill(child: _buildBackground(homeBg)),

          // 2. Bottom-left: time + greeting
          Positioned(
            bottom: 96, // Clearance for the bottom navigation bar
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                TimeGreeting(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          // Bottom-right: daily oracle entry, directly above the announcement entry
          const Positioned(
            bottom: 240, // Directly above the announcement button (bottom:172)
            right: 24,
            child: DailyOracleEntry(),
          ),
          // Bottom-right: announcement entry (re-open manually, ignoring read state)
          Positioned(
            bottom: 172, // Raised to clear the floating ball at the bottom right (bottom:100)
            right: 24,
            child: GestureDetector(
              onTap: _openAnnouncementManually,
              child: Container(
                padding: DesignTokens.paddingCard,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: DesignTokens.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Opens the announcement center manually: tab layout (update + daily announcements).
  /// Ignores the read state, fetches and displays fresh content.
  Future<void> _openAnnouncementManually() async {
    await showAnnouncementCenter(context);
  }

  /// Picks the time-of-day seascape background (slots align with TimeGreeting semantics)
  String _timeBasedBackgroundAsset() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return 'assets/images/bg_dawn.jpg';
    if (hour >= 9 && hour < 16) return 'assets/images/bg_noon.jpg';
    if (hour >= 16 && hour < 19) return 'assets/images/bg_dusk.jpg';
    return 'assets/images/bg_night.jpg';
  }
  Widget _buildBackground(ChatBackground bg) {
    if (bg.type == BackgroundType.video && bg.imagePath != null) {
      return VideoBackground(path: bg.imagePath!);
    }
    if (bg.type == BackgroundType.image && bg.imagePath != null) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: DesignTokens.durationLg),
        child: Image.file(
          File(bg.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultGradient(),
        ),
      );
    }
    // No custom background set, so fall back to the time-of-day seascape
    return Image.asset(
      _timeBasedBackgroundAsset(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _defaultGradient(),
    );
  }

  Widget _defaultGradient() {
    // No gradient system; the default background is a solid darkBackground
    return const DecoratedBox(
      decoration: BoxDecoration(color: DesignTokens.darkBackground),
    );
  }
}
