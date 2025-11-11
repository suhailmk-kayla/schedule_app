import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/car_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Car Name Repository
/// Handles local DB operations and API sync for Car Names
/// Converted from KMP's CarNameRepository.kt
class CarNameRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  CarNameRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all car names by brand ID
  Future<Either<Failure, List<Name>>> getCarNamesByBrandId(int brandId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarName',
        where: 'flag = 1 AND carBrandId = ?',
        whereArgs: [brandId],
        orderBy: 'name ASC',
      );

      final carNames = maps.map((map) => Name.fromMap(map)).toList();
      return Right(carNames);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get car name by name and brand ID
  Future<Either<Failure, List<Name>>> getCarNameByName({
    required String name,
    required int brandId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarName',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND carBrandId = ?',
        whereArgs: [name, brandId],
        orderBy: 'id ASC',
      );

      final carNames = maps.map((map) => Name.fromMap(map)).toList();
      return Right(carNames);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted car name
  Future<Either<Failure, Name?>> getLastEntry() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'CarName',
        orderBy: 'carNameId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final carName = Name.fromMap(maps.first);
      return Right(carName);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single car name to local DB
  Future<Either<Failure, void>> addCarName(Name carName) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'CarName',
        carName.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car names to local DB (transaction)
  Future<Either<Failure, void>> addCarNames(List<Name> carNames) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final carName in carNames) {
          await txn.insert(
            'CarName',
            carName.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update car name in local DB
  Future<Either<Failure, void>> updateCarNameLocal({
    required int carNameId,
    required String name,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'CarName',
        {'name': name},
        where: 'carNameId = ?',
        whereArgs: [carNameId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all car names from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('CarName');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync car names from API (batch download)
  Future<Either<Failure, CarNameListApi>> syncCarNamesFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.carNameDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final carNameListApi = CarNameListApi.fromJson(response.data);
      return Right(carNameListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

