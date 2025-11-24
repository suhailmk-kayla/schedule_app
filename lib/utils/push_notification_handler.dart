import 'dart:developer' as developer;
import 'notification_id.dart';
import 'notification_manager.dart';
import '../presentation/provider/sync_provider.dart';

/// Push Notification Handler
/// Processes incoming push notifications and triggers data downloads
/// Converted from KMP's PushNotificationHandler.kt
class PushNotificationHandler {
  /// Handle notification from OneSignal
  /// Extracts data_ids array and processes each item
  static Future<void> handleNotification(
    Map<String, dynamic> notificationData,
    SyncProvider syncProvider,
  ) async {
    try {
      developer.log('PushNotificationHandler: Processing notification: $notificationData');

      // Extract data from notification
      // OneSignal structure: notification.additionalData contains the payload
      // The payload structure matches KMP: { "data": { "data_ids": [...] } }
      Map<String, dynamic>? data;
      
      // Try to extract from different possible locations (matching KMP pattern)
      if (notificationData.containsKey('data')) {
        data = notificationData['data'] as Map<String, dynamic>?;
        developer.log('PushNotificationHandler: Data found in notification: $data');
      } else if (notificationData.containsKey('custom')) {
        final custom = notificationData['custom'];
        developer.log('PushNotificationHandler: Custom found in notification: $custom');
        if (custom is Map<String, dynamic> && custom.containsKey('a')) {
          data = custom['a'] as Map<String, dynamic>?;
          developer.log('PushNotificationHandler: Data found in custom: $data');
        }
      } else {
        // If notificationData itself is the data object
        data = notificationData;
        developer.log('PushNotificationHandler: Data found in notification: $data');
      }

      if (data == null) {
        developer.log('PushNotificationHandler: No data found in notification');
        return;
      }
      // Extract data_ids array
      final dataIds = data['data_ids'] as List<dynamic>?;
      if (dataIds == null || dataIds.isEmpty) {
        developer.log('PushNotificationHandler: No data_ids found in notification');
        return;
      }

      developer.log('PushNotificationHandler: Found ${dataIds.length} data items to process');

      // Process each data_id item

  for (final item in dataIds) {
    developer.log('PushNotificationHandler: Processing item: $item');
    if (item is Map) {
   final converted = Map<String, dynamic>.from(item);
  await _downloadItem(syncProvider, converted);
    }else{
      developer.log('the type of item is ${item.runtimeType}');
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
      developer.log('PushNotificationHandler: Downloading item - table: $table, id: $id');
      if (table == 0 || id == 0) {
        developer.log('PushNotificationHandler: Invalid table or id: table=$table, id=$id');
        return;
      }

      developer.log('PushNotificationHandler: Downloading item - table: $table, id: $id');

      // Route to appropriate download method based on table ID
      switch (table) {
        case NotificationId.product:
          await syncProvider.downloadProduct(id: id);
          developer.log('PushNotificationHandler: Product downloaded: $id');
          break;
        case NotificationId.carBrand:
          await syncProvider.downloadCarBrand(id: id);
          developer.log('PushNotificationHandler: CarBrand downloaded: $id');
          break;
        case NotificationId.carName:
          await syncProvider.downloadCarName(id: id);
          developer.log('PushNotificationHandler: CarName downloaded: $id');
          break;
        case NotificationId.carModel:
          await syncProvider.downloadCarModel(id: id);
          developer.log('PushNotificationHandler: CarModel downloaded: $id');
          break;
        case NotificationId.carVersion:
          await syncProvider.downloadCarVersion(id: id);
          developer.log('PushNotificationHandler: CarVersion downloaded: $id');
          break;
        case NotificationId.category:
          await syncProvider.downloadCategory(id: id);
          developer.log('PushNotificationHandler: Category downloaded: $id');
          break;
        case NotificationId.subCategory:
          await syncProvider.downloadSubCategory(id: id);
          developer.log('PushNotificationHandler: SubCategory downloaded: $id');
          break;
        case NotificationId.order:
          await syncProvider.downloadOrder(id: id);
          developer.log('PushNotificationHandler: Order downloaded: $id');
          break;
        case NotificationId.orderSub:
          await syncProvider.downloadOrderSub(id: id);
          developer.log('PushNotificationHandler: OrderSub downloaded: $id');
          break;
        case NotificationId.orderSubSuggestion:
          await syncProvider.downloadOrderSubSuggestion(id: id);
          developer.log('PushNotificationHandler: OrderSubSuggestion downloaded: $id');
          break;
        case NotificationId.outOfStock:
          await syncProvider.downloadOutOfStock(id: id);
          developer.log('PushNotificationHandler: OutOfStock downloaded: $id');
          break;
        case NotificationId.outOfStockSub:
          await syncProvider.downloadOutOfStockSub(id: id);
          developer.log('PushNotificationHandler: OutOfStockSub downloaded: $id');
          break;
        case NotificationId.customer:
          await syncProvider.downloadCustomer(id: id);
          developer.log('PushNotificationHandler: Customer downloaded: $id');
          break;
        case NotificationId.user:
          await syncProvider.downloadUser(id: id);
          developer.log('PushNotificationHandler: User downloaded: $id');
          break;
        case NotificationId.salesman:
          await syncProvider.downloadSalesman(id: id);
          developer.log('PushNotificationHandler: Salesman downloaded: $id');
          break;
        case NotificationId.supplier:
          await syncProvider.downloadSupplier(id: id);
          developer.log('PushNotificationHandler: Supplier downloaded: $id');
          break;
        case NotificationId.routes:
          await syncProvider.downloadRoutes(id: id);
          developer.log('PushNotificationHandler: Routes downloaded: $id');
          break;
        case NotificationId.units:
          await syncProvider.downloadUnits(id: id);
          developer.log('PushNotificationHandler: Units downloaded: $id');
          break;
        case NotificationId.productUnits:
          await syncProvider.downloadProductUnits(id: id);
          developer.log('PushNotificationHandler: ProductUnits downloaded: $id');
          break;
        case NotificationId.productCar:
          await syncProvider.downloadProductCar(id: id);
          developer.log('PushNotificationHandler: ProductCar downloaded: $id');
          break;
        case NotificationId.updateStoreKeeper:
          await syncProvider.updateStoreKeeper(id: id);
          developer.log('PushNotificationHandler: UpdateStoreKeeper downloaded: $id');
          break;
        case NotificationId.logout:
          await syncProvider.logout();
          developer.log('PushNotificationHandler: Logout downloaded: $id');
          break;
        default:
          developer.log('PushNotificationHandler: Unknown table ID: $table');
          break;
      }
      developer.log('PushNotificationHandler: Successfully downloaded ${NotificationId.getTableName(table)} (id: $id)');
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationHandler: Error downloading item: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

