package com.foms.schedule

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Notification Channel Helper
 * Stores a static reference to the method channel for sending notifications to Flutter
 * 
 * This allows the service extension to send notifications to Flutter even when
 * FlutterEngineCache is not available (which is common in service extension context).
 * 
 * How it works:
 * 1. MainActivity calls registerChannel() when app starts (foreground)
 * 2. Service extension calls sendNotification() to send notifications
 * 3. If channel is registered = app is in foreground = send immediately
 * 4. If channel is null = app is background/terminated = store in SharedPreferences
 * 
 * IMPORTANT: MethodChannel.invokeMethod() must be called on the main/UI thread.
 * Service extensions run on background threads, so we use Handler to post to main thread.
 */
object NotificationChannelHelper {
    private var methodChannel: MethodChannel? = null
    private val tag = "NotificationChannelHelper"
    private var isRegistered = false
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * Register the method channel when MainActivity is active
     * This is called from MainActivity.configureFlutterEngine()
     * Only called when app is in foreground
     */
    fun registerChannel(flutterEngine: FlutterEngine) {
        Log.d(tag, "========== registerChannel() START ==========")
        try {
            methodChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.foms.schedule/firebase_notifications"
            )
            isRegistered = true
            Log.d(tag, "✅ Method channel registered successfully")
            Log.d(tag, "  • Channel name: com.foms.schedule/firebase_notifications")
            Log.d(tag, "  • Flutter engine available: true")
            Log.d(tag, "  • App is in foreground: true")
        } catch (e: Exception) {
            Log.e(tag, "❌ Error registering method channel: ${e.message}")
            Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
            isRegistered = false
        }
        Log.d(tag, "========== registerChannel() END ==========")
    }
    
    /**
     * Send notification to Flutter via the registered method channel
     * Returns true if sent successfully (app is in foreground)
     * Returns false if channel not registered (app is background/terminated)
     */
    fun sendNotification(data: Map<String, Any>): Boolean {
        Log.d(tag, "========== sendNotification() START ==========")
        Log.d(tag, "Checking if method channel is registered...")
        Log.d(tag, "  • isRegistered: $isRegistered")
        Log.d(tag, "  • methodChannel != null: ${methodChannel != null}")
        
        if (methodChannel == null) {
            Log.w(tag, "⚠️ Method channel NOT registered")
            Log.w(tag, "  → This means MainActivity is not active")
            Log.w(tag, "  → App is likely in background or terminated")
            Log.w(tag, "  → Notification should be stored in SharedPreferences")
            Log.d(tag, "========== sendNotification() END (FAILED) ==========")
            return false
        }
        
        if (!isRegistered) {
            Log.w(tag, "⚠️ Method channel exists but not registered")
            Log.w(tag, "  → This should not happen, but handling gracefully")
            Log.d(tag, "========== sendNotification() END (FAILED) ==========")
            return false
        }
        
        Log.d(tag, "✅ Method channel is registered")
        Log.d(tag, "  → MainActivity is active")
        Log.d(tag, "  → App is in foreground")
        Log.d(tag, "  → Attempting to send notification to Flutter...")
        Log.d(tag, "  • Notification data keys: ${data.keys}")
        Log.d(tag, "  • Notification data size: ${data.size} entries")
        Log.d(tag, "  • Current thread: ${Thread.currentThread().name}")
        Log.d(tag, "  • Main thread: ${Looper.getMainLooper().thread.name}")
        
        // Check if we're on the main thread
        val isMainThread = Looper.myLooper() == Looper.getMainLooper()
        Log.d(tag, "  • Is main thread: $isMainThread")
        
        return if (isMainThread) {
            // Already on main thread - call directly
            Log.d(tag, "  → Already on main thread, calling invokeMethod directly")
            try {
                methodChannel!!.invokeMethod("onNotificationReceived", data)
                Log.d(tag, "✅ invokeMethod() called successfully")
                Log.d(tag, "  → Notification sent to Flutter")
                Log.d(tag, "  → Flutter will process it via method channel handler")
                Log.d(tag, "========== sendNotification() END (SUCCESS) ==========")
                true
            } catch (e: Exception) {
                Log.e(tag, "❌ Failed to send notification via method channel")
                Log.e(tag, "  • Error: ${e.message}")
                Log.e(tag, "  • Error type: ${e.javaClass.simpleName}")
                Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
                Log.d(tag, "========== sendNotification() END (FAILED) ==========")
                false
            }
        } else {
            // Not on main thread - post to main thread using Handler
            Log.d(tag, "  → Not on main thread, posting to main thread via Handler")
            Log.d(tag, "  → Using Handler.post() to execute on main thread")
            
            // Use synchronized flag to track result
            var success = false
            var exception: Exception? = null
            val lock = Object()
            
            // Post to main thread
            mainHandler.post {
                synchronized(lock) {
                    try {
                        Log.d(tag, "  → Now executing on main thread")
                        Log.d(tag, "  → Current thread: ${Thread.currentThread().name}")
                        Log.d(tag, "  → Calling invokeMethod...")
                        methodChannel!!.invokeMethod("onNotificationReceived", data)
                        Log.d(tag, "✅ invokeMethod() called successfully (on main thread)")
                        Log.d(tag, "  → Notification sent to Flutter")
                        Log.d(tag, "  → Flutter will process it via method channel handler")
                        success = true
                        lock.notify()
                    } catch (e: Exception) {
                        Log.e(tag, "❌ Failed to send notification via method channel (on main thread)")
                        Log.e(tag, "  • Error: ${e.message}")
                        Log.e(tag, "  • Error type: ${e.javaClass.simpleName}")
                        Log.e(tag, "Stack trace: ${e.stackTraceToString()}")
                        exception = e
                        success = false
                        lock.notify()
                    }
                }
            }
            
            // Wait for result (with timeout to avoid blocking forever)
            synchronized(lock) {
                try {
                    Log.d(tag, "  → Waiting for main thread execution (max 100ms)...")
                    lock.wait(100) // Wait max 100ms for result
                    if (success) {
                        Log.d(tag, "✅ Notification sent successfully (confirmed)")
                        Log.d(tag, "========== sendNotification() END (SUCCESS) ==========")
                        return true
                    } else {
                        Log.w(tag, "⚠️ Notification send failed or timed out")
                        if (exception != null) {
                            Log.w(tag, "  • Exception: ${exception!!.message}")
                        } else {
                            Log.w(tag, "  • Timed out waiting for result")
                        }
                        Log.d(tag, "========== sendNotification() END (FAILED) ==========")
                        return false
                    }
                } catch (e: InterruptedException) {
                    Log.e(tag, "❌ Interrupted while waiting for result")
                    Log.d(tag, "========== sendNotification() END (FAILED) ==========")
                    return false
                }
            }
        }
    }
    
    /**
     * Check if method channel is registered (for debugging)
     */
    fun isChannelRegistered(): Boolean {
        val registered = methodChannel != null && isRegistered
        Log.d(tag, "isChannelRegistered() = $registered")
        return registered
    }
    
    /**
     * Clear the method channel reference (for testing or cleanup)
     * Normally not needed, but useful for debugging
     */
    fun clearChannel() {
        Log.d(tag, "========== clearChannel() CALLED ==========")
        methodChannel = null
        isRegistered = false
        Log.d(tag, "✅ Method channel cleared")
        Log.d(tag, "========== clearChannel() END ==========")
    }
}

