import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer' as developer;
import '../models/push_data.dart';
import '../repositories/users/users_repository.dart';
import '../utils/storage_helper.dart';
import '../utils/api_endpoints.dart';

/// Push Notification Sender
/// Handles sending push notifications to other users (excluding current user)
/// Converted from KMP's sentPushNotification pattern
class PushNotificationSender {
  final Dio _dio;

  PushNotificationSender({
    required Dio dio,
  }) : _dio = dio;

  /// Get UsersRepository lazily to avoid circular dependency
  UsersRepository get _usersRepository => GetIt.instance<UsersRepository>();

  /// Send push notification to all users except current user and suppliers
  /// Matches KMP's sentPushNotification pattern
  /// 
  /// [dataIds] - List of PushData objects containing table and id
  /// [message] - Optional message for the notification (default: "Data updates")
  /// [customUserIds] - Optional custom user list. If provided, uses this instead of auto-building
  Future<void> sendPushNotification({
    required List<PushData> dataIds,
    String message = 'Data updates',
    List<Map<String, dynamic>>? customUserIds,
  }) async {
    try {
      // 3. Build user IDs list
      final List<Map<String, dynamic>> userIds = [];

      if (customUserIds != null) {
        // Use custom user list if provided (for KMP-specific logic like excluding salesmen)
        userIds.addAll(customUserIds);
      } else {
        // Auto-build user list (default behavior)
        // 1. Get all users
        final usersResult = await _usersRepository.getAllUsers();

        // 2. Get current user ID
        final currentUserId = await StorageHelper.getUserId();

        usersResult.fold(
          (failure) {
            developer.log(
              'PushNotificationSender: Failed to get users: ${failure.message}',
            );
          },
          (users) {
            for (final user in users) {
              // Exclude current user (matches KMP line 404)
              if (user.id == currentUserId) {
                continue;
              }

              // Exclude suppliers (categoryId == 4) - matches KMP line 403
              if (user.catId == 4) {
                continue;
              }
             

              userIds.add({
                'user_id': user.id,
                'silent_push': 1,
              });
            }
          },
        );
      }

      // If no users to notify, skip sending
      if (userIds.isEmpty) {
        developer.log('PushNotificationSender: No users to notify (excluding current user and suppliers)');
        return;
      }

      // 4. Build data_ids array
      final dataIdsArray = dataIds.map((pushData) => pushData.toJson()).toList();

      // 5. Build notification payload (matches KMP structure)
      final params = {
        'ids': userIds,
        'data_message': message,
        'data': {
          'data_ids': dataIdsArray,
          'show_notification': 0, // Silent push
          'message': message,
        },
      };

      developer.log(
        'PushNotificationSender: Sending push notification to ${userIds.length} users',
      );
      developer.log('PushNotificationSender: Data IDs: $dataIdsArray');

      // 6. Send push notification (matches KMP's sendPush - just logs success/error)
      try {
        final response = await _dio.post(
          ApiEndpoints.pushNotification,
          data: params,
          options: Options(
            // Accept all status codes to avoid throwing on non-2xx responses
            validateStatus: (status) => true,
            // Don't try to parse response as JSON - server might return empty or non-JSON
            responseType: ResponseType.json,
            receiveTimeout: const Duration(seconds: 120), // Increase to 2 minutes
            sendTimeout: const Duration(seconds: 30), 
          ),
        );

        // Check if request was successful (status 200-299)
        if (response.statusCode != null && 
            response.statusCode! >= 200 && 
            response.statusCode! < 300) {
          developer.log(
            'PushNotificationSender: Push notification sent successfully (status: ${response.statusCode})',
          );
        } else {
          developer.log(
            'PushNotificationSender: Push notification failed (status: ${response.statusCode})',
          );
          // Log response data if available (might be error message)
          if (response.data != null && response.data.toString().isNotEmpty) {
            developer.log('PushNotificationSender: Response: ${response.data}');
          }
        }
      } on DioException catch (e) {
        // Handle Dio-specific errors (network, timeout, etc.)
        developer.log(
          'PushNotificationSender: DioException sending push notification: ${e.message}',
          error: e,
        );
        if (e.response != null) {
          developer.log(
            'PushNotificationSender: Response status: ${e.response?.statusCode}',
          );
          if (e.response?.data != null) {
            developer.log('PushNotificationSender: Response data: ${e.response?.data}');
          }
        }
        // Don't throw - push notification failure shouldn't break the main operation
      } catch (e, stackTrace) {
        developer.log(
          'PushNotificationSender: Error sending push notification: $e',
          error: e,
          stackTrace: stackTrace,
        );
        // Don't throw - push notification failure shouldn't break the main operation
      }
    } catch (e, stackTrace) {
      developer.log(
        'PushNotificationSender: Error in sendPushNotification: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't throw - push notification failure shouldn't break the main operation
    }
  }
}

