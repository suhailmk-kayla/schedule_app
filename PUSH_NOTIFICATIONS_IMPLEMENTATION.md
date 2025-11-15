# Push Notifications Implementation

## Overview
This document describes the push notification system implementation in Flutter, converted from the KMP project.

## Architecture

### Components

1. **NotificationId** (`lib/utils/notification_id.dart`)
   - Defines constants for all table types (1-22)
   - Maps table IDs to table names

2. **NotificationManager** (`lib/utils/notification_manager.dart`)
   - Manages UI refresh triggers
   - Singleton pattern using ChangeNotifier
   - Triggers: `notificationTrigger`, `notificationLogoutTrigger`, `storekeeperAlreadyCheckingTrigger`

3. **PushNotificationHandler** (`lib/utils/push_notification_handler.dart`)
   - Processes incoming push notifications
   - Extracts `data_ids` array from notification payload
   - Routes to appropriate download methods in SyncProvider

4. **PushNotificationHelper** (`lib/utils/push_notification_helper.dart`)
   - Initializes OneSignal SDK
   - Sets up notification listeners (foreground, background, click)
   - Extracts notification data and routes to PushNotificationHandler

5. **SyncProvider** (`lib/presentation/provider/sync_provider.dart`)
   - Public methods for downloading individual records by ID
   - Private methods support both full sync (`id == -1`) and single record download (`id != -1`)

## Notification Payload Structure

The server sends OneSignal notifications with this structure:

```json
{
  "additionalData": {
    "data": {
      "data_ids": [
        {"table": 1, "id": 456},  // table = NotificationId.PRODUCT
        {"table": 15, "id": 789}   // table = NotificationId.SALESMAN
      ],
      "show_notification": "0",  // "0" = silent push, "1" = show notification
      "message": "Product updates"
    }
  }
}
```

## Flow

1. **Notification Received** → OneSignal SDK receives push notification
2. **PushNotificationHelper** → Extracts `additionalData` from notification
3. **PushNotificationHandler** → Processes `data_ids` array
4. **SyncProvider** → Downloads each record by calling `downloadX(id: id)`
5. **NotificationManager** → Triggers UI refresh after downloads complete

## Implementation Status

### ✅ Completed
- NotificationId constants
- NotificationManager
- PushNotificationHandler
- PushNotificationHelper with listeners
- Public download methods in SyncProvider
- `_downloadSalesmen` supports `id` parameter (example implementation)

### ⚠️ Pending (Need Updates)

#### Repository Methods
Most repository `syncXFromApi` methods need to support optional `id` parameter:

**Pattern to follow** (from `salesman_repository.dart`):
```dart
Future<Either<Failure, Map<String, dynamic>>> syncXFromApi({
  required int partNo,
  required int limit,
  required int userType,
  required int userId,
  required String updateDate,
  int id = -1, // -1 for full sync, specific id for single record
}) async {
  final Map<String, String> queryParams;
  
  if (id == -1) {
    // Full sync mode
    queryParams = {
      'part_no': partNo.toString(),
      'limit': limit.toString(),
      'user_type': userType.toString(),
      'user_id': userId.toString(),
      'update_date': updateDate,
    };
  } else {
    // Single record mode
    queryParams = {
      'id': id.toString(),
    };
  }
  
  final response = await _dio.get(
    ApiEndpoints.xDownload,
    queryParameters: queryParams,
  );
  
  return Right(Map<String, dynamic>.from(response.data));
}
```

**Repositories that need updates:**
- `products_repository.dart` - `syncProductsFromApi`
- `categories_repository.dart` - `syncCategoriesFromApi`
- `sub_categories_repository.dart` - `syncSubCategoriesFromApi`
- `units_repository.dart` - `syncUnitsFromApi`
- `orders_repository.dart` - `syncOrdersFromApi`
- `customers_repository.dart` - `syncCustomersFromApi`
- `routes_repository.dart` - `syncRoutesFromApi`
- `users_repository.dart` - `syncUsersFromApi`
- `suppliers_repository.dart` - `syncSuppliersFromApi`
- `car_brand_repository.dart` - `syncCarBrandsFromApi`
- `car_name_repository.dart` - `syncCarNamesFromApi`
- `car_model_repository.dart` - `syncCarModelsFromApi`
- `car_version_repository.dart` - `syncCarVersionsFromApi`
- `user_category_repository.dart` - `syncUserCategoriesFromApi`
- `order_sub_suggestions_repository.dart` - `syncOrderSubSuggestionsFromApi`
- `out_of_stock_repository.dart` - `syncOutOfStockFromApi`
- And others...

#### SyncProvider Private Methods
Most private `_downloadX` methods need to support `id` parameter:

**Pattern to follow** (from `_downloadSalesmen`):
```dart
Future<void> _downloadX({
  int id = -1, // -1 for full sync, specific id for retry
  int failedId = -1, // FailedSync record id if this is a retry
  void Function()? finished, // Callback for retry mode
}) async {
  if (id == -1) {
    // Full sync mode
    _updateTask('X details downloading...');
  }
  
  final updateDate = _getSyncTimeForTable('X');
  final userType = _cachedUserType ?? 0;
  final userId = _cachedUserId ?? 0;
  
  final result = await _xRepository.syncXFromApi(
    partNo: _xPart,
    limit: _limit,
    userType: userType,
    userId: userId,
    updateDate: updateDate,
    id: id, // Pass id parameter
  );

  result.fold(
    (failure) {
      if (id != -1 && failedId == -1) {
        // Retry mode failed: create FailedSync entry
        _failedSyncRepository.addFailedSync(
          tableId: NotificationId.X,
          dataId: id,
        ).then((_) {
          if (finished != null) finished();
        });
      } else {
        _updateError(failure.message, true);
      }
    },
    (response) async {
      // Process response...
      if (id == -1) {
        // Full sync mode logic
      } else {
        // Single record mode logic
        if (failedId != -1) {
          await _failedSyncRepository.deleteFailedSync(failedId);
        }
        if (finished != null) finished();
      }
    },
  );
}
```

**Methods that need updates:**
- `_downloadProducts`
- `_downloadCarBrand`
- `_downloadCarName`
- `_downloadCarModel`
- `_downloadCarVersion`
- `_downloadCategory`
- `_downloadSubCategory`
- `_downloadOrders`
- `_downloadOrderSubs`
- `_downloadOrderSubSuggestions`
- `_downloadOutOfStock`
- `_downloadOutOfStockSub`
- `_downloadCustomers`
- `_downloadUsers`
- `_downloadSuppliers`
- `_downloadRoutes`
- `_downloadUnits`
- `_downloadUserCategories`
- And others...

## Testing

To test push notifications:

1. **Send test notification via OneSignal Dashboard:**
   ```json
   {
     "additional_data": {
       "data": {
         "data_ids": [
           {"table": 1, "id": 123}
         ],
         "show_notification": "0",
         "message": "Test notification"
       }
     }
   }
   ```

2. **Check logs:**
   - `PushNotificationHelper: OneSignal notification received...`
   - `PushNotificationHandler: Processing notification...`
   - `SyncProvider: Downloading item - table: 1, id: 123`

3. **Verify:**
   - Record is downloaded and stored in local database
   - UI refreshes (if listening to NotificationManager)

## Notes

- Silent pushes (`show_notification: "0"`) prevent default notification display
- All downloads happen in background without blocking UI
- Failed downloads are tracked in `FailedSync` table for retry
- UI refresh is triggered via `NotificationManager.triggerRefresh()`

