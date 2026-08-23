import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
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
      backgroundColor: DesignTokens.darkBackground,
      extendBody: false, // 让背景延伸到底栏后面，毛玻璃才有内容可模糊
      body: Stack(children: [
        // 聊天背景只在这里，不再是全局的
        child,
        // 极客Core悬浮球：只在高级模式开启时显示
        if (advanced)
          Positioned(
            right: 16,
            bottom: 100,
            child: _AdvancedFab(),
          ),
        // 底栏浮在最上层，和背景叠层，毛玻璃生效
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

/// 极客Core独立悬浮球，不进底栏，不破坏五个居中
class _AdvancedFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/advanced'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: DesignTokens.durationMd),
        curve: DesignTokens.curveStandard,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignTokens.primary,
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
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
                  // 胶囊条：只放四项，中间留空
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      // 实色（不透明）
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                  // 中间圆球：单独浮起，比胶囊高一点
                  Positioned(
                    bottom: 14,
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
    final active = sel == 2;
    return GestureDetector(
      onTap: () => onTap(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: DesignTokens.durationMd),
        curve: DesignTokens.curveStandard,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignTokens.primary,
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary.withValues(alpha: active ? 0.55 : 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26),
      ),
    );
  }

Widget _navItem(BuildContext context, IconData icon, String label, int idx, {bool center = false}) {
    final active = sel == idx;
    final c = active
        ? DesignTokens.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: DesignTokens.durationMd),
        curve: DesignTokens.curveStandard,
        padding: EdgeInsets.symmetric(
          horizontal: center ? 14 : 8,
          vertical: center ? 6 : 4,
        ),
        decoration: center
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? DesignTokens.primary
                    : Colors.white.withValues(alpha: 0.08),
                boxShadow: active
                    ? [BoxShadow(
                        color: DesignTokens.primary.withValues(alpha: 0.45),
                        blurRadius: 20,
                      )]
                    : null,
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: center ? 28 : 24,
                color: center && active ? Colors.white : c),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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