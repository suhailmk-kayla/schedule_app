import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
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
          ORDER BY oosp.updatedDateTime DESC
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
          ORDER BY oosp.updatedDateTime DESC
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

  /// Get out of stock sub by sub ID with details (matching KMP's getOutOfStocksSubBySubId)
  Future<Either<Failure, OutOfStockSubWithDetails?>> getOutOfStockSubWithDetailsBySubId(
    int oospId,
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
        WHERE oosp.flag = 1 AND oosp.oospId = ?
        LIMIT 1
        ''',
        [oospId],
      );

      if (maps.isEmpty) {
         
        return const Right(null);
      }

      final outOfStockSub = OutOfStockSubWithDetails.fromMap(maps.first);
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
  /// isViewed: 1 for reportAdmin (single item, likely viewed), 0 for reportAllAdmin (batch, may need review)
  /// Matching KMP: reportAdmin sets isViewed=1 (line 1785), reportAllAdmin sets isViewed=0 (line 1633)
  Future<Either<Failure, void>> addOutOfStockMaster(
    OutOfStock outOfStock, {
    int isViewed = 0,
  }) async {
    try {
      // TRACE: log what we write to local OutOfStockMaster (orderSubId = path 1 from master)
      developer.log(
        'OutOfStockRepository.addOutOfStockMaster: writing oospMasterId=${outOfStock.outOfStockId}, orderSubId=${outOfStock.outosOrderSubId}',
        name: 'OutOfStockRepository.trace',
      );
      final db = await _database;
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO OutOfStockMaster (
          oospMasterId, orderSubId, custId, salesmanId, storekeeperId, 
          dateAndTime, productId, unitId, carId, qty, availQty, baseQty, 
          note, narration, createdDateTime, updatedDateTime, isCompleteflag, 
          flag, UUID, isViewed
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          outOfStock.outOfStockId, // Server ID
          outOfStock.outosOrderSubId,
          outOfStock.outosCustId,
          outOfStock.outosSalesManId,
          outOfStock.outosStockKeeperId,
          outOfStock.outosDateAndTime,
          outOfStock.outosProdId,
          outOfStock.outosUnitId,
          outOfStock.outosCarId,
          outOfStock.outosQty,
          outOfStock.outosAvailableQty,
          outOfStock.outosUnitBaseQty,
          outOfStock.outosNote ?? '',
          outOfStock.outosNarration ?? '',
          outOfStock.createdAt ?? '',
          outOfStock.updatedAt ?? '',
          outOfStock.outosIsCompleatedFlag,
          outOfStock.outosFlag ?? 0,
          outOfStock.uuid,
          isViewed,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple out of stock masters to local DB (transaction)
  /// isViewed: 1 for reportAdmin (single item, likely viewed), 0 for reportAllAdmin (batch, may need review)
  /// Matching KMP: reportAdmin sets isViewed=1 (line 1785), reportAllAdmin sets isViewed=0 (line 1633)
  Future<Either<Failure, void>> addOutOfStockMasters(
    List<OutOfStock> outOfStocks, {
    int isViewed = 1,
  }) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        // Use INSERT OR REPLACE (matches KMP pattern)
        for (final outOfStock in outOfStocks) {
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO OutOfStockMaster (
              oospMasterId, orderSubId, custId, salesmanId, storekeeperId, 
              dateAndTime, productId, unitId, carId, qty, availQty, baseQty, 
              note, narration, createdDateTime, updatedDateTime, isCompleteflag, 
              flag, UUID, isViewed
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              outOfStock.outOfStockId, // Server ID
              outOfStock.outosOrderSubId,
              outOfStock.outosCustId,
              outOfStock.outosSalesManId,
              outOfStock.outosStockKeeperId,
              outOfStock.outosDateAndTime,
              outOfStock.outosProdId,
              outOfStock.outosUnitId,
              outOfStock.outosCarId,
              outOfStock.outosQty,
              outOfStock.outosAvailableQty,
              outOfStock.outosUnitBaseQty,
              outOfStock.outosNote ?? '',
              outOfStock.outosNarration ?? '',
              outOfStock.createdAt ?? '',
              outOfStock.updatedAt ?? '',
              outOfStock.outosIsCompleatedFlag,
              outOfStock.outosFlag ?? 0,
              outOfStock.uuid,
              isViewed,
            ],
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
  /// isViewed: 1 for reportAdmin (single item, likely viewed), 0 for reportAllAdmin (batch, may need review)
  /// Matching KMP: reportAdmin sets isViewed=1 (line 1816), reportAllAdmin sets isViewed=1 (line 1664)
  Future<Either<Failure, void>> addOutOfStockProduct(
    OutOfStockSub outOfStockSub, {
    int isViewed = 0,
  }) async {
    try {
      final db = await _database;
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO OutOfStockProducts (
          oospId, oospMasterId, orderSubId, custId, salesmanId, storekeeperId, 
          dateAndTime, supplierId, productId, unitId, carId, rate, updateRate, 
          qty, availQty, baseQty, note, narration, oospFlag, createdDateTime, 
          updatedDateTime, isCheckedflag, flag, UUID, isViewed
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          outOfStockSub.outOfStockSubId, // Server ID
          outOfStockSub.outosSubOutosId,
          outOfStockSub.outosSubOrderSubId,
          outOfStockSub.outosSubCustId,
          outOfStockSub.outosSubSalesManId,
          outOfStockSub.outosSubStockKeeperId,
          outOfStockSub.outosSubDateAndTime,
          outOfStockSub.outosSubSuppId,
          outOfStockSub.outosSubProdId,
          outOfStockSub.outosSubUnitId,
          outOfStockSub.outosSubCarId,
          outOfStockSub.outosSubRate,
          outOfStockSub.outosSubUpdatedRate,
          outOfStockSub.outosSubQty,
          outOfStockSub.outosSubAvailableQty,
          outOfStockSub.outosSubUnitBaseQty,
          outOfStockSub.outosSubNote ?? '',
          outOfStockSub.outosSubNarration ?? '',
          outOfStockSub.outosSubStatusFlag,
          outOfStockSub.createdAt,
          outOfStockSub.updatedAt,
          outOfStockSub.outosSubIsCheckedFlag,
          outOfStockSub.outosSubFlag ?? 0,
          outOfStockSub.uuid,
          isViewed,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Upsert out of stock product in local DB (conflict replace)
  Future<Either<Failure, void>> upsertOutOfStockProduct(
    OutOfStockSub outOfStockSub, {
    int isViewed = 0,
  }) async {
    try {
      final db = await _database;
      // Use INSERT OR REPLACE (matches KMP pattern)
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO OutOfStockProducts (
          oospId, oospMasterId, orderSubId, custId, salesmanId, storekeeperId, 
          dateAndTime, supplierId, productId, unitId, carId, rate, updateRate, 
          qty, availQty, baseQty, note, narration, oospFlag, createdDateTime, 
          updatedDateTime, isCheckedflag, flag, UUID, isViewed
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          outOfStockSub.outOfStockSubId, // Server ID
          outOfStockSub.outosSubOutosId,
          outOfStockSub.outosSubOrderSubId,
          outOfStockSub.outosSubCustId,
          outOfStockSub.outosSubSalesManId,
          outOfStockSub.outosSubStockKeeperId,
          outOfStockSub.outosSubDateAndTime,
          outOfStockSub.outosSubSuppId,
          outOfStockSub.outosSubProdId,
          outOfStockSub.outosSubUnitId,
          outOfStockSub.outosSubCarId,
          outOfStockSub.outosSubRate,
          outOfStockSub.outosSubUpdatedRate,
          outOfStockSub.outosSubQty,
          outOfStockSub.outosSubAvailableQty,
          outOfStockSub.outosSubUnitBaseQty,
          outOfStockSub.outosSubNote ?? '',
          outOfStockSub.outosSubNarration ?? '',
          outOfStockSub.outosSubStatusFlag,
          outOfStockSub.createdAt,
          outOfStockSub.updatedAt,
          outOfStockSub.outosSubIsCheckedFlag,
          outOfStockSub.outosSubFlag ?? 0,
          outOfStockSub.uuid,
          isViewed,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple out of stock products to local DB (transaction)
  /// isViewed: 1 for reportAdmin (single item, likely viewed), 0 for reportAllAdmin (batch, may need review)
  /// Matching KMP: reportAdmin sets isViewed=1 (line 1816), reportAllAdmin sets isViewed=1 (line 1664)
  Future<Either<Failure, void>> addOutOfStockProducts(
    List<OutOfStockSub> outOfStockSubs, {
    int isViewed = 0,
  }) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        // Use INSERT OR REPLACE (matches KMP pattern)
        for (final outOfStockSub in outOfStockSubs) {
          // TRACE: log what we write to local OutOfStockProducts (orderSubId = path 2 from sub)
          developer.log(
            'OutOfStockRepository.addOutOfStockProducts: writing oospId=${outOfStockSub.outOfStockSubId}, oospMasterId=${outOfStockSub.outosSubOutosId}, orderSubId=${outOfStockSub.outosSubOrderSubId}',
            name: 'OutOfStockRepository.trace',
          );
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO OutOfStockProducts (
              oospId, oospMasterId, orderSubId, custId, salesmanId, storekeeperId, 
              dateAndTime, supplierId, productId, unitId, carId, rate, updateRate, 
              qty, availQty, baseQty, note, narration, oospFlag, createdDateTime, 
              updatedDateTime, isCheckedflag, flag, UUID, isViewed
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              outOfStockSub.outOfStockSubId, // Server ID
              outOfStockSub.outosSubOutosId,
              outOfStockSub.outosSubOrderSubId,
              outOfStockSub.outosSubCustId,
              outOfStockSub.outosSubSalesManId,
              outOfStockSub.outosSubStockKeeperId,
              outOfStockSub.outosSubDateAndTime,
              outOfStockSub.outosSubSuppId,
              outOfStockSub.outosSubProdId,
              outOfStockSub.outosSubUnitId,
              outOfStockSub.outosSubCarId,
              outOfStockSub.outosSubRate,
              outOfStockSub.outosSubUpdatedRate,
              outOfStockSub.outosSubQty,
              outOfStockSub.outosSubAvailableQty,
              outOfStockSub.outosSubUnitBaseQty,
              outOfStockSub.outosSubNote ?? '',
              outOfStockSub.outosSubNarration ?? '',
              outOfStockSub.outosSubStatusFlag,
              outOfStockSub.createdAt,
              outOfStockSub.updatedAt,
              outOfStockSub.outosSubIsCheckedFlag,
              outOfStockSub.outosSubFlag ?? 0,
              outOfStockSub.uuid,
              isViewed,
            ],
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

  /// Update is viewed flag for products by master ID
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

  /// Reject available quantity (matching KMP's rejectAvailableQty)
  /// Updates availQty, note, oospFlag, and isCheckedflag in one operation
  Future<Either<Failure, void>> rejectAvailableQty({
    required int oospId,
    required double availQty,
    required String note,
    required int oospFlag,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'OutOfStockProducts',
        {
          'availQty': availQty,
          'note': note,
          'oospFlag': oospFlag,
          'isCheckedflag': 1,
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

  /// Update is viewed flag for product by sub ID (matching KMP's updateIsSubViewedFlag by oospId)
  Future<Either<Failure, void>> updateIsSubViewedFlagBySubId({
    required int oospId,
    required int isViewed,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OutOfStockProducts',
        {'isViewed': isViewed},
        where: 'oospId = ?',
        whereArgs: [oospId],
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
  /// Matches KMP's createOutOfStockParams structure
  /// Note: Endpoint doesn't support notification payload, send notifications separately
  Future<Either<Failure, OutOfStock>> createOutOfStock(
    OutOfStock outOfStock, {
    Map<String, dynamic>? notificationPayload, // Deprecated: endpoint doesn't support it
  }) async {
    try {
      // Build payload matching KMP's createOutOfStockParams
      // Note: notificationPayload is ignored as endpoint doesn't support it
      final Map<String, dynamic> payload = {
        'outos_order_sub_id': outOfStock.outosOrderSubId,
        'outos_cust_id': outOfStock.outosCustId,
        'outos_sales_man_id': outOfStock.outosSalesManId,
        'outos_stock_keeper_id': outOfStock.outosStockKeeperId,
        'outos_date_and_time': outOfStock.outosDateAndTime,
        'outos_prod_id': outOfStock.outosProdId,
        'outos_unit_id': outOfStock.outosUnitId,
        'outos_car_id': outOfStock.outosCarId,
        'outos_qty': outOfStock.outosQty,
        'outos_available_qty': outOfStock.outosAvailableQty,
        'outos_unit_base_qty': outOfStock.outosUnitBaseQty,
        'outos_note': '',
        'outos_narration': outOfStock.outosNarration ?? '',
        'outos_is_compleated_flag': outOfStock.outosIsCompleatedFlag,
        'items': outOfStock.items?.map((sub) => {
              'outos_sub_order_sub_id': sub.outosSubOrderSubId,
              'outos_sub_supp_id': sub.outosSubSuppId,
              'outos_sub_prod_id': sub.outosSubProdId,
              'outos_sub_unit_id': sub.outosSubUnitId,
              'outos_sub_car_id': sub.outosSubCarId,
              'outos_sub_rate': sub.outosSubRate,
              'outos_sub_updated_rate': sub.outosSubUpdatedRate,
              'outos_sub_qty': sub.outosSubQty,
              'outos_sub_available_qty': sub.outosSubAvailableQty,
              'outos_sub_unit_base_qty': sub.outosSubUnitBaseQty,
              'outos_sub_status_flag': 0,
              'outos_sub_is_checked_flag': 0,
              'outos_sub_note': '',
              'outos_sub_narration': sub.outosSubNarration ?? '',
            }).toList() ?? [],
      };

      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addOutOfStock,
        data: payload,
      );

      // 2. Parse response
      final outOfStockApi = OutOfStockApi.fromJson(response.data);
      if (outOfStockApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create out of stock: ${outOfStockApi.message}',
        ));
      }

      // 3. Store in local DB
      // KMP uses getDBFormatDateTime() when storing from API response (lines 1780-1781)
      // This ensures consistent local timestamps regardless of API response dates
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // Create updated master with current DB format dates (matching KMP line 1780-1781)
      final masterToStore = OutOfStock(
        outOfStockId: outOfStockApi.data.outOfStockId, // Server ID from API
        outosOrderSubId: outOfStockApi.data.outosOrderSubId,
        outosCustId: outOfStockApi.data.outosCustId,
        outosSalesManId: outOfStockApi.data.outosSalesManId,
        outosStockKeeperId: outOfStockApi.data.outosStockKeeperId,
        outosDateAndTime: outOfStockApi.data.outosDateAndTime,
        outosProdId: outOfStockApi.data.outosProdId,
        outosUnitId: outOfStockApi.data.outosUnitId,
        outosCarId: outOfStockApi.data.outosCarId,
        outosQty: outOfStockApi.data.outosQty,
        outosAvailableQty: outOfStockApi.data.outosAvailableQty,
        outosUnitBaseQty: outOfStockApi.data.outosUnitBaseQty,
        outosNote: outOfStockApi.data.outosNote,
        outosNarration: outOfStockApi.data.outosNarration,
        outosIsCompleatedFlag: outOfStockApi.data.outosIsCompleatedFlag,
        outosFlag: outOfStockApi.data.outosFlag,
        uuid: outOfStockApi.data.uuid,
        createdAt: dateTimeStr, // Use current DB format (matching KMP)
        updatedAt: dateTimeStr, // Use current DB format (matching KMP)
        items: outOfStockApi.data.items,
      );

      // Store master (isViewed will be set by caller - reportAdmin uses 1, reportAllAdmin uses 0)
      // Note: We don't set isViewed here because it depends on the caller context
      final addResult = await addOutOfStockMaster(masterToStore);
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
      // 0. Get existing sub from local DB to preserve unchanged fields
      OutOfStockSub? existingSub;
      try {
        final existingResult = await getOutOfStockSubById(outOfStockSub.outOfStockSubId);
        existingResult.fold(
          (_) {},
          (sub) => existingSub = sub,
        );
      } catch (_) {
        // ignore fetch errors; proceed with provided data
      }

      // Build base sub with NEW values overlaid on existing fields
      final baseSub = OutOfStockSub(
        id: existingSub?.id,
        outOfStockSubId: existingSub?.outOfStockSubId ?? outOfStockSub.outOfStockSubId,
        outosSubOutosId: outOfStockSub.outosSubOutosId,
        outosSubOrderSubId: outOfStockSub.outosSubOrderSubId,
        outosSubCustId: outOfStockSub.outosSubCustId,
        outosSubSalesManId: outOfStockSub.outosSubSalesManId,
        outosSubStockKeeperId: outOfStockSub.outosSubStockKeeperId,
        outosSubDateAndTime: outOfStockSub.outosSubDateAndTime,
        outosSubSuppId: outOfStockSub.outosSubSuppId,
        outosSubProdId: outOfStockSub.outosSubProdId,
        outosSubUnitId: outOfStockSub.outosSubUnitId,
        outosSubCarId: outOfStockSub.outosSubCarId,
        outosSubRate: outOfStockSub.outosSubRate,
        outosSubUpdatedRate: outOfStockSub.outosSubUpdatedRate,
        outosSubQty: outOfStockSub.outosSubQty,
        outosSubAvailableQty: outOfStockSub.outosSubAvailableQty,
        outosSubUnitBaseQty: outOfStockSub.outosSubUnitBaseQty,
        outosSubStatusFlag: outOfStockSub.outosSubStatusFlag,
        outosSubIsCheckedFlag: outOfStockSub.outosSubIsCheckedFlag,
        outosSubNote: outOfStockSub.outosSubNote,
        outosSubNarration: outOfStockSub.outosSubNarration,
        outosSubFlag: outOfStockSub.outosSubFlag,
        uuid: outOfStockSub.uuid,
        createdAt: outOfStockSub.createdAt,
        updatedAt: outOfStockSub.updatedAt,
      );

      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: outOfStockSub.toJson(),
      );

      // 2. Parse response with merge support (handles partial responses)
      final outOfStockSubApi = OutOfStockSubApi.fromJsonWithMerge(
        response.data,
        existingOutOfStockSub: baseSub,
      );
      if (outOfStockSubApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update out of stock sub: ${outOfStockSubApi.message}',
        ));
      }

      // 3. Store in local DB (upsert to avoid duplicates)
      final addResult = await upsertOutOfStockProduct(outOfStockSubApi.data);
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

  /// Create multiple out of stock records via API and update local DB
  /// Converted from KMP's reportAllAdmin API call (addOutOfStockAll)
  /// Matches KMP's createOutOfStockAllParams structure
  /// Note: Endpoint doesn't support notification payload, send notifications separately
  Future<Either<Failure, List<OutOfStock>>> createOutOfStockAll({
    required List<OutOfStock> outOfStockMasters,
    required List<OutOfStockSub> outOfStockSubs,
    Map<String, dynamic>? notificationPayload, // Deprecated: endpoint doesn't support it
  }) async {
    try {
      // Build payload matching KMP's createOutOfStockAllParams
      // Note: notificationPayload is ignored as endpoint doesn't support it
      final Map<String, dynamic> payload = {
        'masters': outOfStockMasters.map((master) {
          // Find corresponding sub for this master
          final sub = outOfStockSubs.firstWhere(
            (s) => s.outosSubOrderSubId == master.outosOrderSubId,
            orElse: () => outOfStockSubs.first, // Fallback (shouldn't happen)
          );

          return {
            'outos_order_sub_id': master.outosOrderSubId,
            'outos_cust_id': master.outosCustId,
            'outos_sales_man_id': master.outosSalesManId,
            'outos_stock_keeper_id': master.outosStockKeeperId,
            'outos_date_and_time': master.outosDateAndTime,
            'outos_prod_id': master.outosProdId,
            'outos_unit_id': master.outosUnitId,
            'outos_car_id': master.outosCarId,
            'outos_qty': master.outosQty,
            'outos_available_qty': master.outosAvailableQty,
            'outos_unit_base_qty': master.outosUnitBaseQty,
            'outos_note': '',
            'outos_narration': master.outosNarration ?? '',
            'outos_is_compleated_flag': master.outosIsCompleatedFlag,
            'items': [
              {
                'outos_sub_order_sub_id': sub.outosSubOrderSubId,
                'outos_sub_supp_id': sub.outosSubSuppId,
                'outos_sub_prod_id': sub.outosSubProdId,
                'outos_sub_unit_id': sub.outosSubUnitId,
                'outos_sub_car_id': sub.outosSubCarId,
                'outos_sub_rate': sub.outosSubRate,
                'outos_sub_updated_rate': sub.outosSubUpdatedRate,
                'outos_sub_qty': sub.outosSubQty,
                'outos_sub_available_qty': sub.outosSubAvailableQty,
                'outos_sub_unit_base_qty': sub.outosSubUnitBaseQty,
                'outos_sub_status_flag': 0,
                'outos_sub_is_checked_flag': 0,
                'outos_sub_note': '',
                'outos_sub_narration': sub.outosSubNarration ?? '',
              },
            ],
          };
        }).toList(),
      };

      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addOutOfStockAll,
        data: payload,
      );

      // 2. Parse response
      final outOfStockAllApi = OutOfStockAllApi.fromJson(response.data);
      if (outOfStockAllApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create out of stock: ${outOfStockAllApi.message}',
        ));
      }

      // 3. Store in local DB
      // KMP uses getDBFormatDateTime() when storing from API response (lines 1628-1629)
      // This ensures consistent local timestamps regardless of API response dates
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      for (final outOfStock in outOfStockAllApi.data) {
        // Create updated master with current DB format dates (matching KMP line 1628-1629)
        final masterToStore = OutOfStock(
          id: outOfStock.id,
          outosOrderSubId: outOfStock.outosOrderSubId,
          outosCustId: outOfStock.outosCustId,
          outosSalesManId: outOfStock.outosSalesManId,
          outosStockKeeperId: outOfStock.outosStockKeeperId,
          outosDateAndTime: outOfStock.outosDateAndTime,
          outosProdId: outOfStock.outosProdId,
          outosUnitId: outOfStock.outosUnitId,
          outosCarId: outOfStock.outosCarId,
          outosQty: outOfStock.outosQty,
          outosAvailableQty: outOfStock.outosAvailableQty,
          outosUnitBaseQty: outOfStock.outosUnitBaseQty,
          outosNote: outOfStock.outosNote,
          outosNarration: outOfStock.outosNarration,
          outosIsCompleatedFlag: outOfStock.outosIsCompleatedFlag,
          outosFlag: outOfStock.outosFlag,
          uuid: outOfStock.uuid,
          createdAt: dateTimeStr, // Use current DB format (matching KMP)
          updatedAt: dateTimeStr, // Use current DB format (matching KMP)
          items: outOfStock.items,
        );

        // Store master with isViewed=0 for reportAllAdmin (matching KMP line 1633)
        final addMasterResult = await addOutOfStockMaster(masterToStore, isViewed: 0);
        if (addMasterResult.isLeft) {
          return addMasterResult.map((_) => outOfStockAllApi.data);
        }

        // Add sub items with API dates and isViewed=1 (matching KMP lines 1659-1660, 1664)
        // Note: KMP uses created_at and updated_at from API for sub items (not getDBFormatDateTime)
        if (outOfStock.items != null) {
          for (final sub in outOfStock.items!) {
            // Use API dates for sub items (matching KMP lines 1659-1660)
            final addSubResult = await addOutOfStockProduct(sub, isViewed: 1);
            if (addSubResult.isLeft) {
              return addSubResult.map((_) => outOfStockAllApi.data);
            }
          }
        }
      }

      return Right(outOfStockAllApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Get out of stock products by order sub ID
  /// Converted from KMP's getOrderByOrderSub (OutOfStockProducts.sq)
  /// Returns list of OutOfStockSub for building cancel notification payload
  Future<Either<Failure, List<OutOfStockSub>>> getOutOfStockProductsByOrderSubId(
    int orderSubId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OutOfStockProducts',
        where: 'flag = 1 AND orderSubId = ?',
        whereArgs: [orderSubId],
      );
      final list = maps.map((m) => OutOfStockSub.fromMap(m)).toList();
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update OutOfStockMaster to cancelled when order is cancelled
  /// Converted from KMP's updateToCancelled (OutOfStockMaster.sq)
  Future<Either<Failure, void>> updateMasterToCancelled(int orderSubId) async {
    try {
      final db = await _database;
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await db.update(
        'OutOfStockMaster',
        {'isCompleteflag': 5, 'updatedDateTime': now},
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update OutOfStockProducts to cancelled when order is cancelled
  /// Converted from KMP's oospCancelled/updateToCancelled (OutOfStockProducts.sq)
  Future<Either<Failure, void>> updateProductToCancelled(int orderSubId) async {
    try {
      final db = await _database;
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await db.update(
        'OutOfStockProducts',
        {'oospFlag': 5, 'updatedDateTime': now},
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }
}

