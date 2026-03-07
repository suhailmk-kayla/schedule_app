package com.foms.schedule
import android.app.ActivityManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.annotation.Keep
import com.onesignal.notifications.IDisplayableMutableNotification
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * OneSignal Notification Service Extension
 * Intercepts ALL notifications (foreground, background, terminated) before OneSignal displays them
 * Registered via meta-data in AndroidManifest.xml
 */

 
@Keep
class OneSignalNotificationServiceExtension : INotificationServiceExtension {
    private val tag = "OneSignalServiceExtension"
    private val pendingNotificationsPrefs = "pending_notifications"
    private val pendingNotificationsKey = "pending_notifications_list"
    // final jsonString = prefs.getString('pending_notifications_list');

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        Log.e(tag, "========== onNotificationReceived() CALLED ==========")
        Log.e(tag, "✅ OneSignal Service Extension is working!")
        
        val notification = event.notification
        val context = event.context
        
        Log.d(tag, "Notification ID: ${notification.notificationId}")
        Log.d(tag, "Title: ${notification.title}")
        Log.d(tag, "Body: ${notification.body}")
        
        // Determine notification type
        val hasTitle = notification.title != null && notification.title!!.isNotEmpty()
        val hasBody = notification.body != null && notification.body!!.isNotEmpty()
        val isDataOnly = !hasTitle && !hasBody
        
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(tag, "📋 NOTIFICATION TYPE ANALYSIS:")
        Log.d(tag, "  • Has Title: $hasTitle (${if (hasTitle) notification.title else "null/empty"})")
        Log.d(tag, "  • Has Body: $hasBody (${if (hasBody) notification.body else "null/empty"})")
        Log.d(tag, "  • Notification Type: ${if (isDataOnly) "🔵 DATA-ONLY" else "🟢 PAYLOAD (Display)"}")
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Extract additional data (JSONObject, not Map)
        val additionalData = notification.additionalData
        if (additionalData != null && additionalData.length() > 0) {
            Log.d(tag, "Additional data: $additionalData")
            
            // Convert JSONObject to Map<String, Any>
            val additionalDataMap = jsonObjectToMap(additionalData)
            
            // Extract data_ids from additionalData
            val notificationData = extractNotificationData(additionalDataMap)
            
            if (notificationData != null) {
                Log.d(tag, "✅ Extracted notification data: $notificationData")
                
                // Check if app is in foreground
                val isForeground = isAppInForeground(context)
                
                Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                Log.d(tag, "📱 APP STATE:")
                Log.d(tag, "  • App in Foreground: $isForeground")
                Log.d(tag, "  • Notification Type: ${if (isDataOnly) "DATA-ONLY" else "PAYLOAD"}")
                Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                if (isForeground) {
                    if (isDataOnly) {
                        // DATA-ONLY notification in foreground
                        // OneSignal SDK won't call addForegroundWillDisplayListener for data-only notifications
                        // Service Extension MUST handle it
                        Log.d(tag, "🔵 DATA-ONLY notification in FOREGROUND")
                        Log.d(tag, "  → Service Extension MUST handle it (OneSignal SDK won't call addForegroundWillDisplayListener)")
                        Log.d(tag, "  → Sending to Flutter via method channel")
                        
                        // Send to Flutter via method channel
                        sendToFlutter(context, notificationData)
                        
                        // Prevent OneSignal from trying to process (it won't anyway for data-only, but good practice)
                        event.preventDefault()
                        return // Early return - service extension handled it
                    } else {
                        // PAYLOAD notification in foreground
                        // CRITICAL FIX: OneSignal SDK's foreground detection can be unreliable
                        // Even though we detect foreground, OneSignal SDK may think app is in background
                        // (see logs: "App is in background, show notification" even when service extension detects foreground)
                        // Therefore, we MUST process the notification data here to ensure it's handled
                        Log.d(tag, "🟢 PAYLOAD notification in FOREGROUND")
                        Log.d(tag, "  → Processing notification data to ensure it's handled")
                        Log.d(tag, "  → OneSignal SDK may incorrectly detect background and skip its listener")
                        Log.d(tag, "  → Processing here ensures data is handled regardless")
                        Log.d(tag, "  → Duplicate prevention in PushNotificationHandler will prevent duplicate downloads")
                        
                        // Send to Flutter to ensure notification data is processed
                        // This ensures processing even if OneSignal SDK's listener doesn't trigger
                        // Duplicate prevention in PushNotificationHandler will handle cases where both trigger
                        sendToFlutter(context, notificationData)
                        
                        // Don't prevent display - let the notification show
                        // The notification will display, and data is processed
                        return // Early return - data sent to Flutter, notification will display
                    }
                } else {
                    Log.d(tag, "📴 App is in BACKGROUND/TERMINATED")
                    Log.d(tag, "  → Service Extension handling (Flutter engine not available)")
                    // Try to send to Flutter, otherwise store
                    sendToFlutter(context, notificationData)
                    
                    // Check if this is a silent push
                    // show_notification can be directly in additionalDataMap or nested under "data"
                    val showNotification = (additionalDataMap["show_notification"] as? String)
                        ?: (additionalDataMap["data"] as? Map<*, *>)?.get("show_notification") as? String
                    
                    Log.d(tag, "  • show_notification flag: ${showNotification ?: "not set"}")
                    
                    if (showNotification == "0") {
                        Log.d(tag, "🔇 SILENT PUSH detected (show_notification: 0)")
                        Log.d(tag, "  → Preventing notification display")
                        // Prevent OneSignal from displaying the notification only in background/terminated
                        event.preventDefault()
                    } else {
                        Log.d(tag, "🔔 DISPLAY NOTIFICATION (show_notification: ${showNotification ?: "1"})")
                        Log.d(tag, "  → Notification will be displayed")
                    }
                }
            } else {
                Log.w(tag, "⚠️ Could not extract notification data")
            }
        } else {
            Log.w(tag, "⚠️ No additional data in notification")
        }
        
