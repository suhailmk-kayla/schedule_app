package com.foms.schedule

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.foms.schedule/url_launcher"
    private val storageChannelName = "com.foms.schedule/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register notification method channel for service extension
        // This allows service extension to send notifications to Flutter in real-time
        // Only called when app is in foreground (MainActivity is active)
        NotificationChannelHelper.registerChannel(flutterEngine)

        // URL launcher channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "openUrl") {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_URL", "URL is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Storage channel for accessing native SharedPreferences
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingNotifications" -> {
                        try {
                            val jsonString = SharedPreferencesHelper.getPendingNotifications(applicationContext)
                            result.success(jsonString)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "clearPendingNotifications" -> {
                        try {
                            val success = SharedPreferencesHelper.clearPendingNotifications(applicationContext)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "removePendingNotification" -> {
                        try {
                            val timestamp = call.argument<Long>("timestamp")
                            if (timestamp == null) {
                                result.error("INVALID_ARGUMENT", "Timestamp is required", null)
                                return@setMethodCallHandler
                            }
                            val success = SharedPreferencesHelper.removePendingNotification(applicationContext, timestamp)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
