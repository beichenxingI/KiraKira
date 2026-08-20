// lib/core/utils/file_utils.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 文件读取与编码工具函数
///
/// 提取自 `chat_providers.dart::_encodeFileToB64` 与
/// `webview_chat_stage.dart::_readFileAsB64` 两处重复实现，
/// 统一为单一真相源。
///
/// 注意：[encodeFileToBase64] 为同步函数，**必须**在 `compute` 或
/// 独立 isolate 中调用以避免阻塞主线程。主线程请使用
/// [encodeFileToBase64Async] 异步包装。

/// 将文件读取为 Base64 字符串（同步版，供 `compute` 调用）
///
/// 在独立 isolate 中执行时使用；切勿直接在主 isolate 调用，
/// 否则大文件会阻塞 UI 线程。
String encodeFileToBase64(String path) {
  return base64Encode(File(path).readAsBytesSync());
}

/// 将文件读取为 Base64 字符串（异步版，主线程可用）
///
/// 内部通过 [compute] 在独立 isolate 中执行，避免阻塞主线程。
/// 返回的 Base64 字符串不含 data URL 前缀。
Future<String> encodeFileToBase64Async(String path) {
  return compute(encodeFileToBase64, path, debugLabel: 'encodeFileToBase64');
}