        // OneSignal handles completion automatically - no need to call event.complete()
        // If you want to prevent display, use: event.preventDefault()
        
        Log.e(tag, "========== onNotificationReceived() END ==========")
    }

    /**
     * Convert JSONObject to Map<String, Any>
     * Helper method to convert OneSignal's JSONObject to Map
     */
    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        val keys = jsonObject.keys()
        
        while (keys.hasNext()) {
            val key = keys.next()
            val value = jsonObject.get(key)
            
            when (value) {
                is JSONObject -> map[key] = jsonObjectToMap(value)
                is org.json.JSONArray -> {
                    val list = mutableListOf<Any>()
                    for (i in 0 until value.length()) {
                        val item = value.get(i)
                        when (item) {
                            is JSONObject -> list.add(jsonObjectToMap(item))
                            else -> list.add(item)
                        }
                    }
                    map[key] = list
                }
                else -> map[key] = value
            }
        }
        
        return map
    }

    /**
     * Extract notification data from OneSignal's additionalData structure
     */
    private fun extractNotificationData(additionalData: Map<String, Any>): Map<String, Any>? {
        try {
            // Check if data is nested under "data" key
            val data = additionalData["data"] as? Map<*, *>
            if (data != null) {
                @Suppress("UNCHECKED_CAST")
                return data as? Map<String, Any>
            }
            
            // If not nested, check if data_ids exists directly
            if (additionalData.containsKey("data_ids")) {
                return additionalData
            }
            
            // Return original if no specific structure found
            return additionalData
        } catch (e: Exception) {
            Log.e(tag, "Error extracting notification data: ${e.message}")
            return null
        }
    }

    /**
     * Check if app is in foreground
     */
    private fun isAppInForeground(context: Context): Boolean {
        try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val appProcesses = activityManager.runningAppProcesses ?: return false
            
            val packageName = context.packageName
            for (appProcess in appProcesses) {
                if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                    appProcess.processName == packageName) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "Error checking app state: ${e.message}")
        }
        return false
    }

    /**
     * Send notification data to Flutter via method channel
     * Uses static method channel reference from NotificationChannelHelper
     * If channel is registered = app is in foreground = send immediately
     * If channel is null = app is background/terminated = store in SharedPreferences
     */
    private fun sendToFlutter(context: Context, data: Map<String, Any>) {
        Log.d(tag, "========== sendToFlutter() START ==========")
        Log.d(tag, "Attempting to send notification to Flutter...")
        Log.d(tag, "  • Notification data keys: ${data.keys}")
        Log.d(tag, "  • Notification data size: ${data.size} entries")
        
        // Check if app is in foreground (for logging purposes)
        val isForeground = isAppInForeground(context)
        Log.d(tag, "App state check (for logging): $isForeground")
        
        // Try to send via static method channel reference (set by MainActivity)
        // This is more reliable than FlutterEngineCache in service extension context
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(tag, "📡 METHOD 1: Trying static method channel reference")
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        val sentViaStaticChannel = NotificationChannelHelper.sendNotification(data)
        
        if (sentViaStaticChannel) {
            Log.d(tag, "✅ SUCCESS: Notification sent via static method channel")
            Log.d(tag, "  → App is confirmed to be in foreground")
            Log.d(tag, "  → Flutter will process notification immediately")
            Log.d(tag, "  → No need to store in SharedPreferences")
            Log.d(tag, "========== sendToFlutter() END (SUCCESS) ==========")
            return
        }
        
        // Static channel failed, try FlutterEngineCache as fallback
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(tag, "📡 METHOD 2: Trying FlutterEngineCache (fallback)")
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        try {
            val flutterEngine = FlutterEngineCache.getInstance().get("main")
            
            if (flutterEngine != null) {
                Log.d(tag, "✅ Flutter engine found in cache")
                try {
                    val channel = MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.foms.schedule/firebase_notifications"
                    )
                    Log.d(tag, "Sending notification via FlutterEngineCache method channel...")
                    channel.invokeMethod("onNotificationReceived", data)
                    Log.d(tag, "✅ MethodChannel invokeMethod called successfully (via FlutterEngineCache)")
                    Log.d(tag, "  → Notification sent to Flutter")
                    Log.d(tag, "========== sendToFlutter() END (SUCCESS) ==========")
                    return
                } catch (e: Exception) {
                    Log.e(tag, "❌ MethodChannel failed (via FlutterEngineCache): ${e.message}")
                    Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
                }
            } else {
                Log.w(tag, "⚠️ Flutter engine NOT available from cache")
                Log.w(tag, "  → This is expected in service extension context")
            }
        } catch (e: Exception) {
            Log.e(tag, "❌ Error accessing FlutterEngineCache: ${e.message}")
            Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
        }
        
        // Both methods failed - store in SharedPreferences
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(tag, "📦 FALLBACK: Storing notification in SharedPreferences")
        Log.d(tag, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(tag, "  → Both method channel methods failed")
        Log.d(tag, "  → App is likely in background/terminated")
        Log.d(tag, "  → Notification will be processed when app resumes")
        storeNotificationForLater(context, data)
        Log.d(tag, "========== sendToFlutter() END (STORED) ==========")
    }

    /**
     * Store notification in SharedPreferences for later processing
     */
    private fun storeNotificationForLater(context: Context, data: Map<String, Any>) {
        Log.d(tag, "========== storeNotificationForLater() START ==========")
        try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                pendingNotificationsPrefs,
                Context.MODE_PRIVATE
            )
            
            // Convert Map to JSON string
            val jsonObject = JSONObject()
            for ((key, value) in data) {
                when (value) {
                    is Map<*, *> -> {
                        val nestedJson = JSONObject()
                        @Suppress("UNCHECKED_CAST")
                        for ((nestedKey, nestedValue) in value as Map<String, Any>) {
                            nestedJson.put(nestedKey, nestedValue.toString())
                        }
                        jsonObject.put(key, nestedJson)
                    }
                    is List<*> -> {
                        val jsonArray = org.json.JSONArray()
                        for (item in value) {
                            when (item) {
                                is Map<*, *> -> {
                                    val itemJson = JSONObject()
                                    @Suppress("UNCHECKED_CAST")
                                    for ((itemKey, itemValue) in item as Map<String, Any>) {
                                        itemJson.put(itemKey, itemValue.toString())
                                    }
                                    jsonArray.put(itemJson)
                                }
                                else -> jsonArray.put(item.toString())
                            }
                        }
                        jsonObject.put(key, jsonArray)
                    }
                    else -> jsonObject.put(key, value.toString())
                }
            }
            
            val timestamp = System.currentTimeMillis()
            val notificationWithTimestamp = JSONObject().apply {
                put("timestamp", timestamp)
                put("data", jsonObject)
            }
            
            val existingJson = prefs.getString(pendingNotificationsKey, "[]")
            val notificationsArray = org.json.JSONArray(existingJson ?: "[]")
            notificationsArray.put(notificationWithTimestamp)
            
            prefs.edit()
                .putString(pendingNotificationsKey, notificationsArray.toString())
                .apply()
            
            Log.e(tag, "✅ Notification stored successfully!")
            Log.e(tag, "  Total pending: ${notificationsArray.length()}")
            Log.e(tag, "  Timestamp: $timestamp")

            val storedFinal = prefs.getString(pendingNotificationsKey, "[]")
            Log.e(tag, "📌 Stored Pending Notification Data:\n$storedFinal")
            try {
    val prettyJson = JSONObject(storedFinal ?: "{}").toString(4)
    Log.e(tag, "📌 Stored Pending Notification Data (Pretty):\n$prettyJson")
} catch (e: Exception) {
    Log.e(tag, "📌 Raw JSON (not pretty):\n$storedFinal")
}
            
        } catch (e: Exception) {
            Log.e(tag, "❌ Error storing notification: ${e.message}")
            Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
        }
        Log.d(tag, "========== storeNotificationForLater() END ==========")
    }
}