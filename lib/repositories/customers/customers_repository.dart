import 'dart:developer' as developer;

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
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  CustomersRepository({
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

  /// Get all customers with names (JOIN with SalesMan and Routes)
  /// Returns CustomerWithNames with salesman and route names
  /// Converted from KMP's getAllCustomers/getAllCustomersForAdmin
  Future<Either<Failure, List<CustomerWithNames>>> getAllCustomers({
    String searchKey = '',
    int routeId = -1,
    bool forAdmin = false,
  }) async {
    try {
      final db = await _database;
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
      final db = await _database;
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
      final db = await _database;
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
      final db = await _database;
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
      final db = await _database;
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

Future<Either<Failure, void>> editCustomer(Customer customer) async {
  try {
    final db = await _database;

    // Manually create the map of fields to update
    final Map<String, Object?> updateMap = {
      'code': customer.code,
      'name': customer.name,
      'phone': customer.phoneNo,
      'address': customer.address,
      'routId': customer.routId,
      'salesmanId': customer.salesManId,
      'rating': customer.rating,
      'deviceToken': '', // or keep existing if needed
      'createdDateTime': customer.createdAt ?? '',
      'updatedDateTime': customer.updatedAt ?? '',
      'flag': customer.flag ?? 1,
    };

    // Update using SDK method
    await db.update(
      'Customers',
      updateMap,
      where: 'customerId = ?',
      whereArgs: [customer.customerId], // Use API ID
    );

    return const Right(null);
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
      final db = await _database;
      await db.rawInsert(
        '''
        INSERT INTO Customers (
          customerId,
          code,
          name,
          phone,
          address,
          routId,
          salesmanId,
          rating,
          deviceToken,
          createdDateTime,
          updatedDateTime,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          customer.customerId,
          customer.code,
          customer.name,
          customer.phoneNo,
          customer.address,
          customer.routId,
          customer.salesManId,
          customer.rating,
          '',
          customer.createdAt ?? '',
          customer.updatedAt ?? '',
          customer.flag ?? 1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update customer in local DB
  /// Preserves deviceToken and createdDateTime from existing record
  Future<Either<Failure, void>> updateCustomerLocal(Customer customer) async {
    try {
      final db = await _database;

      // Get existing deviceToken and createdDateTime to preserve them
      final existingMap = await db.query(
        'Customers',
        columns: ['deviceToken', 'createdDateTime'],
        where: 'customerId = ?',
        whereArgs: [customer.customerId],
        limit: 1,
      );

      final deviceToken = existingMap.isNotEmpty 
          ? (existingMap.first['deviceToken'] as String? ?? '')
          : '';
      
      final createdDateTime = existingMap.isNotEmpty
          ? (existingMap.first['createdDateTime'] as String? ?? customer.createdAt ?? '')
          : (customer.createdAt ?? '');

      // Update with merged customer data, preserving deviceToken and createdDateTime
      await db.update(
        'Customers',
        {
          'code': customer.code,
          'name': customer.name,
          'phone': customer.phoneNo,
          'address': customer.address,
          'routId': customer.routId,
          'salesmanId': customer.salesManId,
          'rating': customer.rating,
          'deviceToken': deviceToken, // Preserve existing deviceToken
          'createdDateTime': createdDateTime, // Preserve existing createdDateTime
          'updatedDateTime': customer.updatedAt ?? '',
          'flag': customer.flag ?? 1,
        },
        where: 'customerId = ?',
        whereArgs: [customer.customerId],
      );

      return const Right(null);
    } catch (e) {
      developer.log('updateCustomerLocal error: $e');
      return Left(DatabaseFailure.fromError(e));
    }
  }


  /// Add multiple customers to local DB (transaction)
  Future<Either<Failure, void>> addCustomers(List<Customer> customers) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        const sql = '''
        INSERT INTO Customers (
          customerId,
          code,
          name,
          phone,
          address,
          routId,
          salesmanId,
          rating,
          deviceToken,
          createdDateTime,
          updatedDateTime,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''';
        for (final customer in customers) {
          await txn.rawInsert(
            sql,
            [
              customer.customerId,
              customer.code,
              customer.name,
              customer.phoneNo,
              customer.address,
              customer.routId,
              customer.salesManId,
              customer.rating,
              '',
              customer.createdAt ?? '',
              customer.updatedAt ?? '',
              customer.flag ?? 1,
            ],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Update customer flag via API and update local DB
  /// Converted from KMP's updateCustomerFlag function
  /// Matches KMP pattern: API call first, then update local DB
  Future<Either<Failure, Customer>> updateCustomerFlag({
    required int customerId,
    required int flag,
  }) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateCustomerFlag,
        data: {
          'id': customerId,
          'flag': flag,
        },
      );

      // 2. Parse response
      final customerSuccessApi = CustomerSuccessApi.fromJson(response.data);
      if (customerSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update customer flag: ${customerSuccessApi.message}',
        ));
      }

      // 3. Update local DB
      final db = await _database;
      await db.update(
        'Customers',
        {'flag': flag},
        where: 'customerId = ?',
        whereArgs: [customerId],
      );

      return Right(customerSuccessApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Clear all customers from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('Customers');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync customers from API (batch download or single record retry)
  /// Converted from KMP's downloadCustomer function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all customers in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific customer by id only
  Future<Either<Failure, CustomerListApi>> syncCustomersFromApi({
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
        ApiEndpoints.customerDownload,
        queryParameters: queryParams,
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
  /// Uses custom deserialization to merge partial API response with existing data
  Future<Either<Failure, Customer>> updateCustomer(Customer customer) async {
    try {
      // 1. Get existing customer from local DB to preserve unchanged fields
      final existingCustomerResult = await getCustomerById(customer.customerId!);
      Customer? existingCustomer;
      existingCustomerResult.fold(
        (failure) => null,
        (cust) => existingCustomer = cust,
      );

      // 2. Call API
      final response = await _dio.post(
        ApiEndpoints.updateCustomer,
        data: customer.toJson(),
      );

      // 3. Parse response with merge support (handles partial responses)
      final customerSuccessApi = CustomerSuccessApi.fromJsonWithMerge(
        response.data,
        existingCustomer: existingCustomer,
      );
      
      if (customerSuccessApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update customer: ${customerSuccessApi.message}',
        ));
      }

      // 4. Update local DB with merged data
      final updateResult = await updateCustomerLocal(customerSuccessApi.data);
      if (updateResult.isLeft) {
        return updateResult.map((_) => customerSuccessApi.data);
      }

      return Right(customerSuccessApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

