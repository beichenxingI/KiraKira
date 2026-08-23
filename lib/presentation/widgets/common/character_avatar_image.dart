import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

// TODO(token·待批准): avatarFallback 11 色(明度灰阶+1 主色)无图兜底,
// 提案见总纲 §4。未批准前用 darkSurface/surfaceContainerHighest 兜底。

/// 已解析路径的静态缓存：同一个 imagePath 只解析一次，
/// 避免每次重建都异步解析导致闪一帧占位符（白图根因）。
final Map<String, String> _resolvedPathCache = {};

Future<String> _resolveAvatarPath(String imagePath) async {
  final cached = _resolvedPathCache[imagePath];
  if (cached != null) return cached;
  final resolved = await PathUtils.toAbsolutePath(imagePath);
  _resolvedPathCache[imagePath] = resolved;
  return resolved;
}

String? _cachedPath(String imagePath) => _resolvedPathCache[imagePath];

/// 加载占位底色:深色用 darkSurface,浅色由 Theme 适配
Color _placeholderColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? DesignTokens.darkSurface
      : theme.colorScheme.surfaceContainerHighest;
}

/// Widget that displays character avatar image
/// Handles both absolute and relative paths for mobile compatibility
class CharacterAvatarImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterAvatarImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 按控件实际分配宽度 × 屏幕像素密度算解码宽度，
        // 列表小图用小尺寸、详情大图用大尺寸，自适应不糊。
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final logicalW =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 240.0;
        final decodeWidth = (logicalW * dpr).round().clamp(120, 1440);

        final cached = _cachedPath(imagePath);
        if (cached != null) {
          return Image.file(
            File(cached),
            fit: fit,
            cacheWidth: decodeWidth,
            errorBuilder: errorBuilder,
          );
        }
        return FutureBuilder<String>(
          future: _resolveAvatarPath(imagePath),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.file(
                File(snapshot.data!),
                fit: fit,
                cacheWidth: decodeWidth,
                errorBuilder: errorBuilder,
              );
            } else if (snapshot.hasError) {
              return Image.file(
                File(imagePath),
                fit: fit,
                cacheWidth: decodeWidth,
                errorBuilder: errorBuilder,
              );
            } else {
              return Container(
                color: _placeholderColor(context),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(DesignTokens.primary),
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// Circular avatar variant
class CharacterAvatarCircle extends StatelessWidget {
  final String imagePath;
  final double radius;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterAvatarCircle({
    super.key,
    required this.imagePath,
    this.radius = 28,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // 圆形头像直径约 2*radius，按高分屏预留，解码宽度取 radius*6。
    final int decodeWidth = (radius * 6).round();
    final cached = _cachedPath(imagePath);
    if (cached != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: ResizeImage(
          FileImage(File(cached)),
          width: decodeWidth,
        ),
        onBackgroundImageError:
            errorBuilder != null ? (exception, stackTrace) {} : null,
      );
    }
    return FutureBuilder<String>(
      future: _resolveAvatarPath(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: ResizeImage(
              FileImage(File(snapshot.data!)),
              width: decodeWidth,
            ),
            onBackgroundImageError:
                errorBuilder != null ? (exception, stackTrace) {} : null,
          );
        } else if (snapshot.hasError) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: ResizeImage(
              FileImage(File(imagePath)),
              width: decodeWidth,
            ),
            onBackgroundImageError:
                errorBuilder != null ? (exception, stackTrace) {} : null,
          );
        } else {
          return CircleAvatar(
            radius: radius,
            backgroundColor: _placeholderColor(context),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(DesignTokens.primary),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Background image variant
class CharacterBackgroundImage extends StatelessWidget {
  final String imagePath;
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  const CharacterBackgroundImage({
    super.key,
    required this.imagePath,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // 背景图铺满屏幕，需要较高分辨率，降采样宽度给大一些。
    const int decodeWidth = 1080;
    final cached = _cachedPath(imagePath);
    if (cached != null) {
      return Image.file(
        File(cached),
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        errorBuilder:
            errorBuilder ?? (_, __, ___) => Container(color: Colors.black),
      );
    }
    return FutureBuilder<String>(
      future: _resolveAvatarPath(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            errorBuilder:
                errorBuilder ?? (_, __, ___) => Container(color: Colors.black),
          );
        } else if (snapshot.hasError) {
          return Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            errorBuilder:
                errorBuilder ?? (_, __, ___) => Container(color: Colors.black),
          );
        } else {
          return Container(color: Colors.black);
        }
      },
    );
  }
}