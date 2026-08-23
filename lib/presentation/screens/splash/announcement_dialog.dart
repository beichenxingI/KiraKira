import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/data/models/announcement.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// 弹出公告对话框
///
/// 半透明毛玻璃 + 星星点缀，与 app 整体清新美学统一。
/// 图片、下载按钮按内容有无自动显隐，全部可降级。
Future<void> showAnnouncementDialog(
  BuildContext context,
  Announcement announcement,
) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _AnnouncementCard(announcement: announcement),
  );
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  Future<void> _openDownload(BuildContext context) async {
    final uri = Uri.tryParse(announcement.downloadUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.1,
        vertical: size.height * 0.1,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.8,
          maxHeight: size.height * 0.8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    DesignTokens.darkBackground.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DesignTokens.primary.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (announcement.hasImage) _buildImage(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTitle(),
                              const SizedBox(height: 14),
                              if (announcement.content.trim().isNotEmpty)
                                Text(
                                  announcement.content,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _buildActions(context),
                    ],
                  ),
                  // 右上角关闭按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Image.network(
        announcement.imageUrl,
        width: double.infinity,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 160,
            color: Colors.white.withValues(alpha: 0.05),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, color: DesignTokens.primary, size: 20),
        const SizedBox(width: DesignTokens.spaceSm),
        Expanded(
          child: Text(
            announcement.title.trim().isNotEmpty ? announcement.title : '公告',
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.fontSizeXl,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd, DesignTokens.spaceXs, DesignTokens.spaceMd, DesignTokens.spaceMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (announcement.hasDownload)
            TextButton.icon(
              onPressed: () => _openDownload(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('前往下载'),
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.primary,
              ),
            ),
          const SizedBox(width: DesignTokens.spaceSm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.8),
            ),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}