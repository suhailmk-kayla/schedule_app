import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage Helper
/// Manages secure storage for tokens and user data
/// Converted from KMP's AppSettings.kt
class StorageHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Storage keys (matching KMP's AppSettings keys)
  static const String _keyUserToken = 'key_user_token';
  static const String _keyIsUserLogin = 'key_is_user_login';
  static const String _keyUser = 'key_user';
  static const String _keyUserId = 'key_user_id';
  static const String _keyUserType = 'key_user_type';
  static const String _keyUserPassword = 'key_user_pass';
  static const String _keyDeviceToken = 'key_device_token';

  // ============================================================================
  // Token Management
  // ============================================================================

  /// Get user token
  static Future<String> getUserToken() async {
    return await _storage.read(key: _keyUserToken) ?? '';
  }

  /// Set user token
  static Future<void> setUserToken(String token) async {
    await _storage.write(key: _keyUserToken, value: token);
  }

  /// Clear user token
  static Future<void> clearUserToken() async {
    await _storage.delete(key: _keyUserToken);
  }

  // ============================================================================
  // User Data Management
  // ============================================================================

  /// Get user ID
  static Future<int> getUserId() async {
    final value = await _storage.read(key: _keyUserId);
    return value != null ? int.tryParse(value) ?? 0 : 0;
  }

  /// Set user ID
  static Future<void> setUserId(int userId) async {
    await _storage.write(key: _keyUserId, value: userId.toString());
  }

  /// Get user type
  static Future<int> getUserType() async {
    final value = await _storage.read(key: _keyUserType);
    return value != null ? int.tryParse(value) ?? 0 : 0;
  }

  /// Set user type
  static Future<void> setUserType(int userType) async {
    await _storage.write(key: _keyUserType, value: userType.toString());
  }

  /// Get username
  static Future<String> getUser() async {
    return await _storage.read(key: _keyUser) ?? '';
  }

  /// Set username
  static Future<void> setUser(String user) async {
    await _storage.write(key: _keyUser, value: user);
  }

  /// Get user password
  static Future<String> getUserPassword() async {
    return await _storage.read(key: _keyUserPassword) ?? '';
  }

  /// Set user password
  static Future<void> setUserPassword(String password) async {
    await _storage.write(key: _keyUserPassword, value: password);
  }

  /// Get is user login flag
  static Future<String> getIsUserLogin() async {
    return await _storage.read(key: _keyIsUserLogin) ?? '0';
  }

  /// Set is user login flag
  static Future<void> setIsUserLogin(String value) async {
    await _storage.write(key: _keyIsUserLogin, value: value);
  }

  /// Get device token
  static Future<String> getDeviceToken() async {
    return await _storage.read(key: _keyDeviceToken) ?? '';
  }

  /// Set device token
  static Future<void> setDeviceToken(String deviceToken) async {
    await _storage.write(key: _keyDeviceToken, value: deviceToken);
  }

  // ============================================================================
  // Pending Notifications Management
  // ============================================================================

  /// Get all pending notifications stored in SharedPreferences
  /// Returns list of notification data maps
  static Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('pending_notifications_list');
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear all pending notifications
  static Future<void> clearPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_notifications_list');
    } catch (e) {
      // Ignore errors
    }
  }

  /// Remove a specific pending notification by timestamp
  /// Used to remove processed notifications
  static Future<void> removePendingNotification(int timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('pending_notifications_list');
      
      if (jsonString == null || jsonString.isEmpty) {
        return;
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      jsonList.removeWhere((item) {
        final map = item as Map<String, dynamic>;
        return map['timestamp'] == timestamp;
      });
      
      await prefs.setString('pending_notifications_list', json.encode(jsonList));
    } catch (e) {
      // Ignore errors
    }
  }

  // ============================================================================
  // Clear All Data
  // ============================================================================

  /// Clear all stored data (including pending notifications)
  static Future<void> clearAll() async {
    // Clear all FlutterSecureStorage (tokens, user data, etc.)
    await _storage.deleteAll();
    
    // Clear all SharedPreferences (not just pending notifications)
    // This ensures no data from previous session remains
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

