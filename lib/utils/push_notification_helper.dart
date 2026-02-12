import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
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

      OneSignal.User.pushSubscription.optIn();
      
      // Track push subscription changes (IMPORTANT: detects when token is ready)
      OneSignal.User.pushSubscription.addObserver((state) {
         
         
         
         
         
        
        // Save token when it becomes available
        final token = OneSignal.User.pushSubscription.id;
        if (token != null && token.isNotEmpty) {
          StorageHelper.setDeviceToken(token);
           
        }
      });

      



      // Track user state changes
      OneSignal.User.addObserver((state) {
         
      });

      // Set up notification click handler
      OneSignal.Notifications.addClickListener((event) {
         
        // Process notification when clicked (in case it wasn't processed in foreground)
        _processNotification(event.notification.additionalData);
      });
      
      // Set up foreground notification handler
      // This is called when notification is received while app is in foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
         
        
        // Extract additional data from notification
        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
           
          try {
            await _processNotification(additionalData);
          } catch (e, stackTrace) {
            developer.log(
              'PushNotificationHelper: Foreground handler failed: $e',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
        
        // For silent pushes (show_notification: "0"), prevent default display
        final showNotification = (additionalData?['show_notification'] ??
                additionalData?['data']?['show_notification'])
            ?.toString();
        // Check if notification has title/body (payload notification)
final hasTitle = event.notification.title != null && event.notification.title!.isNotEmpty;
final hasBody = event.notification.body != null && event.notification.body!.isNotEmpty;
final isPayloadNotification = hasTitle || hasBody;
if (!isPayloadNotification || showNotification == '0') {
  // Only prevent if it's data-only OR explicitly marked as silent
  event.preventDefault();
}
      });

      // Note: Background notifications (when app is closed) are handled by addClickListener
      // when the user opens the app from the notification. The click listener above
      // will process the notification data in that case.

      // Set up permission observer
      OneSignal.Notifications.addPermissionObserver((state) {
         
        
      });

      // Set up Firebase Messaging Service method channel
      // This catches ALL notifications (including silent ones) before OneSignal processes them
      // Matches KMP's MyFirebaseMessagingService approach
      // Why: OneSignal SDK listeners might skip silent notifications, but FirebaseMessagingService receives ALL
      // This ensures data syncing works even when app is in background or closed
      _setupFirebaseMessagingChannel();

      _isInitialized = true;
       
    } catch (e) {
       
      rethrow;
    }
  }

  /// Process notification data
  /// Extracts data from OneSignal notification and routes to PushNotificationHandler
  /// Matches KMP's pattern where notification data is extracted and processed
  static Future<void> _processNotification(Map<String, dynamic>? additionalData) async {
     
     
     
    
    if (additionalData == null || additionalData.isEmpty) {
       
       
       
      return;
    }
    
     
     
     
     
    
    try {
      // Get SyncProvider instance from dependency injection
      // We need to get it lazily since it might not be registered yet
       
      SyncProvider? syncProvider;
      try {
        syncProvider = GetIt.instance<SyncProvider>();
         
      } catch (e) {
         
         
        // Try to get it from GetIt with optional check
        if (GetIt.instance.isRegistered<SyncProvider>()) {
          syncProvider = GetIt.instance<SyncProvider>();
           
        } else {
           
           
           
           
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
       
      return userId;
    } catch (e) {
       
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
         
        return pushId;
      }
       
      await Future.delayed(const Duration(milliseconds: 500));
    }
     
    return null;
  }

  /// Set up method channel to receive notifications from Firebase Messaging Service
  /// This catches silent notifications that OneSignal listeners might miss
  /// Matches KMP's MyFirebaseMessagingService approach
  /// In KMP, MyFirebaseMessagingService directly calls PushNotificationHandler.handleNotification
  /// Here, we forward to Flutter which then calls PushNotificationHandler.handleNotification
  static void _setupFirebaseMessagingChannel() {
     
     
     
    
    const MethodChannel channel = MethodChannel('com.foms.schedule/firebase_notifications');
    
    channel.setMethodCallHandler((call) async {
       
       
       
       
       
       
      
      if (call.method == 'onNotificationReceived') {
         
         
         
        
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
           
           
           
          
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final notificationData = Map<String, dynamic>.from(
            data.map((key, value) => MapEntry(key.toString(), value)),
          );
          
           
           
           
           
          
          try {
            // Process through the same handler as OneSignal notifications
            // This matches KMP's PushNotificationHandler.handleNotification(json, database)
            await _processNotification(notificationData);
             
          } catch (e, stackTrace) {
            developer.log(
              '❌ Error processing notification: $e',
              error: e,
              stackTrace: stackTrace,
            );
          }
        } else {
           
           
        }
      } else {
         
         
      }
      
       
    });
    
     
     
     
     
     
  }

  /// Process stored notifications from SharedPreferences
  /// Called when app starts (after user is logged in)
  /// Processes notifications that were stored when Flutter engine was unavailable
  static Future<void> processStoredNotifications() async {
    try {
      // Check if user is logged in (don't process if not logged in)
      final isLoggedIn = await StorageHelper.getIsUserLogin();
      if (isLoggedIn != '1') {
         
        return;
      }

      // Get pending notifications
      final pendingNotifications = await StorageHelper.getPendingNotifications();
      
      if (pendingNotifications.isEmpty) {
         
        return;
      }

       

      // Get SyncProvider instance
      SyncProvider? syncProvider;
      try {
        syncProvider = GetIt.instance<SyncProvider>();
      } catch (e) {
         
        return;
      }

      // Process each notification with duplicate prevention
      final processedTimestamps = <int>[];
      final processedDataIds = <String>{}; // Track processed data_ids to prevent duplicates
      
      for (final notification in pendingNotifications) {
        try {
          // Extract timestamp and data
          final timestamp = notification['timestamp'] as int?;
          final data = notification['data'] as Map<String, dynamic>?;
          
          if (timestamp == null || data == null) {
             
            continue;
          }

          // Convert data to proper format (handle type casting)
          final notificationData = _convertStoredDataToNotificationFormat(data);
          
          // Extract data_ids to create unique key for duplicate detection
          final dataIds = _extractDataIds(notificationData);
          final dataIdsKey = dataIds.join('|');
          
          // Skip if we've already processed this exact notification
          if (processedDataIds.contains(dataIdsKey)) {
             
            // Still remove it to prevent reprocessing
            processedTimestamps.add(timestamp);
            continue;
          }

           

          // Process notification
          await PushNotificationHandler.handleNotification(
            notificationData,
            syncProvider,
          );

          // Mark as processed
          processedTimestamps.add(timestamp);
          processedDataIds.add(dataIdsKey);
           
        } catch (e, stackTrace) {
          developer.log(
            'PushNotificationHelper: Error processing stored notification: $e',
            error: e,
            stackTrace: stackTrace,
          );
          // Continue processing other notifications even if one fails
        }
      }

      // Remove processed notifications
      for (final timestamp in processedTimestamps) {
        await StorageHelper.removePendingNotification(timestamp);
      }

       
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationHelper: Error in processStoredNotifications: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Extract data_ids from notification data to create unique key
  /// Returns list of strings in format "table_id" for duplicate detection
  static List<String> _extractDataIds(Map<String, dynamic> notificationData) {
    final dataIds = <String>[];
    
    try {
      // Try to extract from 'data' key
      final data = notificationData['data'] as Map<String, dynamic>?;
      if (data != null) {
        final dataIdsArray = data['data_ids'] as List<dynamic>?;
        if (dataIdsArray != null) {
          for (final item in dataIdsArray) {
            if (item is Map<String, dynamic>) {
              final table = item['table']?.toString() ?? '0';
              final id = item['id']?.toString() ?? '0';
              dataIds.add('${table}_$id');
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    
    return dataIds;
  }

  /// Convert stored data to notification format
  /// Handles proper type casting from JSON strings back to proper types
  static Map<String, dynamic> _convertStoredDataToNotificationFormat(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map) {
        // Recursively convert nested maps
        result[key] = _convertStoredDataToNotificationFormat(
          Map<String, dynamic>.from(value),
        );
      } else if (value is List) {
        // Convert list items
        result[key] = value.map((item) {
          if (item is Map) {
            return _convertStoredDataToNotificationFormat(
              Map<String, dynamic>.from(item),
            );
          }
          return item;
        }).toList();
      } else if (value is String) {
        // Try to parse as number if it looks like one
        if (value == 'true' || value == 'false') {
          result[key] = value == 'true';
        } else if (RegExp(r'^-?\d+$').hasMatch(value)) {
          // Integer
          result[key] = int.tryParse(value) ?? value;
        } else if (RegExp(r'^-?\d+\.\d+$').hasMatch(value)) {
          // Double
          result[key] = double.tryParse(value) ?? value;
        } else {
          result[key] = value;
        }
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  /// Check if OneSignal is initialized
  static bool get isInitialized => _isInitialized;
}

