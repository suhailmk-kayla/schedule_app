import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/car_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Car Brand Repository
/// Handles local DB operations and API sync for Car Brands
/// Converted from KMP's CarsBrandRepository.kt
class CarBrandRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  CarBrandRepository({
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

  /// Get all car brands
  Future<Either<Failure, List<Brand>>> getAllCarBrands() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarBrand',
        where: 'flag = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      final brands = maps.map((map) => Brand.fromMap(map)).toList();
      return Right(brands);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get car brand by name
  Future<Either<Failure, List<Brand>>> getCarBrandByName(String name) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarBrand',
        where: 'flag = 1 AND LOWER(name) = LOWER(?)',
        whereArgs: [name],
        orderBy: 'id ASC',
      );

      final brands = maps.map((map) => Brand.fromMap(map)).toList();
      return Right(brands);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted car brand
  Future<Either<Failure, Brand?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarBrand',
        where: 'flag = 1',
        orderBy: 'carBrandId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final brand = Brand.fromMap(maps.first);
      return Right(brand);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single car brand to local DB
  Future<Either<Failure, void>> addCarBrand(Brand brand) async {
    try {
      final db = await _database;
      await db.insert(
        'CarBrand',
        brand.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car brands to local DB (transaction)
  /// Priority 1: Optimized batch insert (uses batch.commit instead of await in loop)
  Future<Either<Failure, void>> addCarBrands(List<Brand> brands) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final brand in brands) {
          batch.insert(
            'CarBrand',
            brand.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update car brand in local DB
  Future<Either<Failure, void>> updateCarBrandLocal({
    required int carBrandId,
    required String name,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'CarBrand',
        {'name': name},
        where: 'carBrandId = ?',
        whereArgs: [carBrandId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all car brands from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('CarBrand');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync car brands from API (batch download)
  /// Sync car brands from API (batch download)
  /// Parameters match KMP's params() function
  Future<Either<Failure, CarBrandListApi>> syncCarBrandsFromApi({
    required int partNo, // Changed from offset to partNo
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.carBrandDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final carBrandListApi = CarBrandListApi.fromJson(response.data);
      return Right(carBrandListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create car brand via API and update local DB
  Future<Either<Failure, Brand>> createCarBrand({
    required String brandName,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addCarBrand,
        data: {
          'brand_name': brandName,
        },
      );

      // 2. Parse response
      final carApi = CarApi.fromJson(response.data);
      if (carApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create car brand: ${carApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addCarBrand(carApi.carBrand);
      if (addResult.isLeft) {
        return addResult.map((_) => carApi.carBrand);
      }

      return Right(carApi.carBrand);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update car brand via API and update local DB
  Future<Either<Failure, Brand>> updateCarBrand({
    required int carBrandId,
    required String brandName,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateCarBrand,
        data: {
          'id': carBrandId,
          'brand_name': brandName,
        },
      );

      // 2. Parse response
      final carApi = CarApi.fromJson(response.data);
      if (carApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update car brand: ${carApi.message}',
        ));
      }

      // 3. Store in local DB
      final updateResult = await updateCarBrandLocal(
        carBrandId: carApi.carBrand.id,
        name: carApi.carBrand.brandName,
      );
      if (updateResult.isLeft) {
        return updateResult.map((_) => carApi.carBrand);
      }

      return Right(carApi.carBrand);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

