package com.kirakira.app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Perf: expose the Android API level to Dart so the WebView render mode setting
        // (VD / HC / HCPP) can auto-select per device without adding a device_info dependency.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.KiraKira/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }
}
