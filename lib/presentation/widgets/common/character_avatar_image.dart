import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

// TODO(token, pending approval): avatarFallback 11 colors (lightness grayscale + 1 primary) as missing-image fallback,
// proposal in outline §4. Until approved, fall back to darkSurface/surfaceContainerHighest.

/// Static cache of resolved paths: each imagePath is resolved only once,
/// avoiding an async resolution on every rebuild that flashes a placeholder frame (root cause of the white image).
final Map<String, String> _resolvedPathCache = {};

Future<String> _resolveAvatarPath(String imagePath) async {
  final cached = _resolvedPathCache[imagePath];
  if (cached != null) return cached;
  final resolved = await PathUtils.toAbsolutePath(imagePath);
  _resolvedPathCache[imagePath] = resolved;
  return resolved;
}

String? _cachedPath(String imagePath) => _resolvedPathCache[imagePath];

/// Placeholder background color while loading: darkSurface in dark mode, Theme-adapted in light mode
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
        // Decode width = the widget's actually allocated width x device pixel ratio,
        // so small list thumbnails decode small and large detail images decode large, staying sharp at any size.
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
    // Circular avatar diameter is about 2*radius; leaving headroom for high-DPI screens, decode width is radius*6.
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
    // Background image covers the full screen and needs higher resolution, so the downsample width is larger.
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