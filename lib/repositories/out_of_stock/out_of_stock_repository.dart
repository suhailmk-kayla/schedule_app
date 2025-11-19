import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// OutOfStock Repository
/// Handles local DB operations and API sync for OutOfStock Master and Products
/// Converted from KMP's OutOfStockProductRepository.kt
class OutOfStockRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  OutOfStockRepository({
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

  /// Get all out of stock masters with details (matching KMP's getOutOfStocksMaster)
  /// Returns OutOfStockMasterWithDetails with joined fields
  Future<Either<Failure, List<OutOfStockMasterWithDetails>>> getOutOfStockMastersWithDetails({
    String searchKey = '',
    String date = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT
            un.name AS unitName,
            un.displayName AS unitDispName,
            pr.name AS productName,
            CASE
              WHEN oosp.salesmanId = -1 THEN ''
              ELSE COALESCE(sal.name, sl.name)
            END AS salesman,
            CASE
              WHEN spp.userId = -1 THEN ''
              ELSE COALESCE(spp.name, '')
            END AS supplier,
            CASE
              WHEN oosp.storekeeperId = -1 THEN ''
              ELSE usr.name
            END AS storekeeper,
            CASE
              WHEN oosp.custId = -1 THEN ''
              ELSE cus.name
            END AS customerName,
            oosp.*
          FROM OutOfStockMaster oosp
          LEFT JOIN Units un ON un.unitId = oosp.unitId
          LEFT JOIN Product pr ON pr.productId = oosp.productId
          LEFT JOIN Users sl ON sl.userId = oosp.salesmanId
          LEFT JOIN SalesMan sal ON sal.userId = oosp.salesmanId
          LEFT JOIN Users usr ON usr.userId = oosp.storekeeperId
          LEFT JOIN Customers cus ON cus.customerId = oosp.custId
          LEFT JOIN OutOfStockProducts oosps ON oosps.oospMasterId = oosp.oospMasterId AND oosps.oospFlag = 1
          LEFT JOIN Users spp ON spp.userId = oosps.supplierId
          WHERE oosp.flag = 1 AND oosp.updatedDateTime LIKE ?
          ORDER BY oosp.oospMasterId DESC
          ''',
          ['%$date%'],
        );
      } else {
        maps = await db.rawQuery(
          '''
          SELECT
            un.name AS unitName,
            un.displayName AS unitDispName,
            pr.name AS productName,
            CASE
              WHEN oosp.salesmanId = -1 THEN ''
              ELSE COALESCE(sal.name, sl.name)
            END AS salesman,
            CASE
              WHEN spp.userId = -1 THEN ''
              ELSE COALESCE(spp.name, '')
            END AS supplier,
            CASE
              WHEN oosp.storekeeperId = -1 THEN ''
              ELSE usr.name
            END AS storekeeper,
            CASE
              WHEN oosp.custId = -1 THEN ''
              ELSE cus.name
            END AS customerName,
            oosp.*
          FROM OutOfStockMaster oosp
          LEFT JOIN Units un ON un.unitId = oosp.unitId
          LEFT JOIN Product pr ON pr.productId = oosp.productId
          LEFT JOIN Users sl ON sl.userId = oosp.salesmanId
          LEFT JOIN SalesMan sal ON sal.userId = oosp.salesmanId
          LEFT JOIN Users usr ON usr.userId = oosp.storekeeperId
          LEFT JOIN Customers cus ON cus.customerId = oosp.custId
          LEFT JOIN OutOfStockProducts oosps ON oosps.oospMasterId = oosp.oospMasterId AND oosps.oospFlag = 1
          LEFT JOIN Users spp ON spp.userId = oosps.supplierId
          WHERE oosp.flag = 1 AND LOWER(pr.name) LIKE LOWER(?) AND oosp.updatedDateTime LIKE ?
          ORDER BY oosp.oospMasterId DESC
          ''',
          ['%$searchKey%', '%$date%'],
        );
      }

      final outOfStocks = maps.map((map) => OutOfStockMasterWithDetails.fromMap(map)).toList();
      return Right(outOfStocks);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get out of stock master by ID with details (matching KMP's getOutOfStockMaster)
  Future<Either<Failure, OutOfStockMasterWithDetails?>> getOutOfStockMasterWithDetailsById(
    int oospMasterId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          un.name AS unitName,
          un.displayName AS unitDispName,
          pr.name AS productName,
          CASE
            WHEN oosp.salesmanId = -1 THEN ''
            ELSE COALESCE(sal.name, sl.name)
          END AS salesman,
          CASE
            WHEN spp.userId = -1 THEN ''
            ELSE COALESCE(spp.name, '')
          END AS supplier,
          CASE
            WHEN oosp.storekeeperId = -1 THEN ''
            ELSE usr.name
          END AS storekeeper,
          CASE
            WHEN oosp.custId = -1 THEN ''
            ELSE cus.name
          END AS customerName,
          oosp.*
        FROM OutOfStockMaster oosp
        LEFT JOIN Units un ON un.unitId = oosp.unitId
        LEFT JOIN Product pr ON pr.productId = oosp.productId
        LEFT JOIN Users sl ON sl.userId = oosp.salesmanId
        LEFT JOIN SalesMan sal ON sal.userId = oosp.salesmanId
        LEFT JOIN Users usr ON usr.userId = oosp.storekeeperId
        LEFT JOIN Customers cus ON cus.customerId = oosp.custId
        LEFT JOIN OutOfStockProducts oosps ON oosps.oospMasterId = oosp.oospMasterId AND oosps.oospFlag = 1
        LEFT JOIN Users spp ON spp.userId = oosps.supplierId
        WHERE oosp.flag = 1 AND oosp.oospMasterId = ?
        LIMIT 1
        ''',
        [oospMasterId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final outOfStock = OutOfStockMasterWithDetails.fromMap(maps.first);
      return Right(outOfStock);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get out of stock subs by master ID with details (matching KMP's getOutOfStocksSub)
  Future<Either<Failure, List<OutOfStockSubWithDetails>>> getOutOfStockSubsWithDetailsByMasterId(
    int oospMasterId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          un.name AS unitName,
          un.displayName AS unitDispName,
          pr.name AS productName,
          CASE
            WHEN oosp.salesmanId = -1 THEN ''
            ELSE COALESCE(sal.name, COALESCE(sl.name, ''))
          END AS salesman,
          CASE
            WHEN oosp.storekeeperId = -1 THEN ''
            ELSE COALESCE(usr.name, '')
          END AS storekeeper,
          CASE
            WHEN oosp.supplierId = -1 THEN ''
            ELSE COALESCE(spp.name, '')
          END AS supplierName,
          CASE
            WHEN oosp.custId = -1 THEN ''
            ELSE COALESCE(cus.name, '')
          END AS customerName,
          CASE
            WHEN EXISTS (
              SELECT 1 FROM PackedSubs ps
              WHERE ps.orderSubId = oosp.oospId
            ) THEN 1
            ELSE 0
          END AS isPacked,
          oosp.*
        FROM OutOfStockProducts oosp
        LEFT JOIN Units un ON un.unitId = oosp.unitId
        LEFT JOIN Product pr ON pr.productId = oosp.productId
        LEFT JOIN Users sl ON sl.userId = oosp.salesmanId
        LEFT JOIN SalesMan sal ON sal.userId = oosp.salesmanId
        LEFT JOIN Users usr ON usr.userId = oosp.storekeeperId
        LEFT JOIN Customers cus ON cus.customerId = oosp.custId
        LEFT JOIN Users spp ON spp.userId = oosp.supplierId
        WHERE oosp.flag = 1 AND oosp.oospMasterId = ?
        ORDER BY oosp.oospId
        ''',
        [oospMasterId],
      );

      final outOfStockSubs = maps.map((map) => OutOfStockSubWithDetails.fromMap(map)).toList();
      return Right(outOfStockSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get out of stock subs by supplier ID with details (matching KMP's getOutOfStocksSub for supplier)
  Future<Either<Failure, List<OutOfStockSubWithDetails>>> getOutOfStockSubsWithDetailsBySupplier({
    required int supplierId,
    String searchKey = '',
    String date = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.rawQuery(
          '''
          SELECT
            un.name AS unitName,
            un.displayName AS unitDispName,
            pr.name AS productName,
            CASE
              WHEN EXISTS (
                SELECT 1 FROM PackedSubs ps
                WHERE ps.orderSubId = oosp.oospId
              ) THEN 1
              ELSE 0
            END AS isPacked,
            oosp.*
          FROM OutOfStockProducts oosp
          LEFT JOIN Units un ON un.unitId = oosp.unitId
          LEFT JOIN Product pr ON pr.productId = oosp.productId
          WHERE oosp.flag = 1 AND oosp.supplierId = ? AND oosp.updatedDateTime LIKE ?
          ORDER BY oosp.oospId
          ''',
          [supplierId, '%$date%'],
        );
      } else {
        maps = await db.rawQuery(
          '''
          SELECT
            un.name AS unitName,
            un.displayName AS unitDispName,
            pr.name AS productName,
            CASE
              WHEN EXISTS (
                SELECT 1 FROM PackedSubs ps
                WHERE ps.orderSubId = oosp.oospId
              ) THEN 1
              ELSE 0
            END AS isPacked,
            oosp.*
          FROM OutOfStockProducts oosp
          LEFT JOIN Units un ON un.unitId = oosp.unitId
          LEFT JOIN Product pr ON pr.productId = oosp.productId
          WHERE oosp.flag = 1 AND oosp.supplierId = ? AND LOWER(pr.name) LIKE LOWER(?) AND oosp.updatedDateTime LIKE ?
          ORDER BY oosp.oospId
          ''',
          [supplierId, '%$searchKey%', '%$date%'],
        );
      }

      final outOfStockSubs = maps.map((map) => OutOfStockSubWithDetails.fromMap(map)).toList();
      return Right(outOfStockSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get out of stock sub by ID
  Future<Either<Failure, OutOfStockSub?>> getOutOfStockSubById(int oospId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          un.name AS unitName,
          un.displayName AS unitDispName,
          pr.name AS productName,
          CASE
            WHEN oosp.salesmanId = -1 THEN ''
            ELSE COALESCE(sal.name, COALESCE(sl.name, ''))
          END AS salesman,
          CASE
            WHEN oosp.storekeeperId = -1 THEN ''
            ELSE COALESCE(usr.name, '')
          END AS storekeeper,
          CASE
            WHEN oosp.supplierId = -1 THEN ''
            ELSE COALESCE(spp.name, '')
          END AS supplierName,
          CASE
            WHEN oosp.custId = -1 THEN ''
            ELSE COALESCE(cus.name, '')
          END AS customerName,
          CASE
            WHEN EXISTS (
              SELECT 1 FROM PackedSubs ps
              WHERE ps.orderSubId = oosp.oospId
            ) THEN 1
            ELSE 0
          END AS isPacked,
          oosp.*
        FROM OutOfStockProducts oosp
        LEFT JOIN Units un ON un.unitId = oosp.unitId
        LEFT JOIN Product pr ON pr.productId = oosp.productId
        LEFT JOIN Users sl ON sl.userId = oosp.salesmanId
        LEFT JOIN SalesMan sal ON sal.userId = oosp.salesmanId
        LEFT JOIN Users usr ON usr.userId = oosp.storekeeperId
        LEFT JOIN Customers cus ON cus.customerId = oosp.custId
        LEFT JOIN Users spp ON spp.userId = oosp.supplierId
        WHERE oosp.flag = 1 AND oosp.oospId = ?
        LIMIT 1
        ''',
        [oospId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final outOfStockSub = OutOfStockSub.fromMap(maps.first);
      return Right(outOfStockSub);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get count of unviewed out of stock masters
  Future<Either<Failure, int>> getUnviewedMasterCount() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OutOfStockMaster',
        where: 'flag = 1 AND isViewed = 0',
      );
      return Right(maps.length);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get count of unviewed out of stock products
  Future<Either<Failure, int>> getUnviewedProductCount() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OutOfStockProducts',
        where: 'flag = 1 AND isViewed = 0',
      );
      return Right(maps.length);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted out of stock master
  Future<Either<Failure, OutOfStock?>> getLastMasterEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OutOfStockMaster',
        orderBy: 'oospMasterId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final outOfStock = OutOfStock.fromMap(maps.first);
      return Right(outOfStock);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted out of stock product
  Future<Either<Failure, OutOfStockSub?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OutOfStockProducts',
        orderBy: 'oospId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final outOfStockSub = OutOfStockSub.fromMap(maps.first);
      return Right(outOfStockSub);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add out of stock master to local DB
  Future<Either<Failure, void>> addOutOfStockMaster(OutOfStock outOfStock) async {
    try {
      final db = await _database;
      await db.insert(
        'OutOfStockMaster',
        outOfStock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple out of stock masters to local DB (transaction)
  Future<Either<Failure, void>> addOutOfStockMasters(
    List<OutOfStock> outOfStocks,
  ) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final outOfStock in outOfStocks) {
          batch.insert(
            'OutOfStockMaster',
            outOfStock.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add out of stock product to local DB
  Future<Either<Failure, void>> addOutOfStockProduct(
    OutOfStockSub outOfStockSub,
  ) async {
    try {
      final db = await _database;
      await db.insert(
        'OutOfStockProducts',
        outOfStockSub.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple out of stock products to local DB (transaction)
  Future<Either<Failure, void>> addOutOfStockProducts(
    List<OutOfStockSub> outOfStockSubs,
  ) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final outOfStockSub in outOfStockSubs) {
          batch.insert(
            'OutOfStockProducts',
            outOfStockSub.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update supplier for out of stock product
  Future<Either<Failure, void>> updateSupplier({
    required int oospId,
    required int supplierId,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OutOfStockProducts',
        {'supplierId': supplierId},
        where: 'oospId = ?',
        whereArgs: [oospId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update out of stock product flag
  Future<Either<Failure, void>> updateOospFlag({
    required int oospId,
    required int oospFlag,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'OutOfStockProducts',
        {
          'oospFlag': oospFlag,
          'updatedDateTime': now,
        },
        where: 'oospId = ?',
        whereArgs: [oospId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update is checked flag
  Future<Either<Failure, void>> updateIsCheckedFlag({
    required int oospId,
    required int isCheckedFlag,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OutOfStockProducts',
        {'isCheckedflag': isCheckedFlag},
        where: 'oospId = ?',
        whereArgs: [oospId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update complete flag for master
  Future<Either<Failure, void>> updateCompleteFlag(int oospMasterId) async {
    try {
      final db = await _database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'OutOfStockMaster',
        {
          'isCompleteflag': 1,
          'updatedDateTime': now,
        },
        where: 'oospMasterId = ?',
        whereArgs: [oospMasterId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update is viewed flag for master
  Future<Either<Failure, void>> updateIsMasterViewedFlag({
    required int oospMasterId,
    required int isViewed,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OutOfStockMaster',
        {'isViewed': isViewed},
        where: 'oospMasterId = ?',
        whereArgs: [oospMasterId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update is viewed flag for products
  Future<Either<Failure, void>> updateIsSubViewedFlag({
    required int oospMasterId,
    required int isViewed,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OutOfStockProducts',
        {'isViewed': isViewed},
        where: 'oospMasterId = ?',
        whereArgs: [oospMasterId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all out of stock data
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.delete('OutOfStockProducts');
        await txn.delete('OutOfStockMaster');
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync out of stock masters from API (batch download)
  /// Sync out of stock masters from API (batch download or single record retry)
  /// Converted from KMP's downloadOutOfStock function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all out of stock masters in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific out of stock master by id only
  Future<Either<Failure, OutOfStockListApi>> syncOutOfStockMastersFromApi({
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
        ApiEndpoints.outOfStockDownload,
        queryParameters: queryParams,
      );

      final outOfStockListApi = OutOfStockListApi.fromJson(response.data);
      return Right(outOfStockListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Sync out of stock products from API (batch download or single record retry)
  /// Converted from KMP's downloadOutOfStockSub function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all out of stock products in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific out of stock product by id only
  Future<Either<Failure, OutOfStockSubListApi>> syncOutOfStockProductsFromApi({
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
        ApiEndpoints.outOfStockSubDownload,
        queryParameters: queryParams,
      );

      final outOfStockSubListApi = OutOfStockSubListApi.fromJson(response.data);
      return Right(outOfStockSubListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create out of stock via API and update local DB
  Future<Either<Failure, OutOfStock>> createOutOfStock(
    OutOfStock outOfStock,
  ) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addOutOfStock,
        data: outOfStock.toJson(),
      );

      // 2. Parse response
      final outOfStockApi = OutOfStockApi.fromJson(response.data);
      if (outOfStockApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create out of stock: ${outOfStockApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addOutOfStockMaster(outOfStockApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => outOfStockApi.data);
      }

      return Right(outOfStockApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update out of stock sub via API and update local DB
  Future<Either<Failure, OutOfStockSub>> updateOutOfStockSub(
    OutOfStockSub outOfStockSub,
  ) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: outOfStockSub.toJson(),
      );

      // 2. Parse response
      final outOfStockSubApi = OutOfStockSubApi.fromJson(response.data);
      if (outOfStockSubApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update out of stock sub: ${outOfStockSubApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addOutOfStockProduct(outOfStockSubApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => outOfStockSubApi.data);
      }

      return Right(outOfStockSubApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

