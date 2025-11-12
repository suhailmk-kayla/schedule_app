import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/master_data_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Customers Repository
/// Handles local DB operations and API sync for Customers
/// Converted from KMP's CustomersRepository.kt
class CustomersRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  CustomersRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all customers with names (JOIN with SalesMan and Routes)
  /// Returns CustomerWithNames with salesman and route names
  /// Converted from KMP's getAllCustomers/getAllCustomersForAdmin
  Future<Either<Failure, List<CustomerWithNames>>> getAllCustomers({
    String searchKey = '',
    int routeId = -1,
    bool forAdmin = false,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        if (routeId == -1) {
          // All customers, no route filter
          maps = await db.rawQuery(
            '''
            SELECT c.*, s.name AS saleman, r.name AS route
            FROM Customers AS c
            LEFT JOIN SalesMan s ON c.salesmanId = s.userId
            LEFT JOIN Routes r ON r.routeId = c.routId
            WHERE ${forAdmin ? '1=1' : 'c.flag=1'}
            ORDER BY c.name ASC
            ''',
          );
        } else {
          // Filter by route
          maps = await db.rawQuery(
            '''
            SELECT c.*, s.name AS saleman, r.name AS route
            FROM Customers AS c
            LEFT JOIN SalesMan s ON c.salesmanId = s.userId
            LEFT JOIN Routes r ON r.routeId = c.routId
            WHERE ${forAdmin ? '1=1' : 'c.flag=1'} AND r.routeId = ?
            ORDER BY c.name ASC
            ''',
            [routeId],
          );
        }
      } else {
        // Search with optional route filter
        final searchPattern = '%$searchKey%';
        if (routeId == -1) {
          maps = await db.rawQuery(
            '''
            SELECT c.*, s.name AS saleman, r.name AS route
            FROM Customers AS c
            LEFT JOIN SalesMan s ON c.salesmanId = s.userId
            LEFT JOIN Routes r ON r.routeId = c.routId
            WHERE ${forAdmin ? '1=1' : 'c.flag=1'} AND (
              LOWER(c.name) LIKE LOWER(?) OR 
              LOWER(c.code) LIKE LOWER(?) OR 
              LOWER(s.name) LIKE LOWER(?) OR 
              LOWER(r.name) LIKE LOWER(?)
            )
            ORDER BY c.name ASC
            ''',
            [searchPattern, searchPattern, searchPattern, searchPattern],
          );
        } else {
          maps = await db.rawQuery(
            '''
            SELECT c.*, s.name AS saleman, r.name AS route
            FROM Customers AS c
            LEFT JOIN SalesMan s ON c.salesmanId = s.userId
            LEFT JOIN Routes r ON r.routeId = c.routId
            WHERE ${forAdmin ? '1=1' : 'c.flag=1'} AND (
              LOWER(c.name) LIKE LOWER(?) OR 
              LOWER(c.code) LIKE LOWER(?) OR 
              LOWER(s.name) LIKE LOWER(?) OR 
              LOWER(r.name) LIKE LOWER(?)
            ) AND r.routeId = ?
            ORDER BY c.name ASC
            ''',
            [searchPattern, searchPattern, searchPattern, searchPattern, routeId],
          );
        }
      }

      final customers = maps.map((map) => CustomerWithNames.fromMap(map)).toList();
      return Right(customers);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get customer by ID
  Future<Either<Failure, Customer?>> getCustomerById(int customerId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.rawQuery(
        '''
        SELECT c.*, s.name AS saleman, r.name AS route
        FROM Customers AS c
        LEFT JOIN SalesMan s ON c.salesmanId = s.userId
        LEFT JOIN Routes r ON r.routeId = c.routId
        WHERE c.customerId = ?
        ORDER BY c.name ASC
        LIMIT 1
        ''',
        [customerId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final customer = Customer.fromMap(maps.first);
      return Right(customer);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get customer by code
  Future<Either<Failure, List<Customer>>> getCustomerByCode(String code) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Customers',
        where: 'code = ?',
        whereArgs: [code],
        orderBy: 'name ASC',
      );

      final customers = maps.map((map) => Customer.fromMap(map)).toList();
      return Right(customers);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get customer by code excluding specific customer ID
  Future<Either<Failure, List<Customer>>> getCustomerByCodeWithId({
    required String code,
    required int customerId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Customers',
        where: 'code = ? AND customerId != ?',
        whereArgs: [code, customerId],
        orderBy: 'name ASC',
      );

      final customers = maps.map((map) => Customer.fromMap(map)).toList();
      return Right(customers);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted customer
  Future<Either<Failure, Customer?>> getLastEntry() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'Customers',
        orderBy: 'customerId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final customer = Customer.fromMap(maps.first);
      return Right(customer);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single customer to local DB
  Future<Either<Failure, void>> addCustomer(Customer customer) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Customers',
        customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple customers to local DB (transaction)
  Future<Either<Failure, void>> addCustomers(List<Customer> customers) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final customer in customers) {
          await txn.insert(
            'Customers',
            customer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update customer flag
  Future<Either<Failure, void>> updateCustomerFlag({
    required int customerId,
    required int flag,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'Customers',
        {'flag': flag},
        where: 'customerId = ?',
        whereArgs: [customerId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all customers from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('Customers');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync customers from API (batch download)
  Future<Either<Failure, CustomerListApi>> syncCustomersFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.customerDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );

      final customerListApi = CustomerListApi.fromJson(response.data);
      return Right(customerListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create customer via API and update local DB
  Future<Either<Failure, Customer>> createCustomer(Customer customer) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addCustomer,
        data: customer.toJson(),
      );

      // 2. Parse response
      final customerSuccessApi = CustomerSuccessApi.fromJson(response.data);
      if (customerSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create customer: ${customerSuccessApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addCustomer(customerSuccessApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => customerSuccessApi.data);
      }

      return Right(customerSuccessApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update customer via API and update local DB
  Future<Either<Failure, Customer>> updateCustomer(Customer customer) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateCustomer,
        data: customer.toJson(),
      );

      // 2. Parse response
      final customerSuccessApi = CustomerSuccessApi.fromJson(response.data);
      if (customerSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update customer: ${customerSuccessApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addCustomer(customerSuccessApi.data);
      if (addResult.isLeft) {
        return addResult.map((_) => customerSuccessApi.data);
      }

      return Right(customerSuccessApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

