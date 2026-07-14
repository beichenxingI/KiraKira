import 'package:flutter/services.dart';

class Live2DService {
  static const MethodChannel _channel = MethodChannel('kirakira/live2d');

  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      // Live2D not available on this platform
    }
  }

  static Future<void> loadModel(String path) async {
    try {
      await _channel.invokeMethod('loadModel', {'path': path});
    } catch (e) {
      // Handle error
    }
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {}
  }
}
