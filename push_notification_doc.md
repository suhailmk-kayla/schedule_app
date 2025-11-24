# Complete Push Notification System Documentation

## Overview
This document provides comprehensive documentation for the Push Notification system integrated with OneSignal. The system supports both **silent push notifications** (for data synchronization) and **visible notifications** (for user alerts).

**Technology Stack:**
- **Backend:** Laravel PHP
- **Push Service:** OneSignal
- **Protocol:** HTTP REST API
- **Authentication:** Laravel Sanctum Bearer Token

---

## Table of Contents

1. [API Endpoint for Manual Push Notifications](#api-endpoint-for-manual-push-notifications)
2. [Request Parameters](#request-parameters)
3. [Response Format](#response-format)
4. [Notification Service Provider](#notification-service-provider)
5. [Automatic Notification Triggers](#automatic-notification-triggers)
6. [Silent Push vs Visible Notifications](#silent-push-vs-visible-notifications)
7. [OneSignal Integration Details](#onesignal-integration-details)
8. [Notification Payload Structure](#notification-payload-structure)
9. [Flutter Implementation Guide](#flutter-implementation-guide)
10. [Examples and Use Cases](#examples-and-use-cases)

---

## API Endpoint for Manual Push Notifications

### Endpoint Details

**URL:** `POST /api/push_notification/add`  
**Base URL:** `{YOUR_BASE_URL}/api/push_notification/add`  
**Authentication:** Required (Bearer Token)  
**Route Definition:** Line 51 in `routes/api.php`

---

## Request Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ids` | array | Array of user objects with user IDs and silent push flags |
| `data` | object | Custom data payload to be sent with the notification |

### Optional Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `data_message` | string | Message text for visible notifications | "Notification Data" |

### Request Body Structure

```json
{
  "ids": [
    {
      "user_id": 1,
      "silent_push": 0
    },
    {
      "user_id": 2,
      "silent_push": 1
    }
  ],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 0,
    "message": "New Order Created",
    "custom_key": "custom_value"
  },
  "data_message": "You have a new order"
}
```

### Parameter Details

#### `ids` Array
Each object in the `ids` array contains:
- `user_id` (integer, required): The ID of the user to send notification to
- `silent_push` (integer, optional): 
  - `0` = Visible notification (shows banner/alert)
  - `1` = Silent push (no visible alert, only data payload)
  - Default: `0`

#### `data` Object
The `data` object can contain any custom key-value pairs. Common structure:
- `data_ids` (array): Array of objects indicating which data was updated
  - `table` (integer): Table identifier (e.g., 8 = Orders)
  - `id` (integer): Record ID that was updated
- `show_notification` (integer): 
  - `0` = Silent push
  - `1` = Show notification
- `message` (string): Custom message
- Any other custom fields your app needs

#### `data_message` String
The message text that appears in visible notifications. Only used when `silent_push = 0`.

---

## Response Format

### Success Response (200 OK)

```json
{
  "status": 1,
  "message": "Notification sent successfully",
  "data": ""
}
```

### Error Response (200 OK with status 2)

```json
{
  "status": 2,
  "message": "Notification not sent",
  "data": ""
}
```

**Note:** The API returns status 200 even on errors. Check the `status` field (1 = success, 2 = error).

---

## Notification Service Provider

The core notification sending logic is handled by `NotificationServiceProvider`.

**File Location:** `app/Providers/NotificationServiceProvider.php`

### How It Works

The `send()` method:
1. Iterates through each user ID in the `ids` array
2. Finds the user and retrieves their `device_token` (OneSignal Player ID)
3. Skips users without device tokens
4. Builds OneSignal notification payload
5. Always includes silent push settings (`content_available: true`, `priority: 10`)
6. Conditionally adds visible notification elements if `silent_push = 0`
7. Sends to OneSignal API via cURL
8. Processes each user individually

### Key Code Sections

**Silent Push Detection:**
```php
$silentPush = $row['silent_push'] ?? 0;
```

**Base Notification Payload (Always Included):**
```php
$notification_data = [
    'app_id' => $app_id,
    'include_player_ids' => [$deviceToken],
    'data' => $data,
    'content_available' => true, // Required for silent push on iOS
    'priority' => 10, // Required for silent push on Android
];
```

**Visible Notification Elements (Only if silent_push = 0):**
```php
if (!$silentPush) {
    $notification_data += [
        'icon' => $imageUrl,
        'android_large_icon' => $imageUrl,
        'ios_attachments' => ['id1' => $imageUrl],
        'headings' => ['en' => 'Schedule'],
        'contents' => ['en' => $dataMessage]
    ];
}
```

**OneSignal API Call:**
```php
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://onesignal.com/api/v1/notifications');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Basic ' . $api_key,
]);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($notification_data));
$response = curl_exec($ch);
curl_close($ch);
```

---

## Automatic Notification Triggers

The system automatically sends notifications when certain operations occur, if the `notification` parameter is included in the request.

### 1. Order Operations

#### Add Order
**Endpoint:** `POST /api/orders/add`  
**Location:** `app/Http/Controllers/Api/Operation/OrderController.php` (lines 130-147)

When an order is added, if `notification` parameter is present:
- Automatically adds `data_ids` with table 8 (Orders) and the new order ID
- Sets `show_notification: 0` (silent push)
- Sets message to "New Order"
- Merges with your notification data
- Sends notification to specified users

**Example Request:**
```json
{
  "uuid": "unique-uuid",
  "order_cust_id": 1,
  "items": [...],
  "notification": {
    "ids": [
      {"user_id": 5, "silent_push": 1}
    ],
    "data": {},
    "data_message": "New Order"
  }
}
```

**What Backend Adds:**
```json
{
  "data_ids": [
    {"table": 8, "id": {new_order_id}}
  ],
  "show_notification": 0,
  "message": "New Order"
}
```

#### Other Order Endpoints with Automatic Notifications:
- `POST /api/orders/update_order` (line 294-297)
- `POST /api/orders/update_order_sub` (line 363-366)
- `POST /api/orders/update_biller_adn_checker` (line 387-390)
- `POST /api/orders/update_order_flag` (line 573-576)
- `POST /api/orders/update_store_keeper` (line 610-613)

### 2. User Operations

- `POST /api/users/logoutUserDevice` (line 346-349)
- `POST /api/users/logoutAllUserDevice` (line 370-373)

---

## Silent Push vs Visible Notifications

### Silent Push Notification

**When:** `silent_push = 1` or when `show_notification = 0` in data

**Characteristics:**
- No visible alert/banner to user
- App receives notification in background
- Used for data synchronization
- Always includes `content_available: true` (iOS) and `priority: 10` (Android)
- No `headings` or `contents` fields

**OneSignal Payload (Silent):**
```json
{
  "app_id": "your-onesignal-app-id",
  "include_player_ids": ["device-token-123"],
  "data": {
    "data_ids": [{"table": 8, "id": 123}],
    "show_notification": 0,
    "message": "New Order"
  },
  "content_available": true,
  "priority": 10
}
```

**Use Cases:**
- Data synchronization
- Background updates
- Silent data refresh
- Order status updates

### Visible Notification

**When:** `silent_push = 0` and `show_notification = 1`

**Characteristics:**
- Shows banner/alert to user
- Displays heading and message
- Includes icon/image
- User can tap to open app
- Includes all silent push settings PLUS visible elements

**OneSignal Payload (Visible):**
```json
{
  "app_id": "your-onesignal-app-id",
  "include_player_ids": ["device-token-123"],
  "data": {
    "data_ids": [{"table": 8, "id": 123}],
    "show_notification": 1,
    "message": "New Order"
  },
  "content_available": true,
  "priority": 10,
  "icon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg",
  "android_large_icon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg",
  "ios_attachments": {
    "id1": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg"
  },
  "headings": {
    "en": "Schedule"
  },
  "contents": {
    "en": "You have a new order"
  }
}
```

**Use Cases:**
- Important alerts
- User action required
- New order notifications
- Status changes requiring attention

---

## OneSignal Integration Details

### Configuration

**Config File:** `config/custom.php`

```php
return [
    'onsignal_app_key' => env('ONSIGNAL_APP_KEY'),
    'onsignal_api_key' => env('ONSIGNAL_API_KEY'),
];
```

**Environment Variables Required:**
- `ONSIGNAL_APP_KEY`: Your OneSignal App ID
- `ONSIGNAL_API_KEY`: Your OneSignal REST API Key

### OneSignal API Endpoint

**URL:** `https://onesignal.com/api/v1/notifications`  
**Method:** POST  
**Authentication:** Basic Auth with API Key  
**Content-Type:** application/json

### Headers Sent to OneSignal

```
Content-Type: application/json
Authorization: Basic {your-onesignal-api-key}
```

### Device Token

- **Source:** `users.device_token` field in database
- **Set During:** User login (stored when user logs in)
- **Used As:** OneSignal Player ID (`include_player_ids`)
- **Format:** OneSignal Player ID string

---

## Notification Payload Structure

### What Frontend Sends to Backend API

```json
{
  "ids": [
    {
      "user_id": 1,
      "silent_push": 0
    }
  ],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 0,
    "message": "Order updated",
    "custom_field": "custom_value"
  },
  "data_message": "Your order has been updated"
}
```

### What Backend Sends to OneSignal

**For Silent Push (`silent_push = 1`):**
```json
{
  "app_id": "abc123-def456-ghi789",
  "include_player_ids": ["onesignal-player-id-123"],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 0,
    "message": "Order updated",
    "custom_field": "custom_value"
  },
  "content_available": true,
  "priority": 10
}
```

**For Visible Notification (`silent_push = 0`):**
```json
{
  "app_id": "abc123-def456-ghi789",
  "include_player_ids": ["onesignal-player-id-123"],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 1,
    "message": "Order updated",
    "custom_field": "custom_value"
  },
  "content_available": true,
  "priority": 10,
  "icon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg",
  "android_large_icon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg",
  "ios_attachments": {
    "id1": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg"
  },
  "headings": {
    "en": "Schedule"
  },
  "contents": {
    "en": "Your order has been updated"
  }
}
```

### What Client Receives (Flutter/App)

When the app receives the notification, it gets:

**For Silent Push:**
```json
{
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 0,
    "message": "Order updated",
    "custom_field": "custom_value"
  },
  "custom": {
    // Any additional OneSignal metadata
  }
}
```

**For Visible Notification:**
```json
{
  "notification": {
    "title": "Schedule",
    "body": "Your order has been updated",
    "android": {
      "smallIcon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg",
      "largeIcon": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg"
    },
    "ios": {
      "attachments": {
        "id1": "http://litemathpos.in/mobileApp/uploads/schedule_logo.jpg"
      }
    }
  },
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 1,
    "message": "Order updated",
    "custom_field": "custom_value"
  }
}
```

---

## Flutter Implementation Guide

### Step 1: Add Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
  onesignal_flutter: ^5.0.0  # For receiving notifications
```

### Step 2: Send Push Notification from Flutter

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class PushNotificationService {
  final String baseUrl;
  final String token;

  PushNotificationService({
    required this.baseUrl,
    required this.token,
  });

  Future<Map<String, dynamic>> sendNotification({
    required List<int> userIds,
    required Map<String, dynamic> data,
    String? dataMessage,
    bool silentPush = false,
  }) async {
    const String endpoint = '/api/push_notification/add';
    
    final List<Map<String, dynamic>> ids = userIds.map((userId) {
      return {
        'user_id': userId,
        'silent_push': silentPush ? 1 : 0,
      };
    }).toList();
    
    final Map<String, dynamic> body = {
      'ids': ids,
      'data': data,
    };
    
    if (dataMessage != null && dataMessage.isNotEmpty) {
      body['data_message'] = dataMessage;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        if (responseData['status'] == 1) {
          return {
            'success': true,
            'message': responseData['message'],
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'],
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Request failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Helper method to send silent push for data sync
  Future<Map<String, dynamic>> sendSilentPush({
    required List<int> userIds,
    required int tableId,
    required int recordId,
    String? message,
  }) async {
    return await sendNotification(
      userIds: userIds,
      data: {
        'data_ids': [
          {
            'table': tableId,
            'id': recordId,
          }
        ],
        'show_notification': 0,
        'message': message ?? 'Data updated',
      },
      silentPush: true,
    );
  }

  // Helper method to send visible notification
  Future<Map<String, dynamic>> sendVisibleNotification({
    required List<int> userIds,
    required String message,
    required int tableId,
    required int recordId,
  }) async {
    return await sendNotification(
      userIds: userIds,
      data: {
        'data_ids': [
          {
            'table': tableId,
            'id': recordId,
          }
        ],
        'show_notification': 1,
        'message': message,
      },
      dataMessage: message,
      silentPush: false,
    );
  }
}
```

### Step 3: Usage Examples

```dart
final pushService = PushNotificationService(
  baseUrl: 'https://yourdomain.com',
  token: 'your_sanctum_token',
);

// Example 1: Send silent push for data sync
await pushService.sendSilentPush(
  userIds: [1, 2, 3],
  tableId: 8, // Orders table
  recordId: 123,
  message: 'Order updated',
);

// Example 2: Send visible notification
await pushService.sendVisibleNotification(
  userIds: [1, 2, 3],
  message: 'You have a new order!',
  tableId: 8,
  recordId: 123,
);

// Example 3: Custom notification with additional data
await pushService.sendNotification(
  userIds: [1],
  data: {
    'data_ids': [
      {'table': 8, 'id': 123}
    ],
    'show_notification': 0,
    'message': 'Custom message',
    'order_status': 'pending',
    'customer_name': 'John Doe',
  },
  dataMessage: 'Order status changed',
  silentPush: true,
);
```

### Step 4: Include Notification in Order Updates

When updating an order, include the notification parameter:

```dart
Future<void> updateOrder({
  required int orderId,
  required Map<String, dynamic> orderData,
  List<int>? notifyUserIds,
}) async {
  final Map<String, dynamic> body = {
    'order_id': orderId,
    ...orderData,
  };
  
  // Add notification if user IDs provided
  if (notifyUserIds != null && notifyUserIds.isNotEmpty) {
    body['notification'] = {
      'ids': notifyUserIds.map((id) => {
        'user_id': id,
        'silent_push': 1, // Silent push for data sync
      }).toList(),
      'data': {},
      'data_message': 'Order updated',
    };
  }
  
  final response = await http.post(
    Uri.parse('$baseUrl/api/orders/update_order'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );
  
  // Handle response...
}
```

---

## Examples and Use Cases

### Example 1: Send Silent Push for Order Update

**Request:**
```json
POST /api/push_notification/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "ids": [
    {
      "user_id": 5,
      "silent_push": 1
    }
  ],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 123
      }
    ],
    "show_notification": 0,
    "message": "Order #123 has been updated"
  },
  "data_message": "Order updated"
}
```

**What Happens:**
1. Backend receives request
2. Finds user with ID 5
3. Gets user's `device_token` (OneSignal Player ID)
4. Sends to OneSignal with `content_available: true` and `priority: 10`
5. No visible notification shown to user
6. App receives notification in background
7. App can sync data based on `data_ids`

### Example 2: Send Visible Notification for New Order

**Request:**
```json
POST /api/push_notification/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "ids": [
    {
      "user_id": 3,
      "silent_push": 0
    },
    {
      "user_id": 4,
      "silent_push": 0
    }
  ],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 456
      }
    ],
    "show_notification": 1,
    "message": "New order received"
  },
  "data_message": "You have a new order #456"
}
```

**What Happens:**
1. Backend receives request
2. Finds users with IDs 3 and 4
3. Gets their `device_token` values
4. Sends to OneSignal with:
   - Silent push settings (`content_available: true`, `priority: 10`)
   - Visible notification elements (`headings`, `contents`, `icon`)
5. Users see notification banner: "Schedule - You have a new order #456"
6. Users can tap to open app
7. App receives both notification and data payload

### Example 3: Automatic Notification on Order Creation

**Request:**
```json
POST /api/orders/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "uuid": "unique-uuid-123",
  "order_cust_id": 1,
  "items": [...],
  "notification": {
    "ids": [
      {
        "user_id": 2,
        "silent_push": 1
      }
    ],
    "data": {},
    "data_message": "New Order"
  }
}
```

**What Backend Does:**
1. Creates order
2. Detects `notification` parameter
3. Automatically adds to notification data:
   ```json
   {
     "data_ids": [
       {
         "table": 8,
         "id": {new_order_id}
       }
     ],
     "show_notification": 0,
     "message": "New Order"
   }
   ```
4. Calls `notificationService->send(notification)`
5. Sends silent push to user ID 2

### Example 4: Multiple Users with Mixed Notification Types

**Request:**
```json
POST /api/push_notification/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "ids": [
    {
      "user_id": 1,
      "silent_push": 0
    },
    {
      "user_id": 2,
      "silent_push": 1
    },
    {
      "user_id": 3,
      "silent_push": 0
    }
  ],
  "data": {
    "data_ids": [
      {
        "table": 8,
        "id": 789
      }
    ],
    "show_notification": 1,
    "message": "Order status changed"
  },
  "data_message": "Order #789 status has been updated"
}
```

**What Happens:**
- User 1: Receives **visible notification** (silent_push = 0)
- User 2: Receives **silent push** (silent_push = 1)
- User 3: Receives **visible notification** (silent_push = 0)

Each user gets the notification according to their `silent_push` setting.

---

## Table Reference for Data IDs

When sending `data_ids` in notifications, use these table identifiers:

| Table ID | Table Name | Description |
|----------|------------|-------------|
| 8 | Orders | Order records |
| 11 | Out of Stock | Out of stock records |
| (Other IDs) | (Check your database) | Other tables as needed |

**Example:**
```json
{
  "data_ids": [
    {
      "table": 8,  // Orders table
      "id": 123     // Order ID 123
    }
  ]
}
```

---

## Error Handling

### Common Errors

1. **User Not Found:**
   - If `user_id` doesn't exist, that user is skipped
   - Notification continues for other users

2. **Missing Device Token:**
   - If user has no `device_token`, that user is skipped
   - Notification continues for other users

3. **OneSignal API Error:**
   - cURL errors are logged but don't stop the process
   - API returns status 2 if notification fails

4. **Invalid Parameters:**
   - Missing `ids` or `data` will cause validation errors
   - API returns validation error response

### Best Practices

1. **Always include `data_ids`** for data synchronization
2. **Use silent push** for background data updates
3. **Use visible notifications** for important alerts
4. **Handle missing device tokens** gracefully
5. **Validate user IDs** before sending
6. **Log notification failures** for debugging

---

## Testing

### Test with cURL

**Silent Push:**
```bash
curl -X POST "https://yourdomain.com/api/push_notification/add" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [
      {
        "user_id": 1,
        "silent_push": 1
      }
    ],
    "data": {
      "data_ids": [
        {
          "table": 8,
          "id": 123
        }
      ],
      "show_notification": 0,
      "message": "Test silent push"
    }
  }'
```

**Visible Notification:**
```bash
curl -X POST "https://yourdomain.com/api/push_notification/add" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [
      {
        "user_id": 1,
        "silent_push": 0
      }
    ],
    "data": {
      "data_ids": [
        {
          "table": 8,
          "id": 123
        }
      ],
      "show_notification": 1,
      "message": "Test visible notification"
    },
    "data_message": "This is a test notification"
  }'
```

---

## Configuration Checklist

Before using push notifications, ensure:

- [ ] OneSignal App ID is set in `.env` as `ONSIGNAL_APP_KEY`
- [ ] OneSignal REST API Key is set in `.env` as `ONSIGNAL_API_KEY`
- [ ] Users have valid `device_token` values (set during login)
- [ ] OneSignal SDK is integrated in Flutter app
- [ ] App has proper permissions for push notifications
- [ ] Notification icon URL is accessible
- [ ] Backend can reach OneSignal API (no firewall blocks)

---

## Troubleshooting

### Notifications Not Received

1. **Check device token:**
   - Verify user has `device_token` in database
   - Ensure token is valid OneSignal Player ID

2. **Check OneSignal dashboard:**
   - Verify app ID and API key are correct
   - Check delivery logs in OneSignal dashboard

3. **Check silent push settings:**
   - iOS: Ensure `content_available: true` is set
   - Android: Ensure `priority: 10` is set

4. **Check app permissions:**
   - iOS: Check notification permissions
   - Android: Check notification channel settings

### Silent Push Not Working

1. **iOS:**
   - Ensure app is configured for background notifications
   - Check `content_available: true` is in payload
   - Verify app delegate handles silent notifications

2. **Android:**
   - Ensure `priority: 10` is set
   - Check notification channel priority
   - Verify app handles data-only notifications

---

## Summary

### Key Points

1. **API Endpoint:** `POST /api/push_notification/add` (requires authentication)

2. **Required Parameters:**
   - `ids`: Array of user objects with `user_id` and `silent_push`
   - `data`: Custom data payload

3. **Notification Types:**
   - Silent Push: `silent_push = 1` (no visible alert)
   - Visible: `silent_push = 0` (shows banner/alert)

4. **Automatic Triggers:**
   - Order operations (add, update, etc.)
   - User operations (logout, etc.)
   - Include `notification` parameter in request

5. **OneSignal Integration:**
   - Uses `device_token` as Player ID
   - Always includes silent push settings
   - Conditionally adds visible elements

6. **Data Payload:**
   - `data_ids`: Array of table/ID pairs
   - `show_notification`: 0 or 1
   - `message`: Custom message
   - Any additional custom fields

---

## Code References

### Main Files

1. **Push Notification Controller:**
   - File: `app/Http/Controllers/Api/Operation/PushNotificationController.php`
   - Method: `add()` (lines 13-106)

2. **Notification Service Provider:**
   - File: `app/Providers/NotificationServiceProvider.php`
   - Method: `send()` (lines 12-82)

3. **Order Controller (Auto Notifications):**
   - File: `app/Http/Controllers/Api/Operation/OrderController.php`
   - Methods: Multiple methods with notification support

4. **User Controller (Auto Notifications):**
   - File: `app/Http/Controllers/Api/Operation/UserController.php`
   - Methods: `logoutUserDevice()`, `logoutAllUserDevices()`

5. **Configuration:**
   - File: `config/custom.php`
   - Variables: `onsignal_app_key`, `onsignal_api_key`

6. **Routes:**
   - File: `routes/api.php`
   - Route: Line 51 - `POST /api/push_notification/add`

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Maintained By:** Development Team

