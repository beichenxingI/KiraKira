import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/presentation/providers/background_providers.dart';

class DraggableBackgroundButton extends ConsumerStatefulWidget {
  const DraggableBackgroundButton({super.key});
  @override
  ConsumerState<DraggableBackgroundButton> createState() => _DraggableBackgroundButtonState();
}

class _DraggableBackgroundButtonState extends ConsumerState<DraggableBackgroundButton> {
  double _dx = 0.88;
  double _dy = 0.82;
  bool _loaded = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dx = (prefs.getDouble('bg_btn_dx') ?? 0.88).clamp(0.0, 1.0);
      _dy = (prefs.getDouble('bg_btn_dy') ?? 0.82).clamp(0.0, 1.0);
      _loaded = true;
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bg_btn_dx', _dx);
    await prefs.setDouble('bg_btn_dy', _dy);
  }

  Future<String?> _copyToAppDir(String sourcePath) async {
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/backgrounds');
      if (!await dir.exists()) await dir.create(recursive: true);
      await for (final entity in dir.list()) {
        if (entity is File) await entity.delete();
      }
      final ext = sourcePath.split('.').last;
      final dest = '${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(sourcePath).copy(dest);
      return dest;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickAndSetBackground() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    final stablePath = await _copyToAppDir(xFile.path);
    if (stablePath == null) return;
    if (!mounted) return;
    ref.read(globalBackgroundProvider.notifier).setBackground(ChatBackground.imagePath(stablePath));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final safe = media.padding;
    final sw = media.size.width;
    final sh = media.size.height;
    final bs = 48.0;
    final minX = safe.left + bs / 2;
    final maxX = sw - safe.right - bs / 2;
    final minY = safe.top + bs / 2;
    final maxY = sh - safe.bottom - bs / 2;
    final x = (minX + _dx * (maxX - minX)).clamp(minX, maxX);
    final y = (minY + _dy * (maxY - minY)).clamp(minY, maxY);

    return Positioned(
      left: x - bs / 2,
      top: y - bs / 2,
      child: GestureDetector(
        onTap: _pickAndSetBackground,
        onLongPressStart: (_) {},
        onLongPressMoveUpdate: (d) {
          setState(() {
            _dx = ((d.globalPosition.dx - minX) / (maxX - minX)).clamp(0.0, 1.0);
            _dy = ((d.globalPosition.dy - minY) / (maxY - minY)).clamp(0.0, 1.0);
          });
        },
        onLongPressEnd: (_) => _savePosition(),
        child: Container(
          width: bs,
          height: bs,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFa78bfa).withValues(alpha: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

String? validateBackgroundPath(String? path) {
  if (path == null || path.isEmpty) return null;
  return File(path).existsSync() ? path : null;
}