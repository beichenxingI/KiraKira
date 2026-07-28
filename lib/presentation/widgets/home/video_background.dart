import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 循环播放的视频背景，自动静音（声音交给独立背景音乐控制）
class VideoBackground extends StatefulWidget {
  final String path;
  final bool muted;
  const VideoBackground({super.key, required this.path, this.muted = true});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(File(widget.path));
    _controller = c;
    await c.initialize();
    await c.setLooping(true);
    await c.setVolume(widget.muted ? 0 : 1);
    await c.play();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoBackground old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _init();
    }
  }

  /// 供外部生命周期调用
  void pause() => _controller?.pause();
  void resume() => _controller?.play();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    // 用 FittedBox + cover 铺满全屏
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}