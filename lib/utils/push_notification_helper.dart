import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:developer' as developer;

/// Push Notification Helper
/// Handles OneSignal initialization and getting device token (User ID)
/// Converted from KMP's PushNotificationHelper.kt
class PushNotificationHelper {
  static const String _oneSignalAppId = '55ea1b60-efde-401e-b4cf-5fcbd9524fcc';
  static bool _isInitialized = false;

  /// Initialize OneSignal SDK
  /// Should be called in main.dart before runApp()
  static Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('OneSignal already initialized');
      return;
    }

    try {
      // Initialize OneSignal
      OneSignal.initialize(_oneSignalAppId);

      // Request permission for push notifications
      OneSignal.Notifications.requestPermission(true);

      // Set up notification handlers
      OneSignal.Notifications.addClickListener((event) {
        developer.log('OneSignal notification clicked: ${event.notification}');
      });

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        developer.log('OneSignal notification received in foreground: ${event.notification}');
        // You can prevent the notification from showing by calling:
        // event.notification.preventDefault();
      });

      _isInitialized = true;
      developer.log('OneSignal initialized successfully');
    } catch (e) {
      developer.log('Error initializing OneSignal: $e');
      rethrow;
    }
  }

  /// Get OneSignal User ID (device token)
  /// Returns null if not available yet
  /// Converted from KMP's PushSubscriptionManager.getPushSubscriptionId()
  static String? getPushSubscriptionId() {
    try {
      final subscription = OneSignal.User.pushSubscription;
      final userId = subscription.id;
      developer.log('OneSignal User ID: $userId');
      return userId;
    } catch (e) {
      developer.log('Error getting OneSignal User ID: $e');
      return null;
    }
  }

  /// Fetch Push ID with retry logic
  /// Retries up to 20 times (10 seconds) to get the User ID
  /// Converted from KMP's PushNotificationHelper.fetchPushId()
  static Future<String?> fetchPushId({int maxRetries = 20}) async {
    for (int i = 0; i < maxRetries; i++) {
      final pushId = getPushSubscriptionId();
      if (pushId != null && pushId.isNotEmpty) {
        developer.log('OneSignal User ID obtained: $pushId');
        return pushId;
      }
      developer.log('OneSignal User ID not available yet, retry ${i + 1}/$maxRetries');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    developer.log('OneSignal User ID not available after $maxRetries retries');
    return null;
  }

  /// Check if OneSignal is initialized
  static bool get isInitialized => _isInitialized;
}

