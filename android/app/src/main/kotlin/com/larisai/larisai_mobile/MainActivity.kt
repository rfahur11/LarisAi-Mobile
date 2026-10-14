package com.larisai.larisai_mobile

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.larisai.larisai_mobile/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getHardwareId") {
                try {
                    val androidId: String? = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    if (!androidId.isNullOrBlank() && androidId != "9774d56d682e549c") {
                        result.success(androidId)
                    } else {
                        // Fallback to deterministic hardware signature
                        val fallback = "${Build.BOARD}-${Build.BRAND}-${Build.DEVICE}-${Build.MANUFACTURER}"
                        result.success(fallback)
                    }
                } catch (e: Exception) {
                    val fallback = "${Build.BOARD}-${Build.BRAND}-${Build.DEVICE}-${Build.MANUFACTURER}"
                    result.success(fallback)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
