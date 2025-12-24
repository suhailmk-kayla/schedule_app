import 'dart:developer' as developer;
import 'package:intl/intl.dart';

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/push_notification_sender.dart';
import '../../models/push_data.dart';
import '../../utils/notification_id.dart';
import '../salesman/salesman_repository.dart';
import '../suppliers/suppliers_repository.dart';
import '../../models/salesman_model.dart';
import '../../models/supplier_model.dart';

/// Users Repository
/// Handles local DB operations and API sync for Users
/// Converted from KMP's UsersRepository.kt
class UsersRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  final PushNotificationSender? _pushNotificationSender;
  final SalesManRepository? _salesManRepository;
  final SuppliersRepository? _suppliersRepository;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  UsersRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
    PushNotificationSender? pushNotificationSender,
    SalesManRepository? salesManRepository,
    SuppliersRepository? suppliersRepository,
  })  : _databaseHelper = databaseHelper,
        _dio = dio,
        _pushNotificationSender = pushNotificationSender,
        _salesManRepository = salesManRepository,
        _suppliersRepository = suppliersRepository;
  
  /// Get database instance (cached after first access)
  Future<Database> get _database async {
    if (_cachedDatabase != null) return _cachedDatabase!;
    _cachedDatabase = await _databaseHelper.database;
    return _cachedDatabase!;
  }

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all users with optional search key (includes category name)
  Future<Either<Failure, List<User>>> getAllUsers({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT u.*, uc.name AS categoryName
          FROM Users AS u
          LEFT JOIN UsersCategory AS uc ON uc.userCategoryId = u.categoryId
          WHERE u.flag = 1
          ORDER BY u.name ASC
          ''',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT u.*, uc.name AS categoryName
          FROM Users AS u
          LEFT JOIN UsersCategory AS uc ON uc.userCategoryId = u.categoryId
          WHERE u.flag = 1 AND (
            LOWER(u.name) LIKE LOWER(?) OR 
            LOWER(u.code) LIKE LOWER(?)
          )
          ORDER BY u.name ASC
          ''',
          [searchPattern, searchPattern],
        );
      }

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by ID (includes category name)
  Future<Either<Failure, User?>> getUserById(int userId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT u.*, uc.name AS categoryName
        FROM Users AS u
        LEFT JOIN UsersCategory AS uc ON uc.userCategoryId = u.categoryId
        WHERE u.flag = 1 AND u.userId = ?
        ORDER BY u.name ASC
        LIMIT 1
        ''',
        [userId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final user = User.fromMap(maps.first);
      return Right(user);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by ID with category name (returns raw map for categoryName extraction)
  Future<Either<Failure, Map<String, dynamic>?>> getUserByIdWithCategoryName(
    int userId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT u.*, uc.name AS categoryName
        FROM Users AS u
        LEFT JOIN UsersCategory AS uc ON uc.userCategoryId = u.categoryId
        WHERE u.flag = 1 AND u.userId = ?
        ORDER BY u.name ASC
        LIMIT 1
        ''',
        [userId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      return Right(maps.first);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by code
  Future<Either<Failure, List<User>>> getUserByCode(String code) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND code = ?',
        whereArgs: [code],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by code excluding specific user ID
  Future<Either<Failure, List<User>>> getUserByCodeWithId({
    required String code,
    required int userId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND code = ? AND userId != ?',
        whereArgs: [code, userId],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by phone number
  Future<Either<Failure, List<User>>> getUserByPhone(String phone) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND phone = ? AND categoryId = ?',
        whereArgs: [phone,3],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get salesman by phone number (categoryId = 3)
  Future<Either<Failure, List<User>>> getSalesmanByPhone(String phone) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND phone = ? AND categoryId = ?',
        whereArgs: [phone, 3],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get user by phone number excluding specific user ID
  Future<Either<Failure, List<User>>> getUserByPhoneWithId({
    required String phone,
    required int userId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND phone = ? AND userId != ?',
        whereArgs: [phone, userId],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get salesman by phone number excluding specific user ID (categoryId = 3)
  Future<Either<Failure, List<User>>> getSalesmanByPhoneWithId({
    required String phone,
    required int userId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND phone = ? AND categoryId = ? AND userId != ?',
        whereArgs: [phone, 3, userId],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get users by category ID
  Future<Either<Failure, List<User>>> getUsersByCategory(int categoryId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1 AND categoryId = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC',
      );

      final users = maps.map((map) => User.fromMap(map)).toList();
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted user
  Future<Either<Failure, User?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Users',
        where: 'flag = 1',
        orderBy: 'userId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final user = User.fromMap(maps.first);
      return Right(user);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single user to local DB
  /// CRITICAL: Handles create vs update correctly:
  /// - When creating (user doesn't exist): id = NULL (auto-increment)
  /// - When updating (user exists): preserves existing local id
  Future<Either<Failure, void>> addUser(User user) async {
    try {
      final db = await _database;
      
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO Users (
          userId,
          code,
          name,
          phone,
          address,
          categoryId,
          password,
          createdDateTime,
          updatedDateTime,
          deviceToken,
          multiDeviceLogin,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          user.userId ?? -1, // userId (from API)
          user.code,
          user.name,
          user.phoneNo,
          user.address,
          user.catId,
          '',
          '',
          '',
          '',
          0,
          1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple users to local DB (transaction)
  Future<Either<Failure, void>> addUsers(List<UserDown> users) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final userDown in users) {
          if (userDown.code == 'google') continue;
          // Use INSERT OR REPLACE (matches KMP pattern)
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO Users (
              userId, code, name, phone, address, categoryId, password, 
              createdDateTime, updatedDateTime, deviceToken, multiDeviceLogin, flag
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              userDown.userId,
              userDown.code,
              userDown.name,
              userDown.phoneNo,
              userDown.address,
              userDown.userCatId,
              '', // password
              userDown.createdAt ?? '',
              userDown.updatedAt ?? '',
              '', // deviceToken
              0, // multiDeviceLogin
              userDown.flag ?? 1,
            ],
          );
        }
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      developer.log('addUsers error: $e');
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update user in local DB
  Future<Either<Failure, void>> updateUserLocal({
    required int userId,
    required String code,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Users',
        {
          'code': code,
          'name': name,
          'phone': phone,
          'address': address,
        },
        where: 'userId = ?',
        whereArgs: [userId],
      );
      return const Right(null);
    } catch (e) {
      developer.log('updateUserLocal error: $e');
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update user flag
  Future<Either<Failure, void>> updateUserFlag({
    required int userId,
    required int flag,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Users',
        {'flag': flag},
        where: 'userId = ?',
        whereArgs: [userId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all users from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('Users');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync users from API (batch download or single record retry)
  /// Converted from KMP's downloadUser function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all users in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific user by id only
  Future<Either<Failure, UserListApi>> syncUsersFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
    int id = -1, // -1 for full sync, specific id for retry
  }) async {
    try {
      final Map<String, String> queryParams;
      
      if (id == -1) {
        // Full sync mode: send all parameters (matches KMP's params function when id == -1)
        queryParams = {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        };
      } else {
        // Single record retry mode: send only id (matches KMP's params function when id != -1)
        queryParams = {
          'id': id.toString(),
        };
      }
      
      final response= await _dio.get(
        ApiEndpoints.usersDownload,
        queryParameters: queryParams,
      );

      final userListApi = UserListApi.fromJson(response.data);
      return Right(userListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create user via API and update local DB
  /// Converted from KMP's saveUser method
  Future<Either<Failure, User>> createUser({
    required String code,
    required String name,
    required String phone,
    required int categoryId,
    required String address,
    required String password,
  }) async {
    try {
      // 1. Check if code already exists
      final codeCheckResult = await getUserByCode(code);
      codeCheckResult.fold(
        (_) {},
        (users) {
          if (users.isNotEmpty) {
            throw Exception('The code already used');
          }
        },
      );

      // 2. Call API (using register endpoint as in KMP)
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'cat_id': categoryId,
          'code': code,
          'name': name,
          'phone_no': phone.isEmpty ? '0' : phone,
          'address': address,
          'password': password,
          'confirm_password': password,
        },
      );

      // 3. Parse response
      final status = response.data['status'] as int? ?? 2;
      if (status != 1) {
        final message = response.data['data']?.toString() ?? 'Failed to create user';
        return Left(ServerFailure.fromError(message));
      }

      final userSuccessApi = UserSuccessApi.fromJson(response.data);
      final createdUser = userSuccessApi.user;

      // 4. Store in local DB
      await addUser(createdUser);

      // 5. Build push notification data IDs
      final dataIds = <PushData>[
        PushData(table: NotificationId.user, id: createdUser.userId ?? -1),
      ];

      // 6. Handle SalesMan and Supplier creation if categoryId is 3 or 4
      // Matches KMP's pattern (lines 291-311)
      if (categoryId == 3 || categoryId == 4) {
        final userData = userSuccessApi.userData;
        if (userData != null) {
          final now = _getDBFormatDateTime();
          
          if (categoryId == 3) {
            // Create SalesMan
            final newSalesMan = SalesMan(
              salesManId: userData.id,
              id: -1, // Auto-increment primary key
              userId: createdUser.userId ?? -1,
              code: userData.code,
              name: userData.name,
              phone: userData.phoneNo,
              address: userData.address,
              deviceToken: '',
              createdDateTime: now,
              updatedDateTime: now,
              flag: 1,
            );
            
            // Add SalesMan to local DB
            if (_salesManRepository != null) {
              await _salesManRepository.addSalesMan(newSalesMan);
            }
            
            // Add SalesMan to push notification
            dataIds.add(PushData(table: NotificationId.salesman, id: userData.id));
          } else if (categoryId == 4) {
            // Create Supplier
            // userData.id is the supplierId (business ID from server)
            // createdUser.userId is the userId (links to Users table)
            final newSupplier = Supplier(
              id: userData.id, // supplierId from server (e.g., 29)
              userId: createdUser.userId, // userId from server (e.g., 134)
              code: userData.code,
              name: userData.name,
              phone: userData.phoneNo,
              address: userData.address,
              deviceToken: '',
              createdDateTime: now,
              updatedDateTime: now,
              flag: 1,
            );
            
            // Add Supplier to local DB
            if (_suppliersRepository != null) {
              await _suppliersRepository.addSupplier(newSupplier);
            }
            
            // Add Supplier to push notification
            dataIds.add(PushData(table: NotificationId.supplier, id: userData.id));
          }
        }
      }

      // 7. Send push notification to other users (excluding current user)
      // Matches KMP's sentPushNotification call (line 312)
      // Fire-and-forget: don't await, just trigger in background
      if (_pushNotificationSender != null) {
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'User updates',
        ).catchError((e) {
          developer.log('UsersRepository: Error sending push notification: $e');
        });
      } else {
        developer.log('UsersRepository: PushNotificationSender not available, skipping push notification');
      }

      return Right(createdUser);
    } on DioException catch (e) {
      developer.log('createUser DioException: $e');

      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      developer.log('createUser error: $e');
      if (e.toString().contains('Code already Exist')) {
        return Left(ValidationFailure.fromError('Code already Exist'));
      }
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update user via API and update local DB
  /// for every update the backend updates two tables:users table and the paricular table according to their role
  /// so we need to update the local db for both the tables
  /// Uses custom deserialization to merge partial API response with existing data
  Future<Either<Failure, User>> updateUser({
    required int userId,
    required String code,
    required String name,
    required String phone,
    required String address,
    required int categoryId,
  }) async {
    try {
      // 1. Get existing user from local DB to preserve unchanged fields
      final existingUserResult = await getUserById(userId);
      User? existingUser;
      existingUserResult.fold(
        (_) {},
        (user) => existingUser = user,
      );

      // Build a base user using the NEW values provided by the caller,
      // overlaid on the existing user's other fields (id, userId).
      final baseUser = User(
        id: existingUser?.id ?? -1,
        userId: existingUser?.userId ?? userId,
        code: code,
        name: name,
        phoneNo: phone,
        address: address,
        catId: categoryId,
      );

      // 2. Call API
      final response = await _dio.post(
        ApiEndpoints.updateUser,
        data: {
          'id': userId,
          'code': code,
          'name': name,
          'phone_no': phone,
          'address': address,
        },
      );

      // 3. Parse response with merge support for partial updates
      final userSuccessApi = UserSuccessApi.fromJsonWithMerge(
        response.data,
        existingUser: baseUser,
      );
      if (userSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update user: ${userSuccessApi.message}',
        ));
      }

      // 4. Build push notification data IDs
      final dataIds = <PushData>[
        PushData(table: NotificationId.user, id: userId),
      ];

      // 5. Store in local DB with merged data
      final updateResult = await updateUserLocal(
        userId: userSuccessApi.user.userId ?? -1,
        code: userSuccessApi.user.code,
        name: userSuccessApi.user.name,
        phone: userSuccessApi.user.phoneNo,
        address: userSuccessApi.user.address,
      );
      if (updateResult.isLeft) {
        return updateResult.map((_) => userSuccessApi.user);
      }

      // 6. If salesman (categoryId == 3), update salesman table
      // Check response.data for second_id (salesManId)
      // Use merged values from API response
      if (categoryId == 3 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;
        if (data != null) {
          final salesManId = data['second_id'] as int?;
          if (salesManId != null && salesManId != -1 && _salesManRepository != null) {
            // Update salesman table with merged values from API response
            await _salesManRepository.updateSalesManLocal(
              salesManId: salesManId,
              code: userSuccessApi.user.code,
              name: userSuccessApi.user.name,
              phone: userSuccessApi.user.phoneNo,
              address: userSuccessApi.user.address,
            );
            // Add SalesMan to push notification
            dataIds.add(PushData(table: NotificationId.salesman, id: salesManId));
          }
        }
      }

      // 7. If supplier (categoryId == 4), update supplier table
      // Check response.data for second_id (supplierId)
      // Use merged values from API response
      if (categoryId == 4 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;
        if (data != null) {
          final supplierId = data['second_id'] as int?;
          if (supplierId != null && supplierId != -1 && _suppliersRepository != null) {
            // Update supplier table with merged values from API response
            await _suppliersRepository.updateSupplierLocal(
              supplierId: supplierId,
              code: userSuccessApi.user.code,
              name: userSuccessApi.user.name,
              phone: userSuccessApi.user.phoneNo,
              address: userSuccessApi.user.address,
            );
            // Add Supplier to push notification
            dataIds.add(PushData(table: NotificationId.supplier, id: supplierId));
          }
        }
      }

      // 8. Send push notification to other users
      // Matches KMP's sentPushNotification call (line 360 in UsersViewModel.kt)
      // Fire-and-forget: don't await, just trigger in background
      if (_pushNotificationSender != null) {
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'User updates',
        ).catchError((e) {
          developer.log('UsersRepository: Error sending push notification: $e');
        });
      }

      return Right(userSuccessApi.user);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Change user password via API
  Future<Either<Failure, void>> changeUserPassword({
    required int userId,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.changePassword,
        data: {
          'id': userId,
          'password': password,
          'confirm_password': confirmPassword,
        },
      );

      final status = response.data['status'] as int? ?? 2;
      if (status != 1) {
        final message = response.data['data']?.toString() ?? 'Failed to change password';
        return Left(ServerFailure.fromError(message));
      }

      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Logout user from all devices via API
  Future<Either<Failure, void>> logoutFromDevices({
    required int userId,
  }) async {
    try {
      final notificationPayload = _buildLogoutNotificationPayloadForUser(userId);
      final response = await _dio.post(
        ApiEndpoints.logoutUserDevice,
        data: {
          'id': userId,
          'notification': notificationPayload,
        },
      );

      final status = response.data['status'] as int? ?? 2;
      if (status != 1) {
        final message = response.data['data']?.toString() ?? 'Failed to logout devices';
        return Left(ServerFailure.fromError(message));
      }

      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  Map<String, dynamic> _buildLogoutNotificationPayloadForUser(int userId) {
    return {
      'ids': [
        {
          'user_id': userId,
          'silent_push': 0,
        },
      ],
      'data_message': 'Logout device',
      'data': {
        'data_ids': [
          {
            'table': NotificationId.logout,
            'id': 0,
          },
        ],
        'show_notification': '0',
        'message': 'Logout device',
      },
    };
  }

  /// Logout all users from all devices via API (admin-only)
  Future<Either<Failure, void>> logoutAllUsersFromDevices({
    required int currentUserId,
    required Map<String, dynamic> notificationPayload,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.logoutAllUserDevice,
        data: {
          'id': currentUserId,
          'notification': notificationPayload,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final status = map['status']?.toString() ?? '2';
        if (status == '1') {
          return const Right(null);
        }
        final message = map['data']?.toString() ??
            map['message']?.toString() ??
            'Failed to logout all devices';
        return Left(ServerFailure.fromError(message));
      }

      return Left(ServerFailure.fromError('Invalid response from server'));
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Delete user via API and update local DB
  /// Matches KMP's deleteUser method (lines 188-220)
  /// Updates Users table flag and role-specific table flags (SalesMan/Supplier)
  Future<Either<Failure, void>> deleteUser({
    required int userId,
    required int categoryId,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.deleteUser,
        data: {
          'id': userId,
        },
      );

      final status = response.data['status'] as int? ?? 2;
      if (status != 1) {
        final message = response.data['data']?.toString() ?? 'Failed to delete user';
        return Left(ServerFailure.fromError(message));
      }

      // 2. Build push notification data IDs
      final dataIds = <PushData>[
        PushData(table: NotificationId.user, id: userId),
      ];

      // 3. Update Users table flag
      await updateUserFlag(userId: userId, flag: 0);

      // 4. If SalesMan (categoryId == 3), update SalesMan table flag
      // Check response.data for second_id (salesManId)
      if (categoryId == 3 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;
        if (data != null) {
          final salesManId = data['second_id'] as int?;
          if (salesManId != null && salesManId != -1 && _salesManRepository != null) {
            // Update SalesMan flag to 0 (deleted)
            await _salesManRepository.updateSalesManFlag(
              salesManId: salesManId,
              flag: 0,
            );
            // Add SalesMan to push notification
            dataIds.add(PushData(table: NotificationId.salesman, id: salesManId));
          }
        }
      }

      // 5. If Supplier (categoryId == 4), update Supplier table flag
      // Check response.data for second_id (supplierId)
      if (categoryId == 4 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;
        if (data != null) {
          final supplierId = data['second_id'] as int?;
          if (supplierId != null && supplierId != -1 && _suppliersRepository != null) {
            // Update Supplier flag to 0 (deleted)
            await _suppliersRepository.updateSupplierFlag(
              supplierId: supplierId,
              flag: 0,
            );
            // Add Supplier to push notification
            dataIds.add(PushData(table: NotificationId.supplier, id: supplierId));
          }
        }
      }

      // 6. Send push notification to other users
      // Matches KMP's sentPushNotification call (line 216)
      // Fire-and-forget: don't await, just trigger in background
      if (_pushNotificationSender != null) {
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'User deleted',
        ).catchError((e) {
          developer.log('UsersRepository: Error sending push notification: $e');
        });
      }

      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Check if user is active via API
  Future<Either<Failure, bool>> checkUserActive({
    required int userId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkUserActive,
        data: {
          'id': userId,
        },
      );

      final status = response.data['status'] as int? ?? 2;
      if (status != 1) {
        return const Right(false);
      }

      return const Right(true);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Get current date-time in database format (YYYY-MM-DD HH:mm:ss)
  /// Converted from KMP's getDBFormatDateTime()
  String _getDBFormatDateTime() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }
}

