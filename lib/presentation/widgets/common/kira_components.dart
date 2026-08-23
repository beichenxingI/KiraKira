import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_grouped_tile.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';

/// KiraKira 通用设计组件 · iOS 化宪法 v2 版
/// 深色零阴影、0.5 separator 细边、Cupertino 控件、按压=缩+暗。
/// 全部读 Theme，明暗主题自动适配。

/// 实色卡片:圆角 12、零阴影、仅浅色留 0.5 separator 细边。
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

    final cardRadius = BorderRadius.circular(DesignTokens.radiusCard);

    return Container(
      margin: margin ?? DesignTokens.marginCard,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: cardRadius,
        // 宪法 v2:深色完全无边框;浅色 0.5 separator 细边
        border: isDark
            ? null
            : Border.all(color: theme.dividerColor, width: 0.5),
      ),
      // 去掉 clipBehavior(省 saveLayer);KiraPressable 自带按需裁切
      child: onTap != null
          ? KiraPressable(
              onTap: onTap,
              borderRadius: cardRadius,
              child: Padding(
                padding: padding ?? DesignTokens.paddingCard,
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? DesignTokens.paddingCard,
              child: child,
            ),
    );
  }
}

/// inset-grouped 分组(A-T4b):**一组一张卡**。
/// 组头 = 13pt 次级色小字;组内 children 竖排共享一张圆角 10 卡,
/// 行间自动插 0.5px separator(indent 16)。
///
/// 表单/滑块等"组内是一整块"的场景用 [KiraSection.plain](不插分隔线)。
class KiraSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final bool _plain;

  const KiraSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  }) : _plain = false;

  /// plain 形态:组内是一个整体(滑块组/表单),不自动插分隔线
  KiraSection.plain({
    super.key,
    required this.title,
    required Widget child,
    this.icon,
  })  : children = [child],
        _plain = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = theme.textTheme.bodyMedium?.color;

    final cardRadius = BorderRadius.circular(DesignTokens.radiusGroupedCard);

    // 组内 items:plain 形态直接摆 child;默认形态行间插 0.5 separator
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (!_plain && i > 0) {
        items.add(Divider(
          height: 0.5,
          thickness: 0.5,
          indent: DesignTokens.spaceMd,
          color: theme.dividerColor,
        ));
      }
      items.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 组头:13pt、次级色、w600、letterSpacing 0.5(左距 = 边距 16 + 12)
          Padding(
            padding: const EdgeInsets.only(
              left: DesignTokens.spaceMd + 12,
              right: DesignTokens.spaceMd,
              bottom: DesignTokens.spaceSm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: labelColor),
                  const SizedBox(width: DesignTokens.spaceXs),
                ],
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
          // 一组一张卡
          Container(
            margin: DesignTokens.paddingScreen,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.cardColor, // darkSurface / lightSurface(白)
              borderRadius: cardRadius,
              border: isDark
                  ? null
                  : Border.all(color: theme.dividerColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

/// 微渐变卡片:仅主页欢迎/营销位允许使用(设置族禁用渐变卡,D 块铁律)。
/// 圆角 radiusCard(12)、零阴影;深色只留顶部一条高光边。
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
    this.radius = DesignTokens.radiusCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.cardColor;
    // 微渐变:从左上"受光面"稍亮,到右下"背光面"稍暗,跨度极小
    final lighter = Color.lerp(base, Colors.white, isDark ? 0.06 : 0.5)!;
    final darker = Color.lerp(base, Colors.black, isDark ? 0.12 : 0.03)!;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: padding ?? DesignTokens.paddingCard,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lighter, base, darker],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: isDark
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
              ),
              child: child,
            ),
            // 深色只留顶部高光边(宪法 A-T4e)
            if (isDark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 0.8,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 列表项:图标 + 标题 + 副标题 + 尾部控件。
/// ⚠️ 图标色不再强制主色——主色只留"可点主行动"按钮(A-T4d);
/// 分组卡内请优先用 KiraGroupedTile。
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
          ? Icon(icon, color: theme.textTheme.bodySmall?.color)
          : null,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
    );
  }
}

/// 开关:CupertinoSwitch 薄封装(A-T4c),激活色 = 主题星海紫。
class KiraSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KiraSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: Theme.of(context).colorScheme.primary,
    );
  }
}

/// 带开关的列表项:整行可点切换(内部已是 CupertinoSwitch)。
/// 在分组卡内使用请用 KiraGroupedTile(trailing: KiraSwitch(...))。
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
    return KiraGroupedTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: KiraSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}
