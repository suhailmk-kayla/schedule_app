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

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        Log.e(tag, "========== onNotificationReceived() CALLED ==========")
        Log.e(tag, "✅ OneSignal Service Extension is working!")
        
        val notification = event.notification
        val context = event.context
        
        Log.d(tag, "Notification ID: ${notification.notificationId}")
        Log.d(tag, "Title: ${notification.title}")
        Log.d(tag, "Body: ${notification.body}")
        
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
                
                if (isForeground) {
                    Log.d(tag, "App is in foreground - Flutter listeners will handle processing")
                    Log.d(tag, "Service Extension: Skipping storage (Flutter listeners will process)")
                    // Don't store, don't prevent default - let Flutter listeners handle everything
                    // Flutter listeners will process the notification and prevent display for silent pushes
                    return // Early return - let Flutter listeners handle everything
                } else {
                    Log.d(tag, "App is in background/terminated - Service Extension handling")
                    // Try to send to Flutter, otherwise store
                    sendToFlutter(context, notificationData)
                    
                    // Check if this is a silent push
                    // show_notification can be directly in additionalDataMap or nested under "data"
                    val showNotification = (additionalDataMap["show_notification"] as? String)
                        ?: (additionalDataMap["data"] as? Map<*, *>)?.get("show_notification") as? String
                    
                    if (showNotification == "0") {
                        Log.d(tag, "Silent push detected (show_notification: 0) - Preventing notification display")
                        // Prevent OneSignal from displaying the notification only in background/terminated
                        event.preventDefault()
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
     */
    private fun sendToFlutter(context: Context, data: Map<String, Any>) {
        Log.d(tag, "========== sendToFlutter() START ==========")
        
        // Check if app is in foreground
        val isForeground = isAppInForeground(context)
        Log.d(tag, "App in foreground: $isForeground")
        
        try {
            // Try to get Flutter engine from cache
            val flutterEngine = FlutterEngineCache.getInstance().get("main")
            
            if (flutterEngine != null) {
                Log.d(tag, "✅ Flutter engine is available from cache")
                try {
                    val channel = MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.foms.schedule/firebase_notifications"
                    )
                    Log.d(tag, "Sending notification to Flutter via MethodChannel...")
                    channel.invokeMethod("onNotificationReceived", data)
                    Log.d(tag, "✅ MethodChannel invokeMethod called successfully")
                    
                    // If app is in foreground and engine is available, we successfully sent it
                    // Still store as backup in case Flutter side fails to process
                    if (isForeground) {
                        Log.d(tag, "App is in foreground - notification sent to Flutter, storing as backup")
                        storeNotificationForLater(context, data)
                    }
                    return
                } catch (e: Exception) {
                    Log.e(tag, "❌ MethodChannel failed: ${e.message}")
                    Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
                    storeNotificationForLater(context, data)
                }
            } else {
                Log.w(tag, "⚠️ Flutter engine NOT available from cache")
                Log.d(tag, "  - App in foreground: $isForeground")
                Log.d(tag, "  - This is normal if app is in background/terminated")
                Log.d(tag, "  - Storing notification for later processing")
                storeNotificationForLater(context, data)
            }
        } catch (e: Exception) {
            Log.e(tag, "❌ Error in sendToFlutter: ${e.message}")
            Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
            storeNotificationForLater(context, data)
        }
        Log.d(tag, "========== sendToFlutter() END ==========")
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
            
        } catch (e: Exception) {
            Log.e(tag, "❌ Error storing notification: ${e.message}")
            Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
        }
        Log.d(tag, "========== storeNotificationForLater() END ==========")
    }
}