import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kirakira/presentation/providers/home_background_providers.dart';
import 'package:kirakira/presentation/providers/home_music_service.dart';
import 'package:kirakira/presentation/widgets/home/time_greeting.dart';
import 'package:kirakira/presentation/widgets/home/video_background.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/domain/services/announcement_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/screens/splash/announcement_dialog.dart';
import 'package:kirakira/presentation/providers/announcement_provider.dart';
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
bool _loadingAnnouncement = false;
  HeadlessInAppWebView? _warmupWebView;

  @override
  void initState() {
    super.initState();
    // 触发全局音乐服务初始化（它自己管播放和 App 生命周期）
    ref.read(homeMusicServiceProvider);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() => _now = DateTime.now()); },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 预热 WebView 引擎，进入聊天页时省掉初始化时间
      _warmupWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: '<html></html>'),
      );
      await _warmupWebView!.run();

      // 后台预解码角色头像进缓存
      _preloadCharacterAvatars();

      // 首次启动：强制先弹免责声明，同意后才继续
      if (!mounted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      debugPrint('[协议] 到达调用点, 已同意标志=${prefs.getBool('agreed_terms_v1')}');
      await maybeShowTermsDialog(context, prefs);
      debugPrint('[协议] maybeShowTermsDialog 返回');

      // 读取转圈页拉好的待弹公告（若有），弹完清空避免重复
      if (!mounted) return;
      final pending = ref.read(pendingAnnouncementProvider);
      if (pending != null) {
        showAnnouncementDialog(context, pending);
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

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(
        children: [
          // ── 1. 背景层：视频 / 图片-GIF / 默认渐变 ──────────────────
          Positioned.fill(child: _buildBackground(homeBg)),

          // ── 2. 左下角：时间 + 问候 ─────────────────────────────────
          Positioned(
            bottom: 96, // 留出底部导航栏的空间，不被压住
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
          // ── 右下角：公告入口（手动回看，无视已读记录）──────────────
          Positioned(
            bottom: 172, // 上移，避开右下角的极客Core悬浮球（bottom:100）
            right: 24,
            child: GestureDetector(
              onTap: _openAnnouncementManually,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: _loadingAnnouncement
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Color(0xFFa78bfa)),
                        ),
                      )
                    : const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFFa78bfa),
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// 手动打开公告：无视已读记录，主动拉取并弹窗。
  /// 用户手误点掉或想回看时用，拉不到给轻提示。
  Future<void> _openAnnouncementManually() async {
    if (_loadingAnnouncement) return;
    setState(() => _loadingAnnouncement = true);
    try {
      final announcement = await AnnouncementService().fetch();
      if (!mounted) return;
      if (announcement != null && announcement.hasContent) {
        showAnnouncementDialog(context, announcement);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂时没有拉取到公告')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告拉取失败，请检查网络')),
      );
    } finally {
      if (mounted) setState(() => _loadingAnnouncement = false);
    }
  }

  /// 根据当前时间选四时海景背景图（时段对齐 TimeGreeting 语义）
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
        duration: const Duration(milliseconds: 400),
        child: Image.file(
          File(bg.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultGradient(),
        ),
      );
    }
    // 用户没设自定义背景 → 按当前时间显示四时海景
    return Image.asset(
      _timeBasedBackgroundAsset(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _defaultGradient(),
    );
  }

  Widget _defaultGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        ),
      ),
    );
  }
}