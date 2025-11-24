import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// SubCategories Repository
/// Handles local DB operations and API sync for SubCategories
/// Converted from KMP's SubCategoryRepository.kt
class SubCategoriesRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  SubCategoriesRepository({
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

  /// Get all sub categories with optional search key (includes category name)
  Future<Either<Failure, List<SubCategory>>> getAllSubCategories({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT s.*, c.name AS categoryName
          FROM SubCategory AS s
          LEFT JOIN Category AS c ON c.categoryId = s.parentId
          WHERE s.flag = 1
          ORDER BY s.name ASC
          ''',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT s.*, c.name AS categoryName
          FROM SubCategory AS s
          LEFT JOIN Category AS c ON c.categoryId = s.parentId
          WHERE s.flag = 1 AND (
            LOWER(s.name) LIKE LOWER(?) OR 
            LOWER(c.name) LIKE LOWER(?)
          )
          ORDER BY s.name ASC
          ''',
          [searchPattern, searchPattern],
        );
      }

      final subCategories = maps.map((map) => SubCategory.fromMap(map)).toList();
      return Right(subCategories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all sub categories with category name (returns raw maps for categoryName extraction)
  Future<Either<Failure, List<Map<String, dynamic>>>> getAllSubCategoriesWithCategoryName({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT s.*, c.name AS categoryName
          FROM SubCategory AS s
          LEFT JOIN Category AS c ON c.categoryId = s.parentId
          WHERE s.flag = 1
          ORDER BY s.name ASC
          ''',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT s.*, c.name AS categoryName
          FROM SubCategory AS s
          LEFT JOIN Category AS c ON c.categoryId = s.parentId
          WHERE s.flag = 1 AND (
            LOWER(s.name) LIKE LOWER(?) OR 
            LOWER(c.name) LIKE LOWER(?)
          )
          ORDER BY s.name ASC
          ''',
          [searchPattern, searchPattern],
        );
      }

      return Right(maps);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get sub categories by parent category ID
  Future<Either<Failure, List<SubCategory>>> getSubCategoriesByCategoryId(
    int parentId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SubCategory',
        where: 'flag = 1 AND parentId = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC',
      );

      final subCategories = maps.map((map) => SubCategory.fromMap(map)).toList();
      return Right(subCategories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get sub category by name and parent ID
  Future<Either<Failure, List<SubCategory>>> getSubCategoryByName({
    required String name,
    required int parentId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SubCategory',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND parentId = ?',
        whereArgs: [name, parentId],
        orderBy: 'name ASC',
      );

      final subCategories = maps.map((map) => SubCategory.fromMap(map)).toList();
      return Right(subCategories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get sub category by name and parent ID excluding specific sub category ID
  Future<Either<Failure, List<SubCategory>>> getSubCategoryByNameAndId({
    required String name,
    required int parentId,
    required int subCategoryId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SubCategory',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND parentId = ? AND subCategoryId != ?',
        whereArgs: [name, parentId, subCategoryId],
        orderBy: 'name ASC',
      );

      final subCategories = maps.map((map) => SubCategory.fromMap(map)).toList();
      return Right(subCategories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted sub category
  Future<Either<Failure, SubCategory?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SubCategory',
        orderBy: 'subCategoryId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final subCategory = SubCategory.fromMap(maps.first);
      return Right(subCategory);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single sub category to local DB
  Future<Either<Failure, void>> addSubCategory(SubCategory subCategory) async {
    try {
      final db = await _database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO SubCategory (id, subCategoryId, parentId, name, remark, flag)
        VALUES (NULL, ?, ?, ?, ?, ?)
        ''',
        [
          subCategory.id,
          subCategory.catId,
          subCategory.name,
          subCategory.remark,
          1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple sub categories to local DB (transaction)
  Future<Either<Failure, void>> addSubCategories(
    List<SubCategory> subCategories,
  ) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        const sql = '''
        INSERT OR REPLACE INTO SubCategory (id, subCategoryId, parentId, name, remark, flag)
        VALUES (NULL, ?, ?, ?, ?, ?)
        ''';
        for (final subCategory in subCategories) {
          await txn.rawInsert(
            sql,
            [
              subCategory.id,
              subCategory.catId,
              subCategory.name,
              subCategory.remark,
              1,
            ],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update sub category in local DB
  Future<Either<Failure, void>> updateSubCategoryLocal({
    required int subCategoryId,
    required String name,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'SubCategory',
        {'name': name},
        where: 'subCategoryId = ?',
        whereArgs: [subCategoryId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all sub categories from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('SubCategory');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync sub categories from API (batch download or single record retry)
  /// Converted from KMP's downloadSubCategory function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all sub categories in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific sub category by id only
  Future<Either<Failure, SubCategoryListApi>> syncSubCategoriesFromApi({
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
        ApiEndpoints.subCategoryDownloads,
        queryParameters: queryParams,
      );

      final subCategoryListApi = SubCategoryListApi.fromJson(response.data);
      return Right(subCategoryListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create sub category via API and update local DB
  Future<Either<Failure, SubCategory>> createSubCategory({
    required String name,
    required int parentId,
    String remark = '',
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addSubCategory,
        data: {
          'name': name,
          'cat_id': parentId,
          'remark': remark,
        },
      );

      // 2. Parse response
      final subCategoryApi = SubCategoryApi.fromJson(response.data);
      if (subCategoryApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create sub category: ${subCategoryApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addSubCategory(subCategoryApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => subCategoryApi.data);
      }

      return Right(subCategoryApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update sub category via API and update local DB
  Future<Either<Failure, SubCategory>> updateSubCategory({
    required int subCategoryId,
    required int parentId,
    required String name,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateSubCategory,
        data: {
          'id': subCategoryId,
          'cat_id': parentId,
          'name': name,
        },
      );

      // 2. Parse response
      final subCategoryApi = SubCategoryApi.fromJson(response.data);
      if (subCategoryApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update sub category: ${subCategoryApi.message}',
        ));
      }

      // 3. Store in local DB
      final updateResult = await updateSubCategoryLocal(
        subCategoryId: subCategoryApi.data.id,
        name: subCategoryApi.data.name,
      );
      if (updateResult.isLeft) {
        return updateResult.map((_) => subCategoryApi.data);
      }

      return Right(subCategoryApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

