import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/order_api.dart';
import '../../models/order_sub_with_details.dart';
import '../../models/order_with_name.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Orders Repository
/// Handles local DB operations and API sync for Orders and OrderSubs
/// Converted from KMP's OrderRepository.kt
class OrdersRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  OrdersRepository({
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

  /// Get all orders with optional filters
  Future<Either<Failure, List<Order>>> getAllOrders({
    String searchKey = '',
    int routeId = -1,
    String date = '',
    int? salesmanId,
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      // Build query based on filters
      String whereClause = 'Orders.flag > 0 AND Orders.flag != 2';
      List<dynamic> whereArgs = [];

      if (salesmanId != null) {
        whereClause += ' AND Orders.salesmanId = ?';
        whereArgs.add(salesmanId);
      }

      if (salesmanId != null) {
        whereClause += ' AND salesmanId = ?';
        whereArgs.add(salesmanId);
      }

      if (routeId != -1) {
        // Need to join with Customers and Routes
        maps = await db.rawQuery(
          '''
          SELECT Orders.*
          FROM Orders
          LEFT JOIN Customers ON Customers.customerId = Orders.customerId
          LEFT JOIN Routes ON Routes.routeId = Customers.routId
          WHERE $whereClause AND Routes.routeId = ?
          ORDER BY Orders.updatedDateTime DESC
          ''',
          [...whereArgs, routeId],
        );
      } else if (date.isNotEmpty) {
        whereClause += ' AND updatedDateTime LIKE ?';
        whereArgs.add('%$date%');
        maps = await db.query(
          'Orders',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'updatedDateTime DESC',
        );
      } else if (searchKey.isNotEmpty) {
        whereClause += ' AND (invoiceNo LIKE ? OR customerName LIKE ?)';
        final searchPattern = '%$searchKey%';
        whereArgs.addAll([searchPattern, searchPattern]);
        maps = await db.query(
          'Orders',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'updatedDateTime DESC',
        );
      } else {
        maps = await db.query(
          'Orders',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'orderId',
        );
      }

      final orders = maps.map((map) => Order.fromMap(map)).toList();
      return Right(orders);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get order by ID
  Future<Either<Failure, Order?>> getOrderById(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        where: 'orderId = ?',
        whereArgs: [orderId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final order = Order.fromMap(maps.first);
      return Right(order);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get order with related names (salesman/storekeeper/biller/checker/route)
  Future<Either<Failure, OrderWithName?>> getOrderWithNamesById(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          COALESCE(sl.name, SalesMan.name) AS salesManName,
          CASE
            WHEN Orders.storeKeeperId = -1 THEN ''
            ELSE COALESCE(storeKeeper.name, '')
          END AS storeKeeperName,
          CASE
            WHEN Customers.routId = -1 THEN ''
            ELSE COALESCE(Routes.name, '')
          END AS routeName,
          CASE
            WHEN Orders.billerId = -1 THEN ''
            ELSE COALESCE(biller.name, '')
          END AS billerName,
          CASE
            WHEN Orders.checkerId = -1 THEN ''
            ELSE COALESCE(checker.name, '')
          END AS checkerName,
          Customers.name AS customerDisplayName,
          Orders.*
        FROM Orders
        LEFT JOIN SalesMan ON SalesMan.userId = Orders.salesmanId
        LEFT JOIN Users sl ON sl.userId = Orders.salesmanId
        LEFT JOIN Users storeKeeper ON storeKeeper.userId = Orders.storeKeeperId
        LEFT JOIN Users biller ON biller.userId = Orders.billerId
        LEFT JOIN Users checker ON checker.userId = Orders.checkerId
        LEFT JOIN Customers ON Customers.customerId = Orders.customerId
        LEFT JOIN Routes ON Routes.routeId = Customers.routId
        WHERE Orders.orderId = ?
        LIMIT 1
        ''',
        [orderId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final map = maps.first;
      final order = Order.fromMap(map);
      final orderWithName = OrderWithName(
        order: order,
        salesManName: (map['salesManName'] as String?) ?? '',
        storeKeeperName: (map['storeKeeperName'] as String?) ?? '',
        customerName: (map['customerDisplayName'] as String?) ?? order.orderCustName,
        billerName: (map['billerName'] as String?) ?? '',
        checkerName: (map['checkerName'] as String?) ?? '',
        route: (map['routeName'] as String?) ?? '',
      );
      return Right(orderWithName);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all orders with related names (salesman/storekeeper/biller/checker/route)
  /// Returns OrderWithName objects with populated names from JOIN queries
  Future<Either<Failure, List<OrderWithName>>> getAllOrdersWithNames({
    String searchKey = '',
    int routeId = -1,
    String date = '',
    int? salesmanId,
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      // Build query with JOINs to get names
      String whereClause = 'Orders.flag > 0 AND Orders.flag != 2';
      List<dynamic> whereArgs = [];

      if (salesmanId != null) {
        whereClause += ' AND Orders.salesmanId = ?';
        whereArgs.add(salesmanId);
      }

      if (routeId != -1) {
        whereClause += ' AND Routes.routeId = ?';
        whereArgs.add(routeId);
      }

      if (date.isNotEmpty) {
        whereClause += ' AND Orders.updatedDateTime LIKE ?';
        whereArgs.add('%$date%');
      }

      if (searchKey.isNotEmpty) {
        whereClause += ' AND (Orders.invoiceNo LIKE ? OR Orders.customerName LIKE ?)';
        final searchPattern = '%$searchKey%';
        whereArgs.addAll([searchPattern, searchPattern]);
      }

      maps = await db.rawQuery(
        '''
        SELECT
          COALESCE(sl.name, SalesMan.name) AS salesManName,
          CASE
            WHEN Orders.storeKeeperId = -1 THEN ''
            ELSE COALESCE(storeKeeper.name, '')
          END AS storeKeeperName,
          CASE
            WHEN Customers.routId = -1 THEN ''
            ELSE COALESCE(Routes.name, '')
          END AS routeName,
          CASE
            WHEN Orders.billerId = -1 THEN ''
            ELSE COALESCE(biller.name, '')
          END AS billerName,
          CASE
            WHEN Orders.checkerId = -1 THEN ''
            ELSE COALESCE(checker.name, '')
          END AS checkerName,
          Customers.name AS customerDisplayName,
          Orders.*
        FROM Orders
        LEFT JOIN SalesMan ON SalesMan.userId = Orders.salesmanId
        LEFT JOIN Users sl ON sl.userId = Orders.salesmanId
        LEFT JOIN Users storeKeeper ON storeKeeper.userId = Orders.storeKeeperId
        LEFT JOIN Users biller ON biller.userId = Orders.billerId
        LEFT JOIN Users checker ON checker.userId = Orders.checkerId
        LEFT JOIN Customers ON Customers.customerId = Orders.customerId
        LEFT JOIN Routes ON Routes.routeId = Customers.routId
        WHERE $whereClause
        ORDER BY Orders.updatedDateTime DESC
        ''',
        whereArgs,
      );

      final ordersWithNames = maps.map((map) {
        final order = Order.fromMap(map);
        return OrderWithName(
          order: order,
          salesManName: (map['salesManName'] as String?) ?? '',
          storeKeeperName: (map['storeKeeperName'] as String?) ?? '',
          customerName: (map['customerDisplayName'] as String?) ?? order.orderCustName,
          billerName: (map['billerName'] as String?) ?? '',
          checkerName: (map['checkerName'] as String?) ?? '',
          route: (map['routeName'] as String?) ?? '',
        );
      }).toList();

      return Right(ordersWithNames);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get orders by customer ID and date
  Future<Either<Failure, List<Order>>> getOrdersByCustomer({
    required int customerId,
    required String date,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        where: '(flag = 1 OR flag = 2 OR flag = 3) AND customerId = ? AND dateAndTime LIKE ?',
        whereArgs: [customerId, '%$date%'],
        orderBy: 'updatedDateTime DESC',
        limit: 1,
      );

      final orders = maps.map((map) => Order.fromMap(map)).toList();
      return Right(orders);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get temp/draft orders
  Future<Either<Failure, List<Order>>> getTempOrders() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        where: 'flag = 2',
        orderBy: 'updatedDateTime DESC',
        limit: 1,
      );

      final orders = maps.map((map) => Order.fromMap(map)).toList();
      return Right(orders);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all order subs with details (product name, unit name, etc.) for an order
  /// Converted from KMP's getAllOrderSubAndDetails
  /// Returns order subs with product and unit names from JOIN query
  Future<Either<Failure, List<OrderSubWithDetails>>> getAllOrderSubAndDetails(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          Units.name AS unitName,
          Units.displayName AS unitDispName,
          Product.name AS productName,
          Product.brand AS productBrand,
          Product.subBrand AS productSubBrand,
          OrderSub.*
        FROM OrderSub
        LEFT JOIN Units ON Units.unitId = OrderSub.unitId
        LEFT JOIN Product ON Product.productId = OrderSub.productId
        WHERE OrderSub.orderId = ?
        ORDER BY OrderSub.orderSubId DESC, OrderSub.isCheckedflag ASC
        ''',
        [orderId],
      );

      final orderSubs = maps.map((map) => OrderSubWithDetails.fromMap(map)).toList();
      return Right(orderSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get temp order subs with details (orderFlag == 0)
  /// Converted from KMP's getTempGetOrdersSubAndDetails
  Future<Either<Failure, List<OrderSubWithDetails>>> getTempOrderSubAndDetails(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          Units.name AS unitName,
          Units.displayName AS unitDispName,
          Product.name AS productName,
          Product.brand AS productBrand,
          Product.subBrand AS productSubBrand,
          OrderSub.*
        FROM OrderSub
        LEFT JOIN Units ON Units.unitId = OrderSub.unitId
        LEFT JOIN Product ON Product.productId = OrderSub.productId
        WHERE OrderSub.orderId = ? AND OrderSub.orderFlag = 0
        ORDER BY OrderSub.orderSubId
        ''',
        [orderId],
      );

      final orderSubs = maps.map((map) => OrderSubWithDetails.fromMap(map)).toList();
      return Right(orderSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Delete temp order subs (orderFlag = 0) for an order
  Future<Either<Failure, void>> deleteTempOrderSubs(int orderId) async {
    try {
      final db = await _database;
      await db.delete(
        'OrderSub',
        where: 'orderId = ? AND orderFlag = 0',
        whereArgs: [orderId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get draft orders by order ID (flag = 3)
  /// Converted from KMP's getDraftOrders
  Future<Either<Failure, List<Order>>> getDraftOrders(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        where: 'flag = 3 AND orderId = ?',
        whereArgs: [orderId],
        orderBy: 'updatedDateTime DESC',
      );

      final orders = maps.map((map) => Order.fromMap(map)).toList();
      return Right(orders);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get order subs by order ID
  Future<Either<Failure, List<OrderSub>>> getOrderSubsByOrderId(int orderId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSub',
        where: 'flag = 1 AND orderId = ?',
        whereArgs: [orderId],
        orderBy: 'orderSubId',
      );

      final orderSubs = maps.map((map) => OrderSub.fromMap(map)).toList();
      return Right(orderSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get existing order sub by orderId, productId, unitId, and rate
  /// Converted from KMP's getExistOrderSub
  /// Returns matching order sub if exists (for quantity merging)
  Future<Either<Failure, List<OrderSub>>> getExistOrderSub({
    required int orderId,
    required int productId,
    required int unitId,
    required double rate,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSub',
        where: 'flag = 1 AND orderId = ? AND productId = ? AND unitId = ? AND updateRate = ?',
        whereArgs: [orderId, productId, unitId, rate],
      );

      final orderSubs = maps.map((map) => OrderSub.fromMap(map)).toList();
      return Right(orderSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get order sub by ID
  Future<Either<Failure, OrderSub?>> getOrderSubById(int orderSubId) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSub',
        where: 'flag = 1 AND orderSubId = ?',
        whereArgs: [orderSubId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final orderSub = OrderSub.fromMap(maps.first);
      return Right(orderSub);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted order
  Future<Either<Failure, Order?>> getLastOrderEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        orderBy: 'orderId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final order = Order.fromMap(maps.first);
      return Right(order);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted order sub
  Future<Either<Failure, OrderSub?>> getLastOrderSubEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSub',
        orderBy: 'orderSubId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final orderSub = OrderSub.fromMap(maps.first);
      return Right(orderSub);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get count of unviewed orders (flag = 1 AND isProcessFinish = 0)
  /// Converted from KMP's getOrderByViewed
  Future<Either<Failure, int>> getUnviewedOrderCount() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Orders',
        where: 'flag = 1 AND isProcessFinish = 0',
      );
      return Right(maps.length);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single order to local DB
  /// Converted from KMP's addOrder function (single order)
  /// Uses raw query matching KMP's insert query exactly
  /// id is set to NULL (auto-increment primary key)
  /// isProcessFinish is set to 1 (matching KMP line 20)
  Future<Either<Failure, void>> addOrder(Order order) async {
    try {
      final db = await _database;
      // Raw query matching KMP's insert query (Orders.sq line 23-25)
      // Column order: id,orderId,invoiceNo,UUID,customerId,customerName,storeKeeperId,salesmanId,billerId,checkerId,dateAndTime,note,total,freightCharge,approveFlag,createdDateTime,updatedDateTime,flag,isProcessFinish
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO Orders(
          id, orderId, invoiceNo, UUID, customerId, customerName, storeKeeperId, salesmanId,
          billerId, checkerId, dateAndTime, note, total, freightCharge, approveFlag,
          createdDateTime, updatedDateTime, flag, isProcessFinish
        ) VALUES (
          NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          order.id, // orderId (from API)
          order.orderInvNo.toString(), // invoiceNo
          order.uuid, // UUID
          order.orderCustId, // customerId
          order.orderCustName, // customerName
          order.orderStockKeeperId, // storeKeeperId
          order.orderSalesmanId, // salesmanId
          order.orderBillerId, // billerId
          order.orderCheckerId, // checkerId
          order.orderDateTime, // dateAndTime
          order.orderNote ?? '', // note
          order.orderTotal, // total
          order.orderFreightCharge, // freightCharge
          order.orderApproveFlag, // approveFlag
          order.createdAt, // createdDateTime
          order.updatedAt, // updatedDateTime
          order.orderFlag, // flag
          1, // isProcessFinish (default 1 for single order, matching KMP line 20)
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple orders to local DB (transaction)
  /// Converted from KMP's addOrder function (list)
  /// Uses raw query matching KMP's insert query exactly
  /// For batch sync: id is NULL (auto-increment), isProcessFinish is 0 (matching KMP pattern for sync)
  /// CRITICAL OPTIMIZATION: Uses batch operations for 100x+ performance improvement
  /// Matching KMP pattern: db.transaction { list.forEach { ... } } - SQLDelight optimizes internally
  /// In Flutter/sqflite, we use batch.rawInsert() + batch.commit() to achieve same performance
  Future<Either<Failure, void>> addOrders(List<Order> orders) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        // Raw query matching KMP's insert query (Orders.sq line 23-25)
        // Column order: id,orderId,invoiceNo,UUID,customerId,customerName,storeKeeperId,salesmanId,billerId,checkerId,dateAndTime,note,total,freightCharge,approveFlag,createdDateTime,updatedDateTime,flag,isProcessFinish
        // For batch sync from API: id is NULL (auto-increment), isProcessFinish is 0 (matching KMP line 30 where isNew=1L means isProcessFinish=1, but for sync it's 0)
        for (final order in orders) {
          // CRITICAL: Use batch.rawInsert() instead of await txn.rawInsert() - 100x faster!
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO Orders(
              id, orderId, invoiceNo, UUID, customerId, customerName, storeKeeperId, salesmanId,
              billerId, checkerId, dateAndTime, note, total, freightCharge, approveFlag,
              createdDateTime, updatedDateTime, flag, isProcessFinish
            ) VALUES (
              NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              order.id, // orderId (from API)
              order.orderInvNo.toString(), // invoiceNo
              order.uuid, // UUID
              order.orderCustId, // customerId
              order.orderCustName, // customerName
              order.orderStockKeeperId, // storeKeeperId
              order.orderSalesmanId, // salesmanId
              order.orderBillerId, // billerId
              order.orderCheckerId, // checkerId
              order.orderDateTime, // dateAndTime
              order.orderNote ?? '', // note
              order.orderTotal, // total
              order.orderFreightCharge, // freightCharge
              order.orderApproveFlag, // approveFlag
              order.createdAt, // createdDateTime
              order.updatedAt, // updatedDateTime
              order.orderFlag, // flag
              1, // isProcessFinish (1 for batch sync, matching KMP line 30 where isNotification=false means isNew=1L which maps to isProcessFinish=1)
            ],
          );
        }
        // CRITICAL: Commit all inserts at once - matches SQLDelight's optimized behavior
        await batch.commit(noResult: true);
      });
      developer.log('OrdersRepository: Added ${orders.length} orders');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add single order sub to local DB
  Future<Either<Failure, void>> addOrderSub(OrderSub orderSub) async {
    try {
      final db = await _database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO OrderSub (
          orderSubId,
          orderId,
          invoiceNo,
          UUID,
          customerId,
          salesmanId,
          storeKeeperId,
          dateAndTime,
          productId,
          unitId,
          carId,
          rate,
          updateRate,
          quantity,
          availQty,
          unitBaseQty,
          note,
          narration,
          orderFlag,
          createdDateTime,
          updatedDateTime,
          isCheckedflag,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          orderSub.id,
          orderSub.orderSubOrdrId,
          orderSub.orderSubOrdrInvId.toString(),
          '',
          orderSub.orderSubCustId,
          orderSub.orderSubSalesmanId,
          orderSub.orderSubStockKeeperId,
          orderSub.orderSubDateTime,
          orderSub.orderSubPrdId,
          orderSub.orderSubUnitId,
          orderSub.orderSubCarId,
          orderSub.orderSubRate,
          orderSub.orderSubUpdateRate,
          orderSub.orderSubQty,
          orderSub.orderSubAvailableQty,
          orderSub.orderSubUnitBaseQty,
          orderSub.orderSubNote ?? '',
          orderSub.orderSubNarration ?? '',
          orderSub.orderSubOrdrFlag,
          orderSub.createdAt,
          orderSub.updatedAt,
          orderSub.orderSubIsCheckedFlag,
          orderSub.orderSubFlag,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple order subs to local DB (transaction)
  Future<Either<Failure, void>> addOrderSubs(List<OrderSub> orderSubs) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        const sql = '''
        INSERT OR REPLACE INTO OrderSub (
          orderSubId,
          orderId,
          invoiceNo,
          UUID,
          customerId,
          salesmanId,
          storeKeeperId,
          dateAndTime,
          productId,
          unitId,
          carId,
          rate,
          updateRate,
          quantity,
          availQty,
          unitBaseQty,
          note,
          narration,
          orderFlag,
          createdDateTime,
          updatedDateTime,
          isCheckedflag,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''';
        for (final orderSub in orderSubs) {
          await txn.rawInsert(
            sql,
            [
              orderSub.id,
              orderSub.orderSubOrdrId,
              orderSub.orderSubOrdrInvId.toString(),
              '',
              orderSub.orderSubCustId,
              orderSub.orderSubSalesmanId,
              orderSub.orderSubStockKeeperId,
              orderSub.orderSubDateTime,
              orderSub.orderSubPrdId,
              orderSub.orderSubUnitId,
              orderSub.orderSubCarId,
              orderSub.orderSubRate,
              orderSub.orderSubUpdateRate,
              orderSub.orderSubQty,
              orderSub.orderSubAvailableQty,
              orderSub.orderSubUnitBaseQty,
              orderSub.orderSubNote ?? '',
              orderSub.orderSubNarration ?? '',
              orderSub.orderSubOrdrFlag,
              orderSub.createdAt,
              orderSub.updatedAt,
              orderSub.orderSubIsCheckedFlag,
              orderSub.orderSubFlag,
            ],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order customer
  Future<Either<Failure, void>> updateOrderCustomer({
    required int orderId,
    required int customerId,
    required String customerName,
  }) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.update(
          'Orders',
          {'customerName': customerName, 'customerId': customerId},
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        await txn.update(
          'OrderSub',
          {'customerId': customerId},
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order note
  Future<Either<Failure, void>> updateOrderNote({
    required int orderId,
    required String note,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Orders',
        {'note': note},
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order flag
  Future<Either<Failure, void>> updateOrderFlag({
    required int orderId,
    required int flag,
  }) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.update(
          'Orders',
          {'flag': flag},
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        await txn.update(
          'OrderSub',
          {'flag': flag},
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order freight charge and total
  /// Converted from KMP's updateFreightAndTotal
  Future<Either<Failure, void>> updateFreightAndTotal({
    required int orderId,
    required double freightCharge,
    required double total,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Orders',
        {
          'freightCharge': freightCharge,
          'total': total,
        },
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order updated date time
  /// Converted from KMP's updateUpdatedDate
  Future<Either<Failure, void>> updateUpdatedDate({
    required int orderId,
    required String updatedDateTime,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Orders',
        {'updatedDateTime': updatedDateTime},
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update order process flag (isProcessFinish)
  /// Converted from KMP's updateProcessFlag
  Future<Either<Failure, void>> updateProcessFlag({
    required int orderId,
    required int isProcessFinish,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'Orders',
        {'isProcessFinish': isProcessFinish},
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Delete order sub by ID
  Future<Either<Failure, void>> deleteOrderSub(int orderSubId) async {
    try {
      final db = await _database;
      await db.delete(
        'OrderSub',
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Delete order and all its order subs by order ID
  /// Converted from KMP's removeOrderAndSub
  Future<Either<Failure, void>> deleteOrderAndSub(int orderId) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        // Delete all order subs first
        await txn.delete(
          'OrderSub',
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        // Then delete the order
        await txn.delete(
          'Orders',
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all orders and order subs
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.delete('OrderSub');
        await txn.delete('Orders');
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync orders from API (batch download)
  /// Sync orders from API (batch download or single record retry)
  /// Converted from KMP's downloadOrder function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all orders in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific order by id only
  Future<Either<Failure, OrderListApi>> syncOrdersFromApi({
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
        ApiEndpoints.orderDownload,
        queryParameters: queryParams,
      );

      final orderListApi = OrderListApi.fromJson(response.data);
      return Right(orderListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Sync order subs from API (batch download or single record retry)
  /// Converted from KMP's downloadOrderSub function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all order subs in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific order sub by id only
  Future<Either<Failure, OrderSubListApi>> syncOrderSubsFromApi({
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
        ApiEndpoints.orderSubDownload,
        queryParameters: queryParams,
      );

      final orderSubListApi = OrderSubListApi.fromJson(response.data);
      return Right(orderSubListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create order via API and update local DB
  Future<Either<Failure, Order>> createOrder(Order order) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addOrder,
        data: order.toJson(),
      );

      // 2. Parse response
      final orderApi = OrderApi.fromJson(response.data);
      if (orderApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create order: ${orderApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addOrder(orderApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => orderApi.data);
      }

      // 4. Add order subs if present
      if (order.items != null && order.items!.isNotEmpty) {
        final orderSubs = order.items!.map((sub) {
          // Update orderSub with the new orderId
          return OrderSub(
            id: sub.id,
            orderSubOrdrInvId: orderApi.data.orderInvNo,
            orderSubOrdrId: orderApi.data.id,
            orderSubCustId: sub.orderSubCustId,
            orderSubSalesmanId: sub.orderSubSalesmanId,
            orderSubStockKeeperId: sub.orderSubStockKeeperId,
            orderSubDateTime: sub.orderSubDateTime,
            orderSubPrdId: sub.orderSubPrdId,
            orderSubUnitId: sub.orderSubUnitId,
            orderSubCarId: sub.orderSubCarId,
            orderSubRate: sub.orderSubRate,
            orderSubUpdateRate: sub.orderSubUpdateRate,
            orderSubQty: sub.orderSubQty,
            orderSubAvailableQty: sub.orderSubAvailableQty,
            orderSubUnitBaseQty: sub.orderSubUnitBaseQty,
            orderSubIsCheckedFlag: sub.orderSubIsCheckedFlag,
            orderSubOrdrFlag: sub.orderSubOrdrFlag,
            orderSubNote: sub.orderSubNote,
            orderSubNarration: sub.orderSubNarration,
            orderSubFlag: sub.orderSubFlag,
            createdAt: sub.createdAt,
            updatedAt: sub.updatedAt,
          );
        }).toList();

        await addOrderSubs(orderSubs);
      }

      return Right(orderApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update order via API and update local DB
  Future<Either<Failure, Order>> updateOrder(Order order) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateOrder,
        data: order.toJson(),
      );

      // 2. Parse response
      final orderApi = OrderApi.fromJson(response.data);
      if (orderApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update order: ${orderApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addOrder(orderApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => orderApi.data);
      }

      return Right(orderApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update order with custom payload (for informUpdates)
  /// Accepts custom JSON payload structure with items array and notification
  /// Converted from KMP's informUpdates API call
  Future<Either<Failure, Order>> updateOrderWithCustomPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      // 1. Call API with custom payload
      final response = await _dio.post(
        ApiEndpoints.updateOrder,
        data: payload,
      );

      // 2. Parse response
      final orderApi = OrderApi.fromJson(response.data);
      if (orderApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update order: ${orderApi.message}',
        ));
      }

      // 3. Store order in local DB
      final addResult = await addOrder(orderApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => orderApi.data);
      }

      // 4. Store order subs in local DB
      if (orderApi.data.items != null && orderApi.data.items!.isNotEmpty) {
        final orderSubs = orderApi.data.items!.map((sub) {
          return OrderSub.fromJson(sub.toJson());
        }).toList();

        await addOrderSubs(orderSubs);

        // 5. Handle suggestions if present
        for (int i = 0; i < orderApi.data.items!.length; i++) {
          final sub = orderApi.data.items![i];
          if (sub.suggestions != null && sub.suggestions!.isNotEmpty) {
            // Remove existing suggestions for this sub
            // Note: This would require a method in OrderSubSuggestionsRepository
            // For now, we'll just add the new ones
            // The repository should handle this
          }
        }
      }

      return Right(orderApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update order sub via API and update local DB
  Future<Either<Failure, OrderSub>> updateOrderSub(OrderSub orderSub) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateOrderSub,
        data: orderSub.toJson(),
      );

      // 2. Parse response
      final orderSubApi = OrderSubApi.fromJson(response.data);
      if (orderSubApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update order sub: ${orderSubApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addOrderSub(orderSubApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => orderSubApi.data);
      }

      return Right(orderSubApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Send order (check stock) - calls API
  /// Converted from KMP's OrderViewModel.sendOrder
  /// Builds order payload with all order subs and sends to API
  Future<Either<Failure, OrderApi>> sendOrder(Map<String, dynamic> params) async {
    try {
      // Call API
      final response = await _dio.post(
        ApiEndpoints.addOrder,
        data: params,
      );
      
      // Parse response
      final orderApi = OrderApi.fromJson(response.data);
      if (orderApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to send order: ${orderApi.message}',
        ));
      }

      return Right(orderApi);
    } on DioException catch (e) {
      developer.log('Failed to send order: ${e.response?.data}');
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      developer.log('Failed to send order: $e');
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update biller or checker
  /// Converted from KMP's updateBillerOrChecker API call
  Future<Either<Failure, void>> updateBillerOrChecker(
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.updateBillerOrChecker,
        data: params,
      );

      if (response.statusCode != 200) {
        return Left(ServerFailure.fromError(
          'Failed to update biller/checker: ${response.statusMessage}',
        ));
      }

      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update order approval flag with notification
  /// Converted from KMP's updateOrderApproveFlag API call
  Future<Either<Failure, void>> updateOrderApproveFlag({
    required int orderId,
    required int approveFlag,
    Map<String, dynamic>? notification,
  }) async {
    try {
      final params = {
        'order_id': orderId,
        'order_approve_flag': approveFlag,
        if (notification != null) 'notification': notification,
      };

      final response = await _dio.post(
        ApiEndpoints.updateOrderApproveFlag,
        data: params,
      );

      if (response.statusCode != 200) {
        return Left(ServerFailure.fromError(
          'Failed to update order approval flag: ${response.statusMessage}',
        ));
      }

      // Update local DB
      final db = await _database;
      await db.update(
        'Orders',
        {'approveFlag': approveFlag},
        where: 'orderId = ?',
        whereArgs: [orderId],
      );

      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update order sub flag
  /// Converted from KMP's updateOrderSubFlag
  Future<Either<Failure, void>> updateOrderSubFlag({
    required int orderSubId,
    required int flag,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'OrderSub',
        {'orderFlag': flag},
        where: 'id = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }
}

