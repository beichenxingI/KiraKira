import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/widgets/chat/chat_background_widget.dart';
import 'package:kirakira/presentation/widgets/chat/draggable_background_button.dart';
import 'package:kirakira/presentation/providers/advanced_mode_provider.dart';
import 'package:kirakira/presentation/screens/settings/advanced_screen.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advanced = ref.watch(advancedModeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(children: [
        ChatBackgroundWidget(child: child),
        const DraggableBackgroundButton(),
      ]),
      bottomNavigationBar: _KiraNav(sel: _calcIndex(context, advanced), onTap: (i) => _onTap(context, i, advanced), advanced: advanced),
    );
  }

  static int _calcIndex(BuildContext context, bool advanced) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/characters')) return 0;
    if (path == '/chats') return 1;
    if (path == '/' || path.startsWith('/chat/')) return 2;
    if (path.startsWith('/ai-config')) return 3;
    if (path.startsWith('/settings')) return 4;
    if (advanced && path.startsWith('/advanced')) return 5;
    return 2;
  }

  static void _onTap(BuildContext context, int i, bool advanced) {
    switch (i) {
      case 0: context.go('/characters'); break;
      case 1: context.go('/chats'); break;
      case 2: context.go('/'); break;
      case 3: context.go('/ai-config'); break;
      case 4: context.go('/settings'); break;
      case 5: if (advanced) context.go('/advanced'); break;
    }
  }
}

class _KiraNav extends StatelessWidget {
  final int sel; final ValueChanged<int> onTap; final bool advanced;
  const _KiraNav({required this.sel, required this.onTap, this.advanced = false});

  @override
  Widget build(BuildContext context) {
    final items = [
      _navItem(Icons.person_rounded, '\u89d2\u8272\u5361', 0),
      _navItem(Icons.history_rounded, '\u804a\u5929\u56de\u5fc6', 1),
      _navItem(Icons.chat_bubble_rounded, '\u4e3b\u754c\u9762', 2, center: true),
      _navItem(Icons.api_rounded, 'API\u670d\u52a1', 3),
      _navItem(Icons.settings_rounded, '\u8bbe\u7f6e', 4),
    ];
    if (advanced) items.add(_navItem(Icons.auto_awesome, '\u9ad8\u7ea7', 5));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1a1a2e).withValues(alpha: 0.85), Color(0xFF16213e).withValues(alpha: 0.92)]),
            border: Border(top: BorderSide(color: Color(0xFFa78bfa).withValues(alpha: 0.3))),
          ),
          child: SafeArea(child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: items))),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx, {bool center = false}) {
    final active = sel == idx;
    final c = active ? Color(0xFFa78bfa) : Colors.white.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: () => onTap(idx), behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300), curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: center ? 14 : 8, vertical: center ? 6 : 4),
        decoration: center ? BoxDecoration(shape: BoxShape.circle, gradient: active ? LinearGradient(colors: [Color(0xFFa78bfa), Color(0xFF60a5fa)]) : null, color: active ? null : Colors.white.withValues(alpha: 0.08), boxShadow: active ? [BoxShadow(color: Color(0xFFa78bfa).withValues(alpha: 0.4), blurRadius: 20)] : null) : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: center ? 28 : 24, color: center && active ? Colors.white : c),
          SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: c)),
        ]),
      ),
    );
  }
}