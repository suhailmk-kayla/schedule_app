import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/order_api.dart';
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
      String whereClause = 'flag > 0 AND flag != 2';
      List<dynamic> whereArgs = [];

      if (salesmanId != null) {
        whereClause += ' AND salesmanId = ?';
        whereArgs.add(salesmanId);
      }

      if (routeId != -1) {
        // Need to join with Customers and Routes
        maps = await db.rawQuery(
          '''
          SELECT Orders.* FROM Orders
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
          orderBy: 'orderId',
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
        orderBy: 'orderId DESC',
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
        orderBy: 'orderId DESC',
        limit: 1,
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
  Future<Either<Failure, void>> addOrder(Order order) async {
    try {
      final db = await _database;
      await db.insert(
        'Orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple orders to local DB (transaction)
  Future<Either<Failure, void>> addOrders(List<Order> orders) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final order in orders) {
          batch.insert(
            'Orders',
            order.toMap(),
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

  /// Add single order sub to local DB
  Future<Either<Failure, void>> addOrderSub(OrderSub orderSub) async {
    try {
      final db = await _database;
      await db.insert(
        'OrderSub',
        orderSub.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
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
        final batch = txn.batch();
        for (final orderSub in orderSubs) {
          batch.insert(
            'OrderSub',
            orderSub.toMap(),
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
  Future<Either<Failure, OrderListApi>> syncOrdersFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.orderDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final orderListApi = OrderListApi.fromJson(response.data);
      return Right(orderListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Sync order subs from API (batch download)
  Future<Either<Failure, OrderSubListApi>> syncOrderSubsFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.orderSubDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
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
}

