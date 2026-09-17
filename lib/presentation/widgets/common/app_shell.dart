import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_glass_bar.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // [极客Core迁移 P7] 悬浮球(_AdvancedFab)已随极客Core删除;
    // advancedModeProvider 保留(仍由 providers_registry 登记)。
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // true 才让内容滚到底栏底下,blur 有东西可模糊
      body: Stack(children: [
        // 聊天背景只在这里,不再是全局的
        child,
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  KiraGlassBar(
                    enabledBlur: enableBlur,
                    radius: BorderRadius.circular(DesignTokens.radiusFull),
                    child: Container(
                      height: 64,
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
                          const SizedBox(width: 64),
                          _navItem(context, Icons.api_rounded, 'API服务', 3),
                          _navItem(context, Icons.settings_rounded, '设置', 4),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 34,
                    child: _centerButton(context, sel == 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerButton(BuildContext context, bool isActive) {
    return GestureDetector(
      onTap: () => onTap(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: const Cubic(0.175, 0.885, 0.32, 1.275),
        width: 56,
        height: 56,
        transform: Matrix4.identity()
          ..scale(isActive ? 1.1 : 0.92)
          ..translate(0.0, isActive ? -5.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DesignTokens.primaryLight,
              DesignTokens.primary,
            ],
          ),
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary
                  .withValues(alpha: isActive ? 0.6 : 0.4),
              blurRadius: isActive ? 20 : 15,
              offset: Offset(0, isActive ? 6 : 4),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome,
            color: Colors.white, size: 28),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int idx) {
    final active = sel == idx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? DesignTokens.darkTextSecondary
        : DesignTokens.lightTextSecondary;
    final color = active ? DesignTokens.primary : inactiveColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: const Cubic(0.34, 1.56, 0.64, 1.0),
          transform: Matrix4.identity()
            ..scale(active ? 1.0 : 0.92)
            ..translate(0.0, active ? -2.0 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: active ? 1.0 : 0.6,
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: active ? 1.0 : 0.6,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeCaption,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
