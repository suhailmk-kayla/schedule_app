import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/user_category_model.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// UserCategory Repository
/// Handles local DB operations and API sync for UserCategories
/// Converted from KMP's UserCategoryRepository.kt
class UserCategoryRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  UserCategoryRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;
  
  /// Get database instance (cached after first access)
  Future<Database> get _database async {
    if (_cachedDatabase != null) return _cachedDatabase!;
    _cachedDatabase = await _databaseHelper.database;
    return _cachedDatabase!;
  }

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all user categories with optional search key
  Future<Either<Failure, List<UserCategory>>> getAllUserCategories({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'UsersCategory',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.query(
          'UsersCategory',
          where: 'flag = 1 AND LOWER(name) LIKE LOWER(?)',
          whereArgs: [searchPattern],
          orderBy: 'name ASC',
        );
      }

      final categories = maps.map((map) => UserCategory.fromMap(map)).toList();
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted user category
  Future<Either<Failure, UserCategory?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'UsersCategory',
        orderBy: 'userCategoryId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final category = UserCategory.fromMap(maps.first);
      return Right(category);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single user category to local DB
  Future<Either<Failure, void>> addUserCategory(UserCategory category) async {
    try {
      final db = await _database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO UsersCategory (id, userCategoryId, name, permissionJson, flag)
        VALUES (NULL, ?, ?, ?, ?)
        ''',
        [
          category.id,
          category.name,
          category.permissionJson,
          category.flag,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple user categories to local DB (transaction)
  Future<Either<Failure, void>> addUserCategories(
    List<UserCategory> categories,
  ) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        const sql = '''
        INSERT OR REPLACE INTO UsersCategory (id, userCategoryId, name, permissionJson, flag)
        VALUES (NULL, ?, ?, ?, ?)
        ''';
        for (final category in categories) {
          await txn.rawInsert(
            sql,
            [
              category.id,
              category.name,
              category.permissionJson,
              category.flag,
            ],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync user categories from API (batch download)
  /// Sync user categories from API (batch download or single record retry)
  /// Converted from KMP's downloadUserCategory function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all user categories in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific user category by id only
  Future<Either<Failure, Map<String, dynamic>>> syncUserCategoriesFromApi({
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
      
      final response = await _dio.get(
        ApiEndpoints.userCategoryDownloads,
        queryParameters: queryParams,
      );
       
      return Right(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
       
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
       
      return Left(UnknownFailure.fromError(e));
    }
  }
}

