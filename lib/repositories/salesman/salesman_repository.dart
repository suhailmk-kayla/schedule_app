import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/salesman_model.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// SalesMan Repository
/// Handles local DB operations and API sync for SalesMan
/// Converted from KMP's SalesManRepository.kt
class SalesManRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  SalesManRepository({
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

  /// Get all salesmen with optional search key
  Future<Either<Failure, List<SalesMan>>> getAllSalesMan({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'SalesMan',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'LOWER(name) ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.query(
          'SalesMan',
          where: 'flag = 1 AND (LOWER(name) LIKE LOWER(?) OR LOWER(code) LIKE LOWER(?))',
          whereArgs: [searchPattern, searchPattern],
          orderBy: 'LOWER(name) ASC',
        );
      }

      final salesmen = maps.map((map) => SalesMan.fromMap(map)).toList();
      return Right(salesmen);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get salesman by user ID
  Future<Either<Failure, SalesMan?>> getSalesManByUserId(int userId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SalesMan',
        where: 'flag = 1 AND userId = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final salesman = SalesMan.fromMap(maps.first);
      return Right(salesman);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted salesman
  Future<Either<Failure, SalesMan?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'SalesMan',
        orderBy: 'salesManId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final salesman = SalesMan.fromMap(maps.first);
      return Right(salesman);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single salesman to local DB
  /// Uses raw SQL INSERT OR REPLACE to match KMP behavior exactly:
  /// INSERT OR REPLACE INTO SalesMan(id, salesManId, ...) VALUES (NULL, ?, ...)
  /// This ensures replacement happens on salesManId UNIQUE constraint, not PRIMARY KEY
  /// The id (PRIMARY KEY AUTOINCREMENT) is auto-managed by the database (we pass NULL)
  Future<Either<Failure, void>> addSalesMan(SalesMan salesman) async {
    try {
      final db = await _database;
      final map = salesman.toMapLocalDatabase();
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO SalesMan(
          salesManId, userId, code, name, phone, address, 
          deviceToken, createdDateTime, updatedDateTime, flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          map['salesManId'],
          map['userId'],
          map['code'],
          map['name'],
          map['phone'],
          map['address'],
          map['deviceToken'],
          map['createdDateTime'],
          map['updatedDateTime'],
          map['flag'],
        ],
      );
      return const Right(null);
    } catch (e) {
      developer.log('SalesManRepository: Error adding salesman: $e');
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple salesmen to local DB (transaction)
  /// Uses raw SQL INSERT OR REPLACE to match KMP behavior exactly:
  /// INSERT OR REPLACE INTO SalesMan(id, salesManId, ...) VALUES (NULL, ?, ...)
  /// This ensures replacement happens on salesManId UNIQUE constraint, not PRIMARY KEY
  /// The id (PRIMARY KEY AUTOINCREMENT) is auto-managed by the database (we pass NULL)
  /// Matches KMP's SalesManRepository.add transaction pattern
  /// CRITICAL OPTIMIZATION: Uses batch operations for 100x+ performance improvement
  Future<Either<Failure, void>> addSalesMen(List<SalesMan> salesmen) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final salesman in salesmen) {
          final map = salesman.toMapLocalDatabase();
          // CRITICAL: Use batch.rawInsert() instead of await txn.rawInsert() - 100x faster!
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO SalesMan(
              salesManId, userId, code, name, phone, address, 
              deviceToken, createdDateTime, updatedDateTime, flag
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              map['salesManId'],
              map['userId'],
              map['code'],
              map['name'],
              map['phone'],
              map['address'],
              map['deviceToken'],
              map['createdDateTime'],
              map['updatedDateTime'],
              map['flag'],
            ],
          );
        }
        // CRITICAL: Commit all inserts at once - matches SQLDelight's optimized behavior
        await batch.commit(noResult: true);
        developer.log('SalesManRepository: ${salesmen.length} salesmen added successfully');
      });
      return const Right(null);
    } catch (e) {
      developer.log('SalesManRepository: Error adding salesmen: $e');
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update salesman in local DB
  Future<Either<Failure, void>> updateSalesManLocal({
    required int salesManId,
    required String code,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'SalesMan',
        {
          'code': code,
          'name': name,
          'phone': phone,
          'address': address,
        },
        where: 'salesManId = ?',
        whereArgs: [salesManId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update salesman flag
  Future<Either<Failure, void>> updateSalesManFlag({
    required int salesManId,
    required int flag,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'SalesMan',
        {'flag': flag},
        where: 'salesManId = ?',
        whereArgs: [salesManId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all salesmen from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('SalesMan');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync salesmen from API (batch download or single record retry)
  /// Converted from KMP's downloadSalesman function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all salesmen in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific salesman by id only
  Future<Either<Failure, Map<String, dynamic>>> syncSalesMenFromApi({
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
          'user_id': userId.toString(), // Added back to match KMP
          'update_date': updateDate,
        };
      } else {
        // Single record retry mode: send only id (matches KMP's params function when id != -1)
        queryParams = {
          'id': id.toString(),
        };
      }
      
      final response = await _dio.get(
      
        ApiEndpoints.salesManDownload,
        queryParameters: queryParams,
      );
      
      return Right(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

