import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Categories Repository
/// Handles local DB operations and API sync for Categories
/// Converted from KMP's CategoryRepository.kt
class CategoriesRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  CategoriesRepository({
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

  /// Get all categories with optional search key
  Future<Either<Failure, List<Category>>> getAllCategories({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Category',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.query(
          'Category',
          where: 'flag = 1 AND LOWER(name) LIKE LOWER(?)',
          whereArgs: [searchPattern],
          orderBy: 'name ASC',
        );
      }

      final categories = maps.map((map) => Category.fromMap(map)).toList();
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get category by ID
  Future<Either<Failure, Category?>> getCategoryById(int categoryId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Category',
        where: 'flag = 1 AND categoryId = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC',
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final category = Category.fromMap(maps.first);
      return Right(category);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get category by name
  Future<Either<Failure, List<Category>>> getCategoryByName(String name) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Category',
        where: 'flag = 1 AND LOWER(name) = LOWER(?)',
        whereArgs: [name],
        orderBy: 'name ASC',
      );

      final categories = maps.map((map) => Category.fromMap(map)).toList();
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get category by name excluding specific category ID
  Future<Either<Failure, List<Category>>> getCategoryByNameWithId({
    required String name,
    required int categoryId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Category',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND categoryId != ?',
        whereArgs: [name, categoryId],
        orderBy: 'name ASC',
      );

      final categories = maps.map((map) => Category.fromMap(map)).toList();
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted category
  Future<Either<Failure, Category?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Category',
        orderBy: 'categoryId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final category = Category.fromMap(maps.first);
      return Right(category);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single category to local DB
  Future<Either<Failure, void>> addCategory(Category category) async {
    try {
      final db = await _database;
      
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO Category (
          categoryId, name, remark, flag
        ) VALUES (
          ?, ?, ?, ?
        )
        ''',
        [
          category.categoryId,
          category.name,
          category.remark ?? '',
          1, // flag (default 1)
        ],
      );
      
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple categories to local DB (transaction)
  Future<Either<Failure, void>> addCategories(List<Category> categories) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final category in categories) {
          // Use INSERT OR REPLACE (matches KMP pattern)
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO Category (
              categoryId, name, remark, flag
            ) VALUES (
              ?, ?, ?, ?
            )
            ''',
            [
              category.categoryId,
              category.name,
              category.remark ?? '',
               1,
            ],
          );
        }
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update category in local DB
  Future<Either<Failure, void>> updateCategoryLocal(Category category) async {
    try {
      final db = await _database;
      await db.update(
        'Category',
        {
          'name': category.name,
          'remark': category.remark,
        },
        where: 'categoryId = ?',
        whereArgs: [category.categoryId], // Use server ID, not local id
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all categories from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('Category');
       
      return const Right(null);
    } catch (e) {
       
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync categories from API (batch download or single record retry)
  /// Converted from KMP's downloadCategory function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all categories in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific category by id only
  Future<Either<Failure, CategoryListApi>> syncCategoriesFromApi({
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
        ApiEndpoints.categoryDownloads,
        queryParameters: queryParams,
      );

      final categoryListApi = CategoryListApi.fromJson(response.data);
      return Right(categoryListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create category via API and update local DB
  Future<Either<Failure, Category>> createCategory({
    required String name,
    String remark = '',
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addCategory,
        data: {
          'name': name,
          'remark': remark,
        },
      );

      // 2. Parse response
      final categoryApi = CategoryApi.fromJson(response.data);
      if (categoryApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create category: ${categoryApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addCategory(categoryApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => categoryApi.data);
      }

      return Right(categoryApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update category via API and update local DB
  Future<Either<Failure, Category>> updateCategory({
    required int categoryId,
    required String name,
  }) async {
    try {
      // 1. Get existing category from local DB (to preserve other fields like remark)
      final existingCategoryResult = await getCategoryById(categoryId);
      Category? existingCategory;
      existingCategoryResult.fold(
        (_) {},
        (cat) => existingCategory = cat,
      );

      // Build base category with NEW values overlaid on existing fields
      final baseCategory = Category(
        id: existingCategory?.id ?? -1,
        categoryId: existingCategory?.categoryId ?? categoryId,
        name: name,
        remark: existingCategory?.remark ?? '',
      );

      // 2. Call API
      final response = await _dio.post(
        ApiEndpoints.updateCategory,
        data: {
          'id': categoryId,
          'name': name,
        },
      );

      // 3. Parse response with merge support (handles partial responses)
      final categoryApi = CategoryApi.fromJsonWithMerge(
        response.data,
        existingCategory: baseCategory,
      );
      if (categoryApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update category: ${categoryApi.message}',
        ));
      }

      // 4. Store in local DB
      final updateResult = await updateCategoryLocal(categoryApi.data);
      if (updateResult.isLeft) {
        return updateResult.map((_) => categoryApi.data);
      }

      return Right(categoryApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

