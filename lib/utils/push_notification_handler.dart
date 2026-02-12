import 'dart:developer' as developer;
import 'notification_id.dart';
import 'notification_manager.dart';
import '../presentation/provider/sync_provider.dart';

/// Push Notification Handler
/// Processes incoming push notifications and triggers data downloads
/// Converted from KMP's PushNotificationHandler.kt
class PushNotificationHandler {
  // Duplicate prevention: Track recently processed items to prevent duplicate API calls
  // Format: "table_id" as key, timestamp as value
  // Items are removed after 30 seconds to allow re-processing of same notification after delay
  static final Map<String, int> _recentlyProcessed = {};
  static const int _duplicatePreventionWindowMs = 2000; // 30 seconds

  /// Check if item was recently processed (prevents duplicate API calls)
  /// Returns true if item was processed recently, false otherwise
  static bool _wasRecentlyProcessed(int table, int id) {
    final key = '${table}_$id';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastProcessed = _recentlyProcessed[key];
    
    if (lastProcessed == null) {
      return false; // Not processed recently
    }
    
    // Check if window has expired
    if (now - lastProcessed > _duplicatePreventionWindowMs) {
      _recentlyProcessed.remove(key); // Clean up expired entry
      return false; // Window expired, allow processing
    }
    
    return true; // Processed recently, skip
  }

  /// Mark item as processed (prevents duplicate processing)
  static void _markAsProcessed(int table, int id) {
    final key = '${table}_$id';
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentlyProcessed[key] = now;
    
    // Clean up old entries periodically (every 100 items)
    if (_recentlyProcessed.length > 100) {
      _cleanupOldEntries();
    }
  }

  /// Clean up expired entries from duplicate prevention map
  static void _cleanupOldEntries() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentlyProcessed.removeWhere((key, timestamp) {
      return now - timestamp > _duplicatePreventionWindowMs;
    });
  }
  /// Handle notification from OneSignal
  /// Extracts data_ids array and processes each item
  static Future<void> handleNotification(
    Map<String, dynamic> notificationData,
    SyncProvider syncProvider,
  ) async {
    try {
       

      // Extract data from notification
      // OneSignal structure: notification.additionalData contains the payload
      // The payload structure matches KMP: { "data": { "data_ids": [...] } }
      Map<String, dynamic>? data;
      
      // Try to extract from different possible locations (matching KMP pattern)
      if (notificationData.containsKey('data')) {
        data = notificationData['data'] as Map<String, dynamic>?;
         
      } else if (notificationData.containsKey('custom')) {
        final custom = notificationData['custom'];
         
        if (custom is Map<String, dynamic> && custom.containsKey('a')) {
          data = custom['a'] as Map<String, dynamic>?;
           
        }
      } else {
        // If notificationData itself is the data object
        data = notificationData;
         
      }

      if (data == null) {
         
        return;
      }
      // Extract data_ids array
      final dataIds = data['data_ids'] as List<dynamic>?;
      if (dataIds == null || dataIds.isEmpty) {
         
        return;
      }

       

      // Process each data_id item

  for (final item in dataIds) {
     
    if (item is Map) {
   final converted = Map<String, dynamic>.from(item);
  await _downloadItem(syncProvider, converted);
    }else{
       
    }
  }

      // Trigger UI refresh after all downloads complete
      NotificationManager().triggerRefresh();
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationHandler: Error processing notification: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Download a single item based on table and id
  /// Matches KMP's download() method in PushNotificationHandler.kt
  static Future<void> _downloadItem(
    SyncProvider syncProvider,
    Map<String, dynamic> item,
  ) async {
    try {
      final table = item['table'] as int? ?? 0;
      final id = item['id'] as int? ?? 0;
       
      if (table == 0) {
         
        return;
      }

      // Duplicate prevention: Skip if recently processed
      if (_wasRecentlyProcessed(table, id)) {
        developer.log(
          'PushNotificationHandler: Skipping duplicate - table: $table, id: $id (processed recently)',
        );
        return;
      }

      // Mark as processed before API call (prevents race conditions)
      _markAsProcessed(table, id);
      
       

      // Route to appropriate download method based on table ID
      switch (table) {
        case NotificationId.product:
          await syncProvider.downloadProduct(id: id);
           
          break;
        case NotificationId.carBrand:
          await syncProvider.downloadCarBrand(id: id);
           
          break;
        case NotificationId.carName:
          await syncProvider.downloadCarName(id: id);
           
          break;
        case NotificationId.carModel:
          await syncProvider.downloadCarModel(id: id);
           
          break;
        case NotificationId.carVersion:
          await syncProvider.downloadCarVersion(id: id);
           
          break;
        case NotificationId.category:
          await syncProvider.downloadCategory(id: id);
           
          break;
        case NotificationId.subCategory:
          await syncProvider.downloadSubCategory(id: id);
           
          break;
        case NotificationId.order:
          await syncProvider.downloadOrder(id: id);
           
          break;
        case NotificationId.orderSub:
          await syncProvider.downloadOrderSub(id: id);
           
          break;
        case NotificationId.orderSubSuggestion:
          await syncProvider.downloadOrderSubSuggestion(id: id);
           
          break;
        case NotificationId.outOfStock:
          await syncProvider.downloadOutOfStock(id: id);
           
          break;
        case NotificationId.outOfStockSub:
          await syncProvider.downloadOutOfStockSub(id: id);
           
          break;
        case NotificationId.customer:
          await syncProvider.downloadCustomer(id: id);
           
          break;
        case NotificationId.user:
          await syncProvider.downloadUser(id: id);
           
          break;
        case NotificationId.salesman:
          await syncProvider.downloadSalesman(id: id);
           
          break;
        case NotificationId.supplier:
          await syncProvider.downloadSupplier(id: id);
           
          break;
        case NotificationId.routes:
          await syncProvider.downloadRoutes(id: id);
           
          break;
        case NotificationId.units:
          await syncProvider.downloadUnits(id: id);
           
          break;
        case NotificationId.productUnits:
          await syncProvider.downloadProductUnits(id: id);
           
          break;
        case NotificationId.productCar:
          await syncProvider.downloadProductCar(id: id);
           
          break;
        case NotificationId.updateStoreKeeper:
          await syncProvider.updateStoreKeeper(id: id);
           
          break;
        case NotificationId.logout:
          await syncProvider.logout();
           
          break;
        default:
           
          break;
      }
       
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationHandler: Error downloading item: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

