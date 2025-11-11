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

  CarModelRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get car models by brand ID and name ID
  Future<Either<Failure, List<Model>>> getCarModels({
    required int brandId,
    required int nameId,
  }) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
      await db.insert(
        'CarModel',
        carModel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car models to local DB (transaction)
  Future<Either<Failure, void>> addCarModels(List<Model> carModels) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final carModel in carModels) {
          await txn.insert(
            'CarModel',
            carModel.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
  Future<Either<Failure, CarModelListApi>> syncCarModelsFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.carModelDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
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

