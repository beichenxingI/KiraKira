import 'package:flutter/material.dart';

class KiraMenuItem {
  final String id;
  final String label;
  final IconData? icon;
  final List<KiraMenuItem> children;
  final bool enabled;
  final bool isDestructive;

  const KiraMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.children = const [],
    this.enabled = true,
    this.isDestructive = false,
  });

  bool get hasChildren => children.isNotEmpty;
}
