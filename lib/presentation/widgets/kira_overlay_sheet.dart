import 'dart:ui';
import 'package:flutter/material.dart';

class MenuGroup {
  final String title;
  final List<MenuItem> items;
  MenuGroup(this.title, this.items);
}

class MenuItem {
  final String title;
  final VoidCallback onTap;
  MenuItem(this.title, this.onTap);
}

void showKiraOverlay(BuildContext context, String title, List<MenuGroup> groups, {VoidCallback? onClose}) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => GestureDetector(
      onDown: (_) => {},
      behavior: HitTestBehavior.translucent,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => {entry?.remove(); onClose?.call();},
              child: Container(
                color: Colors.black54,
              ),
            ),
            Column(children: [
              Spacer(),
              Center(child: Empty()),
              Spacer(),
            ]),
          ],
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  final OverlayState overlay = Overlay.of(context);
  overlay.insert(entry);
}
