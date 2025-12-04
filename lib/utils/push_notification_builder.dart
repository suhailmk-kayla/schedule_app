import 'dart:developer' as developer;
import '../repositories/users/users_repository.dart';
import '../utils/storage_helper.dart';

/// Push Notification User List Builder
/// Provides helper methods to build user lists for push notifications
/// Each data type has different targeting rules (matching KMP pattern)
/// 
/// In KMP, each ViewModel has its own sentPushNotification method with specific logic:
/// - Products: Only admins
/// - Customers: Exclude suppliers (catId != 4) AND salesmen (catId != 3), add salesman if admin
/// - Routes: Exclude only suppliers (catId != 4)
/// - Users: Exclude only suppliers (catId != 4)
/// - Orders: Complex logic based on order state (admins, storekeepers, checkers, billers)
class PushNotificationBuilder {
  final UsersRepository _usersRepository;

  PushNotificationBuilder({
    required UsersRepository usersRepository,
  }) : _usersRepository = usersRepository;

  /// Build user list for Product notifications
  /// Matches KMP's ProductViewModel.sentPushNotification (line 599-607)
  /// Targets: All admins (all users, no category filter)
  Future<List<Map<String, dynamic>>> buildProductNotificationList() async {
    final List<Map<String, dynamic>> userIds = [];
    final currentUserId = await StorageHelper.getUserId();

    final usersResult = await _usersRepository.getAllUsers();
    usersResult.fold(
      (failure) {
        developer.log('PushNotificationBuilder: Failed to get users: ${failure.message}');
      },
      (users) {
        for (final user in users) {
          if (user.userId != currentUserId) {
            userIds.add({
              'user_id': user.userId ?? -1,
              'silent_push': 1,
            });
          }
        }
      },
    );

    return userIds;
  }

  /// Build user list for Customer notifications
  /// Matches KMP's CustomersViewModel.sentPushNotification (lines 127-136, 166-176, 197-206)
  /// Targets: Exclude suppliers (catId != 4) AND salesmen (catId != 3)
  ///          If userType is 1 (admin), add salesman with silent_push = 0
  ///          If oldSalesmanId provided, add it with silent_push = 0
  Future<List<Map<String, dynamic>>> buildCustomerNotificationList({
    required int currentUserId,
    required int userType,
    int salesmanId = -1,
    int oldSalesmanId = -1,
  }) async {
    final List<Map<String, dynamic>> userIds = [];

    final usersResult = await _usersRepository.getAllUsers();
    usersResult.fold(
      (failure) {
        developer.log('PushNotificationBuilder: Failed to get users: ${failure.message}');
      },
      (users) {
        for (final user in users) {
          // Exclude current user
          if (user.userId == currentUserId) {
            continue;
          }

          // Exclude suppliers (categoryId != 4) AND salesmen (categoryId != 3)
          // Matches KMP: if (it.users.categoryId!=4L&&it.users.categoryId!=3L)
          if (user.catId == 4 || user.catId == 3) {
            continue;
          }

          userIds.add({
            'user_id': user.id,
            'silent_push': 1,
          });
        }
      },
    );

    // If userType is 1 (admin), add salesman to notification list with silent_push = 0
    // Matches KMP: if (userType==1) ids.add(PushUserData(salesmanId,0))
    if (userType == 1 && salesmanId != -1) {
      userIds.add({
        'user_id': salesmanId,
        'silent_push': 0,
      });
    }

    // Add old salesman ID if provided (for update operations)
    // Matches KMP: ids.add(PushUserData(oldSalesmanId,0))
    if (oldSalesmanId != -1) {
      userIds.add({
        'user_id': oldSalesmanId,
        'silent_push': 0,
      });
    }

    return userIds;
  }

