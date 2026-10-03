import 'dart:io';

import 'package:flutter/services.dart';

/// Reads the Android API level (SDK_INT) through a platform channel, cached per process.
/// Non-Android platforms report 0 (callers treat it as "unknown / oldest").
class AndroidVersion {
  static const MethodChannel _channel = MethodChannel('com.KiraKira/platform');
  static int? _cachedSdkInt;

  static Future<int> get sdkInt async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    if (!Platform.isAndroid) {
      _cachedSdkInt = 0;
      return 0;
    }
    try {
      final v = await _channel.invokeMethod<int>('getAndroidSdkInt');
      _cachedSdkInt = v ?? 0;
    } catch (_) {
      // Channel missing (e.g. older native build): treat as unknown.
      _cachedSdkInt = 0;
    }
    return _cachedSdkInt!;
  }
}
