# Push Notification System - Role-Based Updates & Non-Delivered Push Handling

This document explains the push notification system in the KMP project, detailing what updates are notified to each role and how the system handles non-delivered pushes.

## Overview

The application uses a push notification system to notify users about updates to orders, products, out-of-stock items, and other entities. Notifications include metadata (`data_ids`) that tells the app what data to download and sync locally.

## Notification Structure

Each push notification contains:
- **`ids`**: Array of user IDs to notify, each with:
  - `user_id`: The target user's ID
  - `silent_push`: 0 = show notification, 1 = silent (background sync only)
- **`data_message`**: User-facing message text
- **`data`**: Metadata object containing:
  - `data_ids`: Array of table/id pairs specifying what data to download
  - `show_notification`: Flag (0 or 1) for UI notification display
  - `message`: Notification message text

### Notification Table IDs

The system uses numeric table IDs to identify entity types:
- `1` = PRODUCT
- `2` = CAR_BRAND
- `3` = CAR_NAME
- `4` = CAR_MODEL
- `5` = CAR_VERSION
- `6` = CATEGORY
- `7` = SUB_CATEGORY
- `8` = ORDER
- `9` = ORDER_SUB
- `10` = ORDER_SUB_SUGGESTION
- `11` = OUT_OF_STOCK
- `12` = OUT_OF_STOCK_SUB
- `13` = CUSTOMER
- `14` = USER
- `15` = SALESMAN
- `16` = SUPPLIER
- `17` = ROUTES
- `18` = UNITS
- `19` = PRODUCT_UNITS
- `20` = PRODUCT_CAR
- `21` = UPDATE_STORE_KEEPER
- `22` = LOGOUT

## Role-Based Notification Rules

### User Types
- **ADMIN** (1): Full access, receives most notifications
- **STOREKEEPER** (2): Manages inventory and order fulfillment
- **SALESMAN** (3): Creates and manages orders
- **SUPPLIER** (4): Handles out-of-stock items
- **BILLER** (5): Processes billing
- **CHECKER** (6): Verifies completed orders
- **DRIVER** (7): Delivery management

### Order-Related Notifications

#### 1. New Order Created (`sendOrder`)
When a salesman creates and sends a new order:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **STOREKEEPER**: Visible push (0) - "New Order Received"
- **Notification Data:**
  - Empty `data_ids` initially (order data comes in API response)
  - After order creation, `data_ids` include:
    - Table 8 (ORDER) with order ID
    - Table 9 (ORDER_SUB) for each order sub-item

#### 2. Storekeeper Updates Order (`informUpdates`)
When a storekeeper updates order items (quantities, notes, out-of-stock):
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **STOREKEEPER**: Silent push (1) - excluding the current storekeeper
  - **BILLER**: Silent push (1) - only if `billerId != -1`
  - **SALESMAN**: Visible push (0) - "Updates from storekeeper"
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 3. Storekeeper Verifies Order (`verifyOrder`)
When a storekeeper verifies and completes order checking:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **STOREKEEPER**: Silent push (1) - excluding current storekeeper
  - **BILLER**: Silent push (1) - only if `billerId != -1`
  - **SALESMAN**: Visible push (0) - "Order verified"
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 4. Send to Biller (`sendToBillerOrChecker` with `isBiller = true`)
When order is sent to a biller:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **BILLER**: Visible push (0) - all billers - "Order received"
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 5. Send to Checker (`sendToCheckers`)
When order is sent to checker:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **CHECKER**: Visible push (0) - all checkers - "Order received"
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 6. Checker Starts Checking (`changeToChecking`)
When a checker starts checking an order:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **SALESMAN**: Silent push (1)
  - **CHECKER**: Silent push (1) - excluding current checker
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 7. Checker Completes Order (`completeOrder`)
When a checker completes order verification:
- **Notified Roles:**
  - **ADMIN**: Silent push (1)
  - **STOREKEEPER**: Silent push (1)
  - **BILLER**: Silent push (1) - only if `billerId != -1`
  - **CHECKER**: Silent push (1) - excluding current checker
  - **SALESMAN**: Visible push (0) - "Order checked and completed"
- **Notification Data:**
  - Table 8 (ORDER) with order ID

#### 8. Cancel Order (`cancelOrder`)
When an order is cancelled:
- **Notified Roles:**
  - **ADMIN**: Silent push (1) - excluding current admin
  - **STOREKEEPER**: Visible push (0) - "Order Cancelled"
  - **CHECKER**: Visible push (0) - only if `checkerId != -1`
  - **BILLER**: Visible push (0) - only if `billerId != -1`
  - **SUPPLIER**: Silent push (1) - for related out-of-stock items
- **Notification Data:**
  - Table 8 (ORDER) with order ID
  - Table 11 (OUT_OF_STOCK) for related out-of-stock masters
  - Table 12 (OUT_OF_STOCK_SUB) for related out-of-stock subs

#### 9. Update Storekeeper (`updateStoreKeeper`)
When storekeeper assignment changes (notification ID 21):
- **Notified Roles:**
  - Specific storekeeper (system-level notification)
- **Notification Data:**
  - Table 21 (UPDATE_STORE_KEEPER) with order ID
  - Triggers `storekeeperAlreadyCheckingTrigger` in NotificationManager

### Out-of-Stock Notifications

#### 1. Supplier Response (`decideAdmin`, `informAdminFromSupplier`)
When supplier responds to out-of-stock items:
- **Notified Roles:**
  - **ADMIN**: Visible push (0) - "Supplier response"
