import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/car_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Car Version Repository
/// Handles local DB operations and API sync for Car Versions
/// Converted from KMP's CarVersionRepository.kt
class CarVersionRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  CarVersionRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all car versions by brand ID, name ID, and model ID
  Future<Either<Failure, List<Version>>> getAllCarVersions({
    required int brandId,
    required int nameId,
    required int modelId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarVersion',
        where: 'flag = 1 AND carBrandId = ? AND carNameId = ? AND carModelId = ?',
        whereArgs: [brandId, nameId, modelId],
        orderBy: 'name ASC',
      );

      final carVersions = maps.map((map) => Version.fromMap(map)).toList();
      return Right(carVersions);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get car version by name, brand ID, name ID, and model ID
  Future<Either<Failure, List<Version>>> getCarVersionByName({
    required String name,
    required int brandId,
    required int nameId,
    required int modelId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarVersion',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND carBrandId = ? AND carNameId = ? AND carModelId = ?',
        whereArgs: [name, brandId, nameId, modelId],
        orderBy: 'id ASC',
      );

      final carVersions = maps.map((map) => Version.fromMap(map)).toList();
      return Right(carVersions);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted car version
  Future<Either<Failure, Version?>> getLastEntry() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarVersion',
        orderBy: 'carVersionId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final carVersion = Version.fromMap(maps.first);
      return Right(carVersion);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single car version to local DB
  Future<Either<Failure, void>> addCarVersion(Version carVersion) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'CarVersion',
        carVersion.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car versions to local DB (transaction)
  Future<Either<Failure, void>> addCarVersions(List<Version> carVersions) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final carVersion in carVersions) {
          await txn.insert(
            'CarVersion',
            carVersion.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update car version in local DB
  Future<Either<Failure, void>> updateCarVersionLocal({
    required int carVersionId,
    required String name,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'CarVersion',
        {'name': name},
        where: 'carVersionId = ?',
        whereArgs: [carVersionId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all car versions from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('CarVersion');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync car versions from API (batch download)
  Future<Either<Failure, CarVersionListApi>> syncCarVersionsFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.carVersionDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final carVersionListApi = CarVersionListApi.fromJson(response.data);
      return Right(carVersionListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

