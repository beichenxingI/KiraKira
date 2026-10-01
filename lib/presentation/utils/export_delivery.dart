// lib/presentation/utils/export_delivery.dart
/// Unified export delivery channel: let the user pick
/// "share / save to file" first, then execute.
///
/// - Save to file: FilePicker.saveFile — on mobile (since 8.3.7) `bytes` is
///   mandatory; omitting it throws "Bytes are required" on Android/iOS.
///   On desktop saveFile only returns a path without writing the file (and
///   macOS throws UnsupportedError when given `bytes`), so writeAsBytes must
///   be done manually.
/// - Share: write to a temp directory + SharePlus.instance.share (new API).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Delivery mode
enum ExportDeliveryMode { share, save }

/// Shows the "share / save to file" chooser (native AlertDialog; the webview
/// side already has the _showHtmlBottomSheet precedent).
Future<ExportDeliveryMode?> askExportDelivery(
  BuildContext context,
  String fileName,
) {
  return showDialog<ExportDeliveryMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('导出'),
      content: Text(fileName),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ExportDeliveryMode.save),
          child: const Text('保存到文件'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ExportDeliveryMode.share),
          child: const Text('分享'),
        ),
      ],
    ),
  );
}

/// Unified export delivery: when [mode] is given, runs that channel directly
/// (no context needed, suited to ask-then-generate-async flows); otherwise
/// shows the chooser with [context].
/// Returns the saved path (save mode) or null (cancel/share mode returns the
/// temp file path).
Future<String?> deliverExportFile({
  BuildContext? context,
  required String fileName,
  required Uint8List bytes,
  String? subject,
  String? ext,
  ExportDeliveryMode? mode,
}) async {
  var m = mode;
  if (m == null) {
    if (context == null) return null;
    m = await askExportDelivery(context, fileName);
    if (m == null) return null;
  }
  if (m == ExportDeliveryMode.save) {
    final path = await _saveBytes(fileName, bytes, ext);
    if (path != null && context != null && context.mounted) {
      coreToast(context, '已保存到: $path');
    }
    return path;
  }
  return _shareBytes(fileName, bytes, subject);
}

/// Saves to the user-chosen location. On mobile saveFile(bytes) writes the
/// file directly; on desktop saveFile only returns a path, so the write must
/// be done manually.
Future<String?> _saveBytes(String fileName, Uint8List bytes, String? ext) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: isMobile ? bytes : null,
    type: ext != null ? FileType.custom : FileType.any,
    allowedExtensions: ext != null ? [ext] : null,
  );
  if (path == null) return null;
  if (!isMobile) {
    await File(path).writeAsBytes(bytes);
  }
  return path;
}

/// Writes a temp file and shares it (same getTemporaryDirectory pattern as
/// existing exports).
Future<String?> _shareBytes(String fileName, Uint8List bytes, String? subject) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: subject),
  );
  return file.path;
}
