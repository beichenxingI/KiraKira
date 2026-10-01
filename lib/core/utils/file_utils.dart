// lib/core/utils/file_utils.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// File reading and encoding utilities.
///
/// Extracted from the duplicated implementations in
/// `chat_providers.dart::_encodeFileToB64` and
/// `webview_chat_stage.dart::_readFileAsB64`, unified into a single source
/// of truth.
///
/// [encodeFileToBase64] is synchronous and **must** be called inside
/// `compute` or a separate isolate to avoid blocking the main thread. Use
/// [encodeFileToBase64Async] on the main thread.

/// Reads a file into a Base64 string (synchronous, for `compute`).
///
/// Run in a separate isolate; never call it directly on the main isolate,
/// otherwise large files block the UI thread.
String encodeFileToBase64(String path) {
  return base64Encode(File(path).readAsBytesSync());
}

/// Reads a file into a Base64 string (async, safe on the main thread).
///
/// Runs in a separate isolate via [compute] to avoid blocking the main
/// thread. The returned Base64 string has no data URL prefix.
Future<String> encodeFileToBase64Async(String path) {
  return compute(encodeFileToBase64, path, debugLabel: 'encodeFileToBase64');
}
