// lib/presentation/utils/export_delivery.dart
/// [问题1] 统一导出交付通道:先让用户选「分享 / 保存到文件」,再执行。
///
/// - 保存到文件:FilePicker.saveFile —— 移动端(8.3.7 起)必传 bytes,
///   不传会在 Android/iOS 抛 "Bytes are required" 异常;桌面端 saveFile
///   只返回路径不写文件(且 macOS 传 bytes 会抛 UnsupportedError),
///   需自行 writeAsBytes。
/// - 分享:写临时目录 + SharePlus.instance.share(新 API)。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 交付模式
enum ExportDeliveryMode { share, save }

/// 弹出「分享 / 保存到文件」选择框(原生 AlertDialog,webview 侧已有
/// _showHtmlBottomSheet 先例)。
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

/// 统一导出交付:[mode] 指定时直接执行对应通道(不依赖 context,适合
/// 先问后异步生成的场景);否则用 [context] 弹选择框。
/// 返回保存路径(save 模式)或 null(取消/分享模式返回临时文件路径)。
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

/// 保存到用户选择的位置。移动端由 saveFile(bytes) 直接写入;
/// 桌面端 saveFile 只返回路径,需自行写入。
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

/// 写临时文件并分享(与既有导出的 getTemporaryDirectory 模式一致)。
Future<String?> _shareBytes(String fileName, Uint8List bytes, String? subject) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: subject),
  );
  return file.path;
}
