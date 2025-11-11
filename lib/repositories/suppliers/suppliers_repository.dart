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

  SuppliersRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all suppliers with optional search key
  Future<Either<Failure, List<Supplier>>> getAllSuppliers({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
  Future<Either<Failure, void>> addSupplier(Supplier supplier) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Suppliers',
        supplier.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple suppliers to local DB (transaction)
  Future<Either<Failure, void>> addSuppliers(List<Supplier> suppliers) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final supplier in suppliers) {
          await txn.insert(
            'Suppliers',
            supplier.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
      await db.delete('Suppliers');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync suppliers from API (batch download)
  Future<Either<Failure, Map<String, dynamic>>> syncSuppliersFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.supplierDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );
      return Right(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

