import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// KiraKira 通用设计组件 · 实色层次方案
/// 全部读 Theme，明暗主题自动适配；只负责外观，不绑定页面布局。

/// 实色卡片:大圆角 + 双层柔阴影(日间)/ 表面层级+高光边(夜间),做出"浮起"。
class KiraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const KiraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 夜间:表面提亮 + 高光边,不靠阴影;日间:纯卡片色 + 双层柔阴影
    final List<BoxShadow> shadows = isDark
        ? const []
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ];

    final cardRadius = BorderRadius.circular(DesignTokens.radiusCard);

    return Container(
      margin: margin ?? DesignTokens.marginCard,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: cardRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : theme.dividerColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: shadows,
      ),
      // 去掉 clipBehavior: Clip.antiAlias — child不会超出圆角,无需裁剪,省saveLayer
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        child: onTap != null
            ? InkWell(
                borderRadius: cardRadius,
                onTap: onTap,
                child: Padding(
                  padding: padding ?? DesignTokens.paddingCard,
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? DesignTokens.paddingCard,
                child: child,
              ),
      ),
    );
  }
}

/// 分组容器:强调色小标题 + 一张卡片包裹一组内容,分组间敢留白。
class KiraSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;

  const KiraSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLg,
              vertical: DesignTokens.spaceSm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: labelColor),
                  const SizedBox(width: DesignTokens.spaceSm),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
              child: KiraCard(
                padding: EdgeInsets.zero,
                child: child,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

/// 微渐变卡片：同色系、小跨度、有光影方向，营造质感而不喧宾夺主。
class KiraGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const KiraGradientCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = DesignTokens.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.cardColor;
    // 微渐变：从左上"受光面"稍亮，到右下"背光面"稍暗，跨度极小(约6%明度)
    final lighter = Color.lerp(base, Colors.white, isDark ? 0.06 : 0.5)!;
    final darker = Color.lerp(base, Colors.black, isDark ? 0.12 : 0.03)!;
    return Container(
      margin: margin,
      padding: padding ?? DesignTokens.paddingCard,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighter, base, darker],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          // 顶部高光边：模拟光线打在上缘，是"高级感"的关键细节
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.5),
          width: 0.8,
        ),
        // 宪法:深色靠明度分层不靠重阴影 → 深色无阴影,浅色仅 shadowLevel1
        boxShadow: isDark ? const [] : DesignTokens.shadowLevel1,
      ),
      child: child,
    );
  }
}

/// 列表项：图标 + 标题 + 副标题 + 尾部控件，统一内边距与圆角高亮。
class KiraListTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KiraListTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary)
          : null,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.textTheme.bodySmall?.color))
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
    );
  }
}

/// 圆润胶囊开关：柔和轨道 + 圆形滑块,替代方形系统开关。
class KiraSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KiraSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = theme.colorScheme.primary;
    final track = value
        ? active
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.10));
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: DesignTokens.durationSm),
        curve: DesignTokens.curveFade,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: DesignTokens.durationSm),
          curve: DesignTokens.curveFade,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 带圆润开关的列表项:复用 KiraListTile 的排版,整行可点切换。
class KiraSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KiraSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KiraListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: KiraSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}