import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:developer' as developer;
import 'package:get_it/get_it.dart';
import 'push_notification_handler.dart';
import '../presentation/provider/sync_provider.dart';
import 'storage_helper.dart';

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
      // Enable debug logging (helps troubleshoot)
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.Debug.setAlertLevel(OSLogLevel.none);

      // Initialize OneSignal
      OneSignal.initialize(_oneSignalAppId);

      // Request permission for push notifications
      OneSignal.Notifications.requestPermission(true);

      // Track push subscription changes (IMPORTANT: detects when token is ready)
      OneSignal.User.pushSubscription.addObserver((state) {
        developer.log('Push Subscription State Changed:');
        developer.log('  Opted In: ${OneSignal.User.pushSubscription.optedIn}');
        developer.log('  ID: ${OneSignal.User.pushSubscription.id}');
        developer.log('  Token: ${OneSignal.User.pushSubscription.token}');
        developer.log('  State: ${state.current.jsonRepresentation()}');
        
        // Save token when it becomes available
        final token = OneSignal.User.pushSubscription.id;
        if (token != null && token.isNotEmpty) {
          StorageHelper.setDeviceToken(token);
          developer.log('Device token saved: $token');
        }
      });

      // Track user state changes
      OneSignal.User.addObserver((state) {
        developer.log('OneSignal user changed: ${state.jsonRepresentation()}');
      });

      // Set up notification click handler
      OneSignal.Notifications.addClickListener((event) {
        developer.log('OneSignal notification clicked: ${event.notification}');
        // Process notification when clicked (in case it wasn't processed in foreground)
        _processNotification(event.notification.additionalData);
      });

      // Set up foreground notification handler
      // This is called when notification is received while app is in foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        developer.log('OneSignal notification received in foreground: ${event.notification}');
        
        // Extract additional data from notification
        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          _processNotification(additionalData);
        }
        
        // For silent pushes (show_notification: "0"), prevent default display
        final showNotification = additionalData?['data']?['show_notification'] as String?;
        if (showNotification == '0') {
          developer.log('PushNotificationHelper: Silent push detected, preventing display');
          event.preventDefault(); // ✅ This method EXISTS!
          return;
        }
        
        // Regular notifications will display automatically
      });

      // Note: Background notifications (when app is closed) are handled by addClickListener
      // when the user opens the app from the notification. The click listener above
      // will process the notification data in that case.

      // Set up permission observer
      OneSignal.Notifications.addPermissionObserver((state) {
        developer.log('OneSignal permission changed: ${state.toString()}');
      });

      _isInitialized = true;
      developer.log('OneSignal initialized successfully');
    } catch (e) {
      developer.log('Error initializing OneSignal: $e');
      rethrow;
    }
  }

  /// Process notification data
  /// Extracts data from OneSignal notification and routes to PushNotificationHandler
  /// Matches KMP's pattern where notification data is extracted and processed
  static Future<void> _processNotification(Map<String, dynamic>? additionalData) async {
    if (additionalData == null || additionalData.isEmpty) {
      developer.log('PushNotificationHelper: No additional data in notification');
      return;
    }
    try {
      // Get SyncProvider instance from dependency injection
      // We need to get it lazily since it might not be registered yet
      SyncProvider? syncProvider;
      try {
        syncProvider = GetIt.instance<SyncProvider>();
      } catch (e) {
        developer.log('PushNotificationHelper: SyncProvider not available yet: $e');
        // Try to get it from GetIt with optional check
        if (GetIt.instance.isRegistered<SyncProvider>()) {
          syncProvider = GetIt.instance<SyncProvider>();
        } else {
          developer.log('PushNotificationHelper: SyncProvider not registered, cannot process notification');
          return;
        }
      }

      // Process notification through handler
      await PushNotificationHandler.handleNotification(
        additionalData,
        syncProvider,
      );
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationHelper: Error processing notification: $e',
        error: e,
        stackTrace: stackTrace,
      );
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

