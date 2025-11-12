import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Routes Repository
/// Handles local DB operations and API sync for Routes
/// Converted from KMP's RoutesRepository.kt
class RoutesRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  RoutesRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all routes with optional search key
  Future<Either<Failure, List<Route>>> getAllRoutes({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Routes',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT * FROM Routes 
          WHERE flag = 1 AND (
            LOWER(name) LIKE LOWER(?) OR 
            LOWER(code) LIKE LOWER(?)
          )
          ORDER BY name ASC
          ''',
          [searchPattern, searchPattern],
        );
      }

      final routes = maps.map((map) => Route.fromMap(map)).toList();
      return Right(routes);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all routes with salesman name (join query)
  /// Converted from KMP's getAllRoutesWithSaleman query
  Future<Either<Failure, List<RouteWithSalesman>>> getAllRoutesWithSalesman({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT s.name AS salesman, r.* 
          FROM Routes AS r
          LEFT JOIN SalesMan AS s ON r.salesmanId = s.userId
          WHERE r.flag = 1 
          ORDER BY r.name ASC
          ''',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT s.name AS salesman, r.* 
          FROM Routes AS r
          LEFT JOIN SalesMan AS s ON r.salesmanId = s.userId
          WHERE r.flag = 1 AND (
            LOWER(r.name) LIKE LOWER(?) OR 
            LOWER(r.code) LIKE LOWER(?) OR 
            LOWER(s.name) LIKE LOWER(?)
          )
          ORDER BY r.name ASC
          ''',
          [searchPattern, searchPattern, searchPattern],
        );
      }

      final routes = maps.map((map) => RouteWithSalesman.fromMap(map)).toList();
      return Right(routes);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get route by name
  Future<Either<Failure, List<Route>>> getRouteByName(String name) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Routes',
        where: 'flag = 1 AND LOWER(name) = LOWER(?)',
        whereArgs: [name],
        orderBy: 'name ASC',
      );

      final routes = maps.map((map) => Route.fromMap(map)).toList();
      return Right(routes);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get route by name excluding specific route ID
  Future<Either<Failure, List<Route>>> getRouteByNameAndId({
    required String name,
    required int routeId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Routes',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND routeId != ?',
        whereArgs: [name, routeId],
        orderBy: 'name ASC',
      );

      final routes = maps.map((map) => Route.fromMap(map)).toList();
      return Right(routes);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get routes by salesman ID
  Future<Either<Failure, List<Route>>> getRoutesBySalesman(int salesmanId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Routes',
        where: 'flag = 1 AND salesmanId = ?',
        whereArgs: [salesmanId],
        orderBy: 'name ASC',
      );

      final routes = maps.map((map) => Route.fromMap(map)).toList();
      return Right(routes);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted route
  Future<Either<Failure, Route?>> getLastEntry() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Routes',
        orderBy: 'routeId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final route = Route.fromMap(maps.first);
      return Right(route);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single route to local DB
  Future<Either<Failure, void>> addRoute(Route route) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Routes',
        route.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple routes to local DB (transaction)
  Future<Either<Failure, void>> addRoutes(List<Route> routes) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final route in routes) {
          await txn.insert(
            'Routes',
            route.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update route in local DB
  Future<Either<Failure, void>> updateRouteLocal(Route route) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'Routes',
        {'name': route.name},
        where: 'routeId = ?',
        whereArgs: [route.id],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all routes from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('Routes');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync routes from API (batch download)
  Future<Either<Failure, RouteListApi>> syncRoutesFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.routesDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final routeListApi = RouteListApi.fromJson(response.data);
      return Right(routeListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create route via API and update local DB
  Future<Either<Failure, Route>> createRoute({
    required String name,
    required String code,
    required int salesmanId,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addRoute,
        data: {
          'name': name,
          'code': code,
          'salesman_id': salesmanId,
        },
      );

      // 2. Parse response
      final addRouteApi = AddRouteApi.fromJson(response.data);
      if (addRouteApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create route: ${addRouteApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addRoute(addRouteApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => addRouteApi.data);
      }

      return Right(addRouteApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update route via API and update local DB
  Future<Either<Failure, Route>> updateRoute({
    required int routeId,
    required String name,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateRoute,
        data: {
          'id': routeId,
          'name': name,
        },
      );

      // 2. Parse response
      final addRouteApi = AddRouteApi.fromJson(response.data);
      if (addRouteApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update route: ${addRouteApi.message}',
        ));
      }

      // 3. Store in local DB
      final updateResult = await updateRouteLocal(addRouteApi.data);
      if (updateResult.isLeft) {
        return updateResult.map((_) => addRouteApi.data);
      }

      return Right(addRouteApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

