import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Users Repository
/// Handles local DB operations and API sync for Users
/// Converted from KMP's UsersRepository.kt
class UsersRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  UsersRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all users with optional search key (includes category name)
  Future<Either<Failure, List<User>>> getAllUsers({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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

  /// Get user by code
  Future<Either<Failure, List<User>>> getUserByCode(String code) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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

  /// Get users by category ID
  Future<Either<Failure, List<User>>> getUsersByCategory(int categoryId) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
  Future<Either<Failure, void>> addUser(User user) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple users to local DB (transaction)
  Future<Either<Failure, void>> addUsers(List<UserDown> users) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final userDown in users) {
          // Skip google users
          if (userDown.code == 'google') continue;

          final user = User(
            id: userDown.id,
            name: userDown.name,
            code: userDown.code,
            phoneNo: userDown.phoneNo,
            catId: userDown.userCatId,
            address: userDown.address,
          );

          await txn.insert(
            'Users',
            user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
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
      final db = await _databaseHelper.database;
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
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update user flag
  Future<Either<Failure, void>> updateUserFlag({
    required int userId,
    required int flag,
  }) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
      await db.delete('Users');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync users from API (batch download)
  Future<Either<Failure, UserListApi>> syncUsersFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.usersDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
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
  Future<Either<Failure, User>> createUser(User user) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addUser,
        data: user.toJson(),
      );

      // 2. Parse response
      final userSuccessApi = UserSuccessApi.fromJson(response.data);
      if (userSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create user: ${userSuccessApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addUser(userSuccessApi.user);
      if (addResult.isLeft) {
        return addResult.map((_) => userSuccessApi.user);
      }

      return Right(userSuccessApi.user);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update user via API and update local DB
  Future<Either<Failure, User>> updateUser({
    required int userId,
    required String code,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      // 1. Call API
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

      // 2. Parse response
      final userSuccessApi = UserSuccessApi.fromJson(response.data);
      if (userSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update user: ${userSuccessApi.message}',
        ));
      }

      // 3. Store in local DB
      final updateResult = await updateUserLocal(
        userId: userSuccessApi.user.id,
        code: userSuccessApi.user.code,
        name: userSuccessApi.user.name,
        phone: userSuccessApi.user.phoneNo,
        address: userSuccessApi.user.address,
      );
      if (updateResult.isLeft) {
        return updateResult.map((_) => userSuccessApi.user);
      }

      return Right(userSuccessApi.user);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