  /// Build user list for Route notifications
  /// Matches KMP's CustomersViewModel.addRoute (lines 278-286)
  /// Targets: Exclude only suppliers (catId != 4), includes salesmen
  Future<List<Map<String, dynamic>>> buildRouteNotificationList() async {
    final List<Map<String, dynamic>> userIds = [];
    final currentUserId = await StorageHelper.getUserId();

    final usersResult = await _usersRepository.getAllUsers();
    usersResult.fold(
      (failure) {
        developer.log('PushNotificationBuilder: Failed to get users: ${failure.message}');
      },
      (users) {
        for (final user in users) {
          // Exclude current user
          if (user.userId == currentUserId) {
            continue;
          }

          // Exclude only suppliers (categoryId != 4)
          // Matches KMP: if (it.users.categoryId!=4L)
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

    return userIds;
  }

  /// Build user list for User notifications
  /// Matches KMP's UsersViewModel.sentPushNotification (lines 398-408)
  /// Targets: Exclude only suppliers (catId != 4), includes salesmen
  Future<List<Map<String, dynamic>>> buildUserNotificationList() async {
    final List<Map<String, dynamic>> userIds = [];
    final currentUserId = await StorageHelper.getUserId();

    final usersResult = await _usersRepository.getAllUsers();
    usersResult.fold(
      (failure) {
        developer.log('PushNotificationBuilder: Failed to get users: ${failure.message}');
      },
      (users) {
        for (final user in users) {
          // Exclude current user
          if (user.userId == currentUserId) {
            continue;
          }

          // Exclude only suppliers (categoryId != 4)
          // Matches KMP: if(it.users.categoryId!=4L)
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

    return userIds;
  }

  /// Build user list for Order notifications (complex logic)
  /// Matches KMP's OrderViewModel.sentPushNotification patterns
  /// Targets: Admins, storekeepers, checkers, billers based on order state
  Future<List<Map<String, dynamic>>> buildOrderNotificationList({
    required int currentUserId,
    int? checkerId,
    int? billerId,
    bool includeStorekeepers = true,
    bool includeCheckers = false,
    bool includeBillers = false,
  }) async {
    final List<Map<String, dynamic>> userIds = [];

    // Get admins
    final adminsResult = await _usersRepository.getUsersByCategory(1);
    adminsResult.fold(
      (failure) => developer.log('PushNotificationBuilder: Failed to get admins: ${failure.message}'),
      (admins) {
        for (final admin in admins) {
          if (admin.id != currentUserId) {
            userIds.add({
              'user_id': admin.id,
              'silent_push': 1,
            });
          }
        }
      },
    );

    // Get storekeepers
    if (includeStorekeepers) {
      final storekeepersResult = await _usersRepository.getUsersByCategory(2);
      storekeepersResult.fold(
        (failure) => developer.log('PushNotificationBuilder: Failed to get storekeepers: ${failure.message}'),
        (storekeepers) {
          for (final storekeeper in storekeepers) {
            userIds.add({
              'user_id': storekeeper.id,
              'silent_push': 0,
            });
          }
        },
      );
    }

    // Get checkers
    if (includeCheckers && checkerId != null && checkerId != -1) {
      final checkersResult = await _usersRepository.getUsersByCategory(6);
      checkersResult.fold(
        (failure) => developer.log('PushNotificationBuilder: Failed to get checkers: ${failure.message}'),
        (checkers) {
          for (final checker in checkers) {
            userIds.add({
              'user_id': checker.id,
              'silent_push': 0,
            });
          }
        },
      );
    }

    // Get billers
    if (includeBillers && billerId != null && billerId != -1) {
      final billersResult = await _usersRepository.getUsersByCategory(5);
      billersResult.fold(
        (failure) => developer.log('PushNotificationBuilder: Failed to get billers: ${failure.message}'),
        (billers) {
          for (final biller in billers) {
            userIds.add({
              'user_id': biller.id,
              'silent_push': 0,
            });
          }
        },
      );
    }

    return userIds;
  }

  /// Build custom user list with flexible filtering
  /// Use this for data types that don't fit the standard patterns
  Future<List<Map<String, dynamic>>> buildCustomNotificationList({
    required int currentUserId,
    List<int>? excludeCategoryIds,
    List<int>? includeOnlyCategoryIds,
    List<int>? additionalUserIds,
    int silentPush = 1,
  }) async {
    final List<Map<String, dynamic>> userIds = [];

    final usersResult = await _usersRepository.getAllUsers();
    usersResult.fold(
      (failure) {
        developer.log('PushNotificationBuilder: Failed to get users: ${failure.message}');
      },
      (users) {
        for (final user in users) {
          // Exclude current user
          if (user.userId == currentUserId) {
            continue;
          }

          // Exclude by category IDs
          if (excludeCategoryIds != null && excludeCategoryIds.contains(user.catId)) {
            continue;
          }

          // Include only specific category IDs
          if (includeOnlyCategoryIds != null && !includeOnlyCategoryIds.contains(user.catId)) {
            continue;
          }

          userIds.add({
            'user_id': user.id,
            'silent_push': silentPush,
          });
        }
      },
    );

    // Add additional user IDs (e.g., specific salesmen)
    if (additionalUserIds != null) {
      for (final userId in additionalUserIds) {
        if (userId != currentUserId && userId != -1) {
          userIds.add({
            'user_id': userId,
            'silent_push': 0, // Usually non-silent for specific users
          });
        }
      }
    }

    return userIds;
  }
}

