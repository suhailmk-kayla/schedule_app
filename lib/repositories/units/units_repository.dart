import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Units Repository
/// Handles local DB operations and API sync for Units
/// Converted from KMP's UnitsRepository.kt
class UnitsRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  UnitsRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all units with optional search key
  Future<Either<Failure, List<Units>>> getAllUnits({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Units',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT * FROM Units 
          WHERE flag = 1 AND (
            LOWER(name) LIKE LOWER(?) OR 
            LOWER(code) LIKE LOWER(?) OR 
            LOWER(displayName) LIKE LOWER(?)
          )
          ORDER BY name ASC
          ''',
          [searchPattern, searchPattern, searchPattern],
        );
      }

      final units = maps.map((map) => Units.fromMap(map)).toList();
      return Right(units);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all base units (type = 0)
  Future<Either<Failure, List<Units>>> getAllBaseUnits() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Units',
        where: 'flag = 1 AND type = ?',
        whereArgs: [0],
        orderBy: 'name ASC',
      );

      final units = maps.map((map) => Units.fromMap(map)).toList();
      return Right(units);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get unit by code
  Future<Either<Failure, Units?>> getUnitByCode(String code) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Units',
        where: 'flag = 1 AND LOWER(code) = LOWER(?)',
        whereArgs: [code],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final unit = Units.fromMap(maps.first);
      return Right(unit);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get unit by name
  Future<Either<Failure, Units?>> getUnitByName(String name, {int? unitId}) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps;

      if (unitId == null) {
        maps = await db.query(
          'Units',
          where: 'flag = 1 AND LOWER(name) = LOWER(?)',
          whereArgs: [name],
          orderBy: 'id DESC',
          limit: 1,
        );
      } else {
        maps = await db.query(
          'Units',
          where: 'flag = 1 AND LOWER(name) = LOWER(?) AND unitId != ?',
          whereArgs: [name, unitId],
          orderBy: 'id DESC',
          limit: 1,
        );
      }

      if (maps.isEmpty) {
        return const Right(null);
      }

      final unit = Units.fromMap(maps.first);
      return Right(unit);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get unit by unit ID
  Future<Either<Failure, Units?>> getUnitByUnitId(int unitId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Units',
        where: 'unitId = ?',
        whereArgs: [unitId],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final unit = Units.fromMap(maps.first);
      return Right(unit);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all derived units by base unit ID
  Future<Either<Failure, List<Units>>> getAllDerivedUnitsByBaseId(int baseId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Units',
        where: 'flag = 1 AND baseId = ? AND type = ?',
        whereArgs: [baseId, 1],
        orderBy: 'id DESC',
        limit: 1,
      );

      final units = maps.map((map) => Units.fromMap(map)).toList();
      return Right(units);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted unit
  Future<Either<Failure, Units?>> getLastEntry() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Units',
        where: 'flag = 1',
        orderBy: 'unitId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final unit = Units.fromMap(maps.first);
      return Right(unit);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single unit to local DB
  Future<Either<Failure, void>> addUnit(Units unit) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Units',
        unit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple units to local DB (transaction)
  Future<Either<Failure, void>> addUnits(List<Units> units) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final unit in units) {
          await txn.insert(
            'Units',
            unit.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update unit in local DB
  Future<Either<Failure, void>> updateUnitLocal(Units unit) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'Units',
        {
          'name': unit.name,
          'displayName': unit.displayName,
          'comment': unit.comment,
        },
        where: 'unitId = ?',
        whereArgs: [unit.id],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all units from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('Units');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync units from API (batch download)
  Future<Either<Failure, UnitListApi>> syncUnitsFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.unitsDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final unitListApi = UnitListApi.fromJson(response.data);
      return Right(unitListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create unit via API and update local DB
  Future<Either<Failure, Units>> createUnit(Units unit) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addUnit,
        data: unit.toJson(),
      );

      // 2. Parse response
      final unitApi = UnitApi.fromJson(response.data);
      if (unitApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create unit: ${unitApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addUnit(unitApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => unitApi.data);
      }

      return Right(unitApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update unit via API and update local DB
  Future<Either<Failure, Units>> updateUnit({
    required Units unit,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateUnit,
        data: unit.toJson(),
      );

      // 2. Parse response
      final unitApi = UnitApi.fromJson(response.data);
      if (unitApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update unit: ${unitApi.message}',
        ));
      }

      // 3. Store in local DB
      final updateResult = await updateUnitLocal(unitApi.data);
      if (updateResult.isLeft) {
        return updateResult.map((_) => unitApi.data);
      }

      return Right(unitApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

