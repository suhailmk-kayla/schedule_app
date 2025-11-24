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
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  CarNameRepository({
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

  /// Get all car names by brand ID
  Future<Either<Failure, List<Name>>> getCarNamesByBrandId(int brandId) async {
    try {
      final db = await _database;
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
      final db = await _database;
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
      final db = await _database;
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

  /// Get all cars with brand name (for list display)
  /// Returns raw maps with carBrand and carName data
  /// Converted from KMP's getAllCars
  Future<Either<Failure, List<Map<String, dynamic>>>> getAllCars({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT
            CarBrand.name AS carBrand,
            CarName.*
          FROM
            CarName
          LEFT JOIN
            CarBrand ON CarBrand.carBrandId = CarName.carBrandId
          WHERE
            CarName.flag = 1
          ORDER BY
            CarName.name ASC
          ''',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT
            CarBrand.name AS carBrand,
            CarName.*
          FROM
            CarName
          LEFT JOIN
            CarBrand ON CarBrand.carBrandId = CarName.carBrandId
          WHERE
            CarName.flag = 1 AND (
              LOWER(CarBrand.name) LIKE LOWER(?) OR 
              LOWER(CarName.name) LIKE LOWER(?)
            )
          ORDER BY
            CarName.name ASC
          ''',
          [searchPattern, searchPattern],
        );
      }

      return Right(maps);
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
      final db = await _database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO CarName (id,carNameId, carBrandId, name, flag)
        VALUES (NULL, ?, ?, ?)
        ''',
        [
          carName.id,
          carName.carBrandId,
          carName.carName,
          carName.flag ?? 1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple car names to local DB (transaction)
  Future<Either<Failure, void>> addCarNames(List<Name> carNames) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        const sql = '''
        INSERT OR REPLACE INTO CarName (id, carNameId, carBrandId, name, flag)
        VALUES (NULL, ?, ?, ?, ?)
        ''';
        for (final carName in carNames) {
          await txn.rawInsert(
            sql,
            [
              carName.id,
              carName.carBrandId,
              carName.carName,
              carName.flag ?? 1,
            ],
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
      final db = await _database;
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
      final db = await _database;
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
  /// Sync car names from API (batch download or single record retry)
  /// Converted from KMP's downloadCarName function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all car names in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific car name by id only
  Future<Either<Failure, CarNameListApi>> syncCarNamesFromApi({
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
        ApiEndpoints.carNameDownload,
        queryParameters: queryParams,
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

