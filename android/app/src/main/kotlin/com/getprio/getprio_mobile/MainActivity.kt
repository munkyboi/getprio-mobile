package com.getprio.getprio_mobile

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "getprio/onboarding")
            .setMethodCallHandler { call, result ->
                try {
                    // Survives updates, but never uninstall or Android backup restore.
                    val marker = File(noBackupFilesDir, "onboarding-completed")
                    when (call.method) {
                        "isComplete" -> result.success(marker.exists())
                        "complete" -> {
                            marker.writeText("1")
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("onboarding_storage", "Could not save onboarding state", null)
                }
            }
    }
}
