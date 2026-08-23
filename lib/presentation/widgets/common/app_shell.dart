import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_glass_bar.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/providers/advanced_mode_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advanced = ref.watch(advancedModeProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // true 才让内容滚到底栏底下,blur 有东西可模糊
      body: Stack(children: [
        // 聊天背景只在这里,不再是全局的
        child,
        // 极客Core悬浮球:只在高级模式开启时显示
        if (advanced)
          Positioned(
            right: 16,
            // 动态避让底栏:安全区 + 底栏高(62) + 底栏下边距(12) + 间距 16
            bottom: MediaQuery.paddingOf(context).bottom + 62 + 12 + 16,
            child: const _AdvancedFab(),
          ),
        // 底栏浮在最上层,和背景叠层,毛玻璃生效
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _KiraNav(
            sel: _calcIndex(context),
            onTap: (i) => _onTap(context, i),
          ),
        ),
      ]),
    );
  }

  static int _calcIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/characters')) return 0;
    if (path == '/chats') return 1;
    if (path == '/' || path.startsWith('/chat/')) return 2;
    if (path.startsWith('/ai-config')) return 3;
    if (path.startsWith('/settings')) return 4;
    return 2;
  }

  static void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/characters'); break;
      case 1: context.go('/chats'); break;
      case 2: context.go('/'); break;
      case 3: context.go('/ai-config'); break;
      case 4: context.go('/settings'); break;
    }
  }
}

/// 极客Core独立悬浮球,不进底栏,不破坏五个居中
/// B-T1:去紫辉阴影,KiraGlassBar 壳 + primary 图标,KiraPressable 按压。
class _AdvancedFab extends StatelessWidget {
  const _AdvancedFab();

  @override
  Widget build(BuildContext context) {
    return KiraPressable(
      onTap: () => context.push('/advanced'),
      child: KiraGlassBar(
        radius: BorderRadius.circular(DesignTokens.radiusFull),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.auto_awesome,
              color: DesignTokens.primary, size: 22),
        ),
      ),
    );
  }
}

class _KiraNav extends StatelessWidget {
  final int sel;
  final ValueChanged<int> onTap;
  const _KiraNav({required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 聊天 tab(/,index 2)关闭 blur:WebView 平台视图规避(A-T6)
    final enableBlur = sel != 2;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 62,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 胶囊条:只放四项,中间留空;毛玻璃壳(聊天 tab 退化半透明)
                  KiraGlassBar(
                    enabledBlur: enableBlur,
                    radius: BorderRadius.circular(DesignTokens.radiusFull),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusFull),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _navItem(context, Icons.person_rounded, '角色卡', 0),
                          _navItem(context, Icons.history_rounded, '聊天回忆', 1),
                          const SizedBox(width: 56), // 给中间圆球留位
                          _navItem(context, Icons.api_rounded, 'API服务', 3),
                          _navItem(context, Icons.settings_rounded, '设置', 4),
                        ],
                      ),
                    ),
                  ),
                  // 中间圆球:单独浮起,比胶囊高一点
                  Positioned(
                    bottom: 16,
                    child: _centerButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return KiraPressable(
      onTap: () => onTap(2),
      pressScale: 0.93, // 球缩放放大一点,品牌主按钮手感
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignTokens.primary,
          // iOS 感:顶部 1px 高光边,无投影
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: const Icon(Icons.chat_bubble_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int idx) {
    final active = sel == idx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? DesignTokens.darkTextTertiary
        : DesignTokens.lightTextTertiary;
    final c = active ? DesignTokens.primary : inactive;

    return KiraPressable(
      onTap: () => onTap(idx),
      scaleEnabled: false, // 导航项不缩放,只 opacity 反馈
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: c),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
