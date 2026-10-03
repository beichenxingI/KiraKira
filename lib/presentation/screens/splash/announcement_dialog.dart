import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/data/models/announcement.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';

/// Shows the announcement dialog.
///
/// Uses showKiraDialog for the PiuPiu soft-bounce animation, matching the
/// project-wide dialog feel. Frosted translucent glass with star accents,
/// consistent with the app's overall clean aesthetic. The image and download
/// button show or hide based on the available content; everything degrades gracefully.
Future<void> showAnnouncementDialog(
  BuildContext context,
  Announcement announcement,
) {
  return showKiraDialog(
    context: context,
    barrierColor: Colors.black54,
    dialog: _AnnouncementCard(announcement: announcement),
  );
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  /// Type theme: update = orange, daily = coral pink
  (IconData, Color) get _typeTheme => switch (announcement.type) {
        AnnouncementType.update =>
          (Icons.rocket_launch, DesignTokens.statusWarning),
        AnnouncementType.daily => (Icons.auto_awesome, DesignTokens.primary),
      };

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
    final (icon, accent) = _typeTheme;
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
          // Perf: BackdropFilter (sigma 20) removed — the per-frame blur was a frame-drop
          // source on dialog pop. Opacity raised so the card stays readable as a solid
          // translucent surface over the dimmed barrier.
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  DesignTokens.darkBackground.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
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
                              _buildTitle(icon, accent),
                              const SizedBox(height: 14),
                              if (announcement.content.trim().isNotEmpty)
                                MarkdownBody(
                                  data: announcement.content,
                                  shrinkWrap: true,
                                  softLineBreak: true,
                                  styleSheet:
                                      MarkdownStyleSheet.fromTheme(
                                              Theme.of(context))
                                          .copyWith(
                                    p: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                    h1: TextStyle(
                                      color: accent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    h2: TextStyle(
                                      color: accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    h3: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    listBullet: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                    strong: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    a: TextStyle(
                                      color: accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _buildActions(context),
                    ],
                  ),
                  // Close button in the top-right corner
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

  Widget _buildTitle(IconData icon, Color accent) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
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
      padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd,
          DesignTokens.spaceXs, DesignTokens.spaceMd, DesignTokens.spaceMd),
      child: Row(
        children: [
          if (announcement.hasDownload)
            Expanded(
              child: CorePrimaryButton(
                label: '前往下载',
                icon: Icons.download,
                onPressed: () => _openDownload(context),
              ),
            ),
          if (announcement.hasDownload) const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: CoreSecondaryButton(
              label: '知道了',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
