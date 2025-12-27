import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'dart:developer' as developer;

/// Enforces notification permission for internal app usage
/// Blocks app functionality until permission is granted
class NotificationPermissionEnforcer {
  /// Check if notification permission is granted
  /// Returns true if granted, false otherwise
  static Future<bool> checkPermission() async {
    try {
      // OneSignal doesn't have a direct permission status check,
      // so we check via subscription status
      final subscription = OneSignal.User.pushSubscription;
      
      // If user has opted in and has a subscription ID, permission is likely granted
      final subscriptionId = subscription.id;
      if (subscription.optedIn == true && subscriptionId != null && subscriptionId.isNotEmpty) {
        return true;
      }
      
      // For Android, we can also check system permission
      final systemPermission = await ph.Permission.notification.status;
      if (systemPermission.isGranted) {
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error checking notification permission: $e');
      return false;
    }
  }

  /// Request notification permission
  /// Returns true if granted, false if denied
  static Future<bool> requestPermission() async {
    try {
      // Request via OneSignal
      final accepted = await OneSignal.Notifications.requestPermission(true);
      developer.log('Notification permission request result: $accepted');
      
      if (accepted) {
        return true;
      }
      
      // Also try system-level request for Android
      final systemPermission = await ph.Permission.notification.request();
      if (systemPermission.isGranted) {
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Open app settings so user can enable notification permission manually
  static Future<bool> openAppSettings() async {
    try {
      // Use permission_handler's openAppSettings top-level function
      return await ph.openAppSettings();
    } catch (e) {
      developer.log('Error opening app settings: $e');
      return false;
    }
  }
}