- **Notification Data:**
  - Table 11 (OUT_OF_STOCK) with master ID
  - Table 12 (OUT_OF_STOCK_SUB) with sub IDs

#### 2. Admin Marks Available (`markAvailableQty`, `markDecideAvailableQty`)
When admin confirms available quantity:
- **Notified Roles:**
  - **ADMIN**: Silent push (1) - excluding current admin
  - **SUPPLIER**: Visible push (0) - "Order confirmed"
- **Notification Data:**
  - Table 11 (OUT_OF_STOCK) with master ID
  - Table 12 (OUT_OF_STOCK_SUB) with sub IDs

### Master Data Updates

For product settings, categories, units, cars, customers, users, salesmen, suppliers:
- **Notified Roles:**
  - **All Users**: Silent push (1) - excluding current user
  - **Exception**: Suppliers are excluded from customer/user/salesman updates
- **Notification Data:**
  - Table ID corresponding to the updated entity type
  - Entity ID

### Logout Notification

When a user is logged out from all devices:
- **Notified Roles:**
  - **All Users**: Visible push (0)
- **Notification Data:**
  - Table 22 (LOGOUT) with ID 0
  - Triggers `notificationLogoutTrigger` in NotificationManager

## Non-Delivered Push Handling

The system handles missed or failed push notifications through a **FailedSync** mechanism.

### FailedSync Table

The `FailedSync` table tracks failed sync operations with:
- `id`: Primary key
- `table_id`: The table ID that failed to sync
- `data_id`: The specific entity ID that failed to download

### How It Works

#### 1. Failure Detection

When a push notification is received and processed:
- `PushNotificationHandler.handleNotification()` is called
- It extracts `data_ids` from the notification
- For each `data_id`, it calls the appropriate download method (e.g., `downloadOrder(id)`, `downloadProduct(id)`)

If the download API call fails:
- A `FailedSync` entry is created with:
  - `table_id`: The table ID from the notification
  - `data_id`: The entity ID that failed
- The failure is logged but doesn't block the app

#### 2. Retry Mechanism

The app retries failed syncs in several scenarios:

**a) On App Start:**
- `BaseScreen` calls `syncViewModel.getAllFailed()` in `LaunchedEffect(Unit)`
- This loads all entries from the `FailedSync` table
- A bottom bar appears if there are failed syncs

**b) On Notification Trigger:**
- When `NotificationManager.triggerRefresh()` is called (after successful sync)
- `BaseScreen` listens to `notificationTrigger` state
- Calls `syncViewModel.getAllFailed()` again to check for new failures

**c) Manual Retry:**
- Users can manually retry failed syncs from the failed syncs list
- Each retry attempts to download the specific entity by ID
- If successful, the `FailedSync` entry is deleted
- If it fails again, the entry remains for future retry

#### 3. Sync Process for Failed Items

When retrying a failed sync:

1. **Load FailedSync entries**: Get all entries from `FailedSync` table
2. **For each entry**: Call the appropriate download method with:
   - `id`: The `data_id` from FailedSync
   - `failedId`: The FailedSync entry's ID
3. **On Success**:
   - Data is downloaded and stored locally
   - The `FailedSync` entry is deleted: `failedSyncRepository.delete(failedId)`
   - `NotificationManager.triggerRefresh()` is called to update UI
4. **On Failure**:
   - The `FailedSync` entry remains in the table
   - Error message is logged
   - User can retry later

#### 4. Example Flow

```
1. Push notification received: {table: 8, id: 123}
2. App calls downloadOrder(123)
3. API call fails (network error, timeout, etc.)
4. FailedSync entry created: {table_id: 8, data_id: 123}
5. User opens app → getAllFailed() loads the entry
6. User retries → downloadOrder(123, failedId: 1)
7. API call succeeds
8. Order data saved locally
9. FailedSync entry with id=1 is deleted
10. UI refreshed
```

### Key Implementation Details

1. **Silent vs Visible Pushes**:
   - `silent_push: 0` = User sees notification, data syncs in background
   - `silent_push: 1` = No user notification, data syncs silently

2. **Current User Exclusion**:
   - The user who triggered the action is always excluded from notifications
   - Prevents unnecessary notifications to the initiator

3. **Conditional Notifications**:
   - Some roles are notified only if certain conditions are met (e.g., `billerId != -1`)
   - Storekeepers are excluded if they're the one making the update

4. **Batch Notifications**:
   - Multiple `data_ids` can be included in a single notification
   - Each triggers a separate download operation

5. **Error Handling**:
   - Network failures don't crash the app
   - Failed syncs are persisted for retry
   - Users are informed of failed syncs via UI indicators

## Benefits of This Approach

1. **Resilience**: App continues to function even if some notifications fail
2. **Data Consistency**: Failed syncs are tracked and retried until successful
3. **User Control**: Users can manually retry failed syncs
4. **Offline Support**: Failed syncs persist across app restarts
5. **Efficient Notifications**: Silent pushes reduce UI noise while keeping data in sync

## Migration Notes for Flutter

When implementing this in Flutter:
1. Maintain the same notification structure and table IDs
2. Implement `FailedSync` table in sqflite
3. Use `getAllFailed()` pattern for retry mechanism
4. Call retry logic on app start and after notification triggers
5. Preserve the role-based notification rules exactly as in KMP
6. Use silent_push flag to control notification display in Flutter
7. Implement `NotificationManager` equivalent using Provider or similar state management


