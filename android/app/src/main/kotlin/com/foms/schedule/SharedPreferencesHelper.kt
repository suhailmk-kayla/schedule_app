package com.foms.schedule
import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * SharedPreferences Helper
 * Provides access to native SharedPreferences that can be called from Flutter via method channel
 * 
 * This is needed because Flutter's shared_preferences package uses a different SharedPreferences
 * file than native Android code. Native code stores in "pending_notifications" file,
 * while Flutter's package uses the default file.
 */
object SharedPreferencesHelper {
    private const val TAG = "SharedPreferencesHelper"
    const val PREFS_NAME = "pending_notifications"
    const val PREFS_KEY = "pending_notifications_list"
    
    /**
     * Get pending notifications from native SharedPreferences
     * Returns the JSON string stored in SharedPreferences, or null if not found
     */
    fun getPendingNotifications(context: Context): String? {
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val jsonString = prefs.getString(PREFS_KEY, null)
            Log.d(TAG, "getPendingNotifications: ${if (jsonString != null) "Found ${jsonString.length} chars" else "null"}")
            jsonString
        } catch (e: Exception) {
            Log.e(TAG, "Error getting pending notifications: ${e.message}")
            null
        }
    }
    
    /**
     * Clear all pending notifications from native SharedPreferences
     */
    fun clearPendingNotifications(context: Context): Boolean {
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit().remove(PREFS_KEY).apply()
            Log.d(TAG, "clearPendingNotifications: Success")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing pending notifications: ${e.message}")
            false
        }
    }
    
    /**
     * Remove a specific pending notification by timestamp
     * Reads the JSON array, removes the item with matching timestamp, and saves back
     */
    fun removePendingNotification(context: Context, timestamp: Long): Boolean {
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val jsonString = prefs.getString(PREFS_KEY, null)
            
            if (jsonString == null || jsonString.isEmpty()) {
                Log.d(TAG, "removePendingNotification: No notifications to remove")
                return true
            }
            
            // Parse JSON array
            val jsonArray = org.json.JSONArray(jsonString)
            var removed = false
            
            // Remove items with matching timestamp
            val newArray = org.json.JSONArray()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                val itemTimestamp = item.optLong("timestamp", -1)
                if (itemTimestamp != timestamp) {
                    newArray.put(item)
                } else {
                    removed = true
                }
            }
            
            // Save back to SharedPreferences
            prefs.edit().putString(PREFS_KEY, newArray.toString()).apply()
            Log.d(TAG, "removePendingNotification: ${if (removed) "Removed" else "Not found"} (timestamp: $timestamp)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error removing pending notification: ${e.message}")
            false
        }
    }
}

