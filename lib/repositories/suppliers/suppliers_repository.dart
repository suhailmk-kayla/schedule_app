import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/supplier_model.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Suppliers Repository
/// Handles local DB operations and API sync for Suppliers
/// Converted from KMP's SuppliersRepository.kt
class SuppliersRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  SuppliersRepository({
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

  /// Get all suppliers with optional search key
  Future<Either<Failure, List<Supplier>>> getAllSuppliers({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Suppliers',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.query(
          'Suppliers',
          where: 'flag = 1 AND (LOWER(name) LIKE LOWER(?) OR LOWER(code) LIKE LOWER(?))',
          whereArgs: [searchPattern, searchPattern],
          orderBy: 'name ASC',
        );
      }

      final suppliers = maps.map((map) => Supplier.fromMap(map)).toList();
      return Right(suppliers);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get supplier by user ID
  Future<Either<Failure, Supplier?>> getSupplierByUserId(int userId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Suppliers',
        where: 'flag = 1 AND userId = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final supplier = Supplier.fromMap(maps.first);
      return Right(supplier);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted supplier
  Future<Either<Failure, Supplier?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Suppliers',
        orderBy: 'supplierId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final supplier = Supplier.fromMap(maps.first);

      return Right(supplier);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single supplier to local DB
  /// Uses raw SQL INSERT OR REPLACE to match KMP behavior:
  /// INSERT OR REPLACE INTO Suppliers(id, supplierId, ...) VALUES (NULL, ?, ...)
  /// Replacement must pivot on supplierId (business ID), not the auto-increment id
  Future<Either<Failure, void>> addSupplier(Supplier supplier) async {
    try {
      final db = await _database;
      final map = supplier.toMap();
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO Suppliers(
          id, supplierId, userId, code, name, phone, address,
          deviceToken, createdDateTime, updatedDateTime, flag
        ) VALUES (
          NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          map['supplierId'],
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
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple suppliers to local DB (transaction)
  /// Uses raw SQL INSERT OR REPLACE with NULL id to ensure replacement on supplierId
  Future<Either<Failure, void>> addSuppliers(List<Supplier> suppliers) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        for (final supplier in suppliers) {
          final map = supplier.toMap();
          await txn.rawInsert(
            '''
            INSERT OR REPLACE INTO Suppliers(
              id, supplierId, userId, code, name, phone, address,
              deviceToken, createdDateTime, updatedDateTime, flag
            ) VALUES (
              NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              map['supplierId'],
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
      });
      developer.log('SuppliersRepository: ${suppliers.length} suppliers added successfully');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update supplier in local DB
  Future<Either<Failure, void>> updateSupplierLocal({
    required int supplierId,
    required String code,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Suppliers',
        {
          'code': code,
          'name': name,
          'phone': phone,
          'address': address,
        },
        where: 'supplierId = ?',
        whereArgs: [supplierId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update supplier flag
  Future<Either<Failure, void>> updateSupplierFlag({
    required int supplierId,
    required int flag,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Suppliers',
        {'flag': flag},
        where: 'supplierId = ?',
        whereArgs: [supplierId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all suppliers from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('Suppliers');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync suppliers from API (batch download or single record retry)
  /// Converted from KMP's downloadSupplier function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all suppliers in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific supplier by id only
  Future<Either<Failure, Map<String, dynamic>>> syncSuppliersFromApi({
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
        ApiEndpoints.supplierDownload,
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

