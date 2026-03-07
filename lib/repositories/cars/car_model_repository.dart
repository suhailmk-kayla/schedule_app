import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/car_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Car Model Repository
/// Handles local DB operations and API sync for Car Models
/// Converted from KMP's CarModelRepository.kt
class CarModelRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  CarModelRepository({
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

  /// Get car models by brand ID and name ID
  Future<Either<Failure, List<Model>>> getCarModels({
    required int brandId,
    required int nameId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarModel',
        where: 'flag = 1 AND carBrandId = ? AND carNameId = ?',
        whereArgs: [brandId, nameId],
        orderBy: 'id ASC',
      );

      final carModels = maps.map((map) => Model.fromMap(map)).toList();
      return Right(carModels);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get car model by name, brand ID, and name ID
  Future<Either<Failure, List<Model>>> getCarModelByName({
    required String name,
    required int brandId,
    required int nameId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarModel',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND carBrandId = ? AND carNameId = ?',
        whereArgs: [name, brandId, nameId],
        orderBy: 'id ASC',
      );

      final carModels = maps.map((map) => Model.fromMap(map)).toList();
      return Right(carModels);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted car model
  Future<Either<Failure, Model?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'CarModel',
        orderBy: 'carModelId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final carModel = Model.fromMap(maps.first);
      return Right(carModel);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single car model to local DB
  Future<Either<Failure, void>> addCarModel(Model carModel) async {
    try {
      final db = await _database;
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO CarModel (
          carModelId, carBrandId, carNameId, name, flag
        ) VALUES (
          ?, ?, ?, ?, ?
        )
        ''',
        [
          carModel.carModelId,
          carModel.carBrandId,
          carModel.carNameId,
          carModel.modelName,
          carModel.flag ?? 1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car models to local DB (transaction)
  Future<Either<Failure, void>> addCarModels(List<Model> carModels) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final carModel in carModels) {
          // Use INSERT OR REPLACE (matches KMP pattern)
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO CarModel (
              carModelId, carBrandId, carNameId, name, flag
            ) VALUES (
              ?, ?, ?, ?, ?
            )
            ''',
            [
              carModel.carModelId,
              carModel.carBrandId,
              carModel.carNameId,
              carModel.modelName,
              carModel.flag ?? 1,
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

  /// Update car model in local DB
  Future<Either<Failure, void>> updateCarModelLocal({
    required int carModelId,
    required String name,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'CarModel',
        {'name': name},
        where: 'carModelId = ?',
        whereArgs: [carModelId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all car models from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('CarModel');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync car models from API (batch download)
  /// Sync car models from API (batch download or single record retry)
  /// Converted from KMP's downloadCarModel function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all car models in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific car model by id only
  Future<Either<Failure, CarModelListApi>> syncCarModelsFromApi({
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
        ApiEndpoints.carModelDownload,
        queryParameters: queryParams,
      );

      final carModelListApi = CarModelListApi.fromJson(response.data);
      return Right(carModelListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

