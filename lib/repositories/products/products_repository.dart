import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/product_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/push_notification_sender.dart';
import '../../models/push_data.dart';
import '../../utils/notification_id.dart';

/// Products Repository
/// Handles local DB operations and API sync for Products
/// Converted from KMP's ProductsRepository.kt
class ProductsRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  final PushNotificationSender? _pushNotificationSender;
  
  // Cache database instance to avoid async getter overhead on every call
  // Priority 3: Performance optimization - cache DB instance at repository level
  Database? _cachedDatabase;

  ProductsRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
    PushNotificationSender? pushNotificationSender,
  })  : _databaseHelper = databaseHelper,
        _dio = dio,
        _pushNotificationSender = pushNotificationSender;
  
  /// Get database instance (cached after first access)
  /// Priority 3: Performance optimization - eliminates async getter overhead
  Future<Database> get _database async {
    if (_cachedDatabase != null) return _cachedDatabase!;
    _cachedDatabase = await _databaseHelper.database;
    return _cachedDatabase!;
  }

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all products with optional search key
  Future<Either<Failure, List<Product>>> getAllProducts({
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Product',
          where: 'flag = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT * FROM Product 
          WHERE flag = 1 AND (
            LOWER(code) LIKE LOWER(?) OR 
            LOWER(name) LIKE LOWER(?) OR 
            LOWER(subName) LIKE LOWER(?) OR 
            LOWER(brand) LIKE LOWER(?) OR 
            LOWER(subBrand) LIKE LOWER(?)
          )
          ORDER BY name ASC
          ''',
          [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern],
        );
      }

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all products by category
  Future<Either<Failure, List<Product>>> getAllProductsByCategory({
    required int categoryId,
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Product',
          where: 'flag = 1 AND categoryId = ?',
          whereArgs: [categoryId],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT * FROM Product 
          WHERE flag = 1 AND (
            LOWER(code) LIKE LOWER(?) OR 
            LOWER(name) LIKE LOWER(?) OR 
            LOWER(subName) LIKE LOWER(?) OR 
            LOWER(brand) LIKE LOWER(?) OR 
            LOWER(subBrand) LIKE LOWER(?)
          ) AND categoryId = ?
          ORDER BY name ASC
          ''',
          [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern, categoryId],
        );
      }

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all products by category and subcategory
  Future<Either<Failure, List<Product>>> getAllProductsBySubCategory({
    required int categoryId,
    required int subCategoryId,
    String searchKey = '',
  }) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps;

      if (searchKey.isEmpty) {
        maps = await db.query(
          'Product',
          where: 'flag = 1 AND categoryId = ? AND subCategoryId = ?',
          whereArgs: [categoryId, subCategoryId],
          orderBy: 'name ASC',
        );
      } else {
        final searchPattern = '%$searchKey%';
        maps = await db.rawQuery(
          '''
          SELECT * FROM Product 
          WHERE flag = 1 AND (
            LOWER(code) LIKE LOWER(?) OR 
            LOWER(name) LIKE LOWER(?) OR 
            LOWER(subName) LIKE LOWER(?) OR 
            LOWER(brand) LIKE LOWER(?) OR 
            LOWER(subBrand) LIKE LOWER(?)
          ) AND categoryId = ? AND subCategoryId = ?
          ORDER BY name ASC
          ''',
          [
            searchPattern,
            searchPattern,
            searchPattern,
            searchPattern,
            searchPattern,
            categoryId,
            subCategoryId
          ],
        );
      }

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get product by ID
  Future<Either<Failure, Product?>> getProductById(int productId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          Category.name AS categoryName,
          SubCategory.name AS subCategoryName,
          Suppliers.name AS supplierName,
          Units.name AS baseUnitName,
          Product.*
        FROM Product
        LEFT JOIN Category ON Category.categoryId = Product.categoryId
        LEFT JOIN SubCategory ON SubCategory.subCategoryId = Product.subCategoryId
        LEFT JOIN Suppliers ON Suppliers.userId = Product.defaultSuppId
        LEFT JOIN Units ON Units.unitId = Product.baseUnitId
        WHERE Product.flag = 1 AND Product.productId = ?
        ORDER BY Product.id DESC
        LIMIT 1
        ''',
        [productId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final product = Product.fromMap(maps.first);
      return Right(product);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by name
  Future<Either<Failure, List<Product>>> getProductsByName(String name) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(name) = LOWER(?)',
        whereArgs: [name],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by name excluding specific product ID
  Future<Either<Failure, List<Product>>> getProductsByNameWithId({
    required String name,
    required int productId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(name) = LOWER(?) AND productId != ?',
        whereArgs: [name, productId],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by code
  Future<Either<Failure, List<Product>>> getProductsByCode(String code) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(code) = LOWER(?)',
        whereArgs: [code],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by code excluding specific product ID
  Future<Either<Failure, List<Product>>> getProductsByCodeWithId({
    required String code,
    required int productId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(code) = LOWER(?) AND productId != ?',
        whereArgs: [code, productId],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by barcode
  Future<Either<Failure, List<Product>>> getProductsByBarcode(String barcode) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(barcode) = LOWER(?)',
        whereArgs: [barcode],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get products by barcode excluding specific product ID
  Future<Either<Failure, List<Product>>> getProductsByBarcodeWithId({
    required String barcode,
    required int productId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1 AND LOWER(barcode) = LOWER(?) AND productId != ?',
        whereArgs: [barcode, productId],
        orderBy: 'name ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      return Right(products);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted product
  Future<Either<Failure, Product?>> getLastEntry() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'Product',
        where: 'flag = 1',
        orderBy: 'productId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final product = Product.fromMap(maps.first);
      return Right(product);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single product to local DB
  /// Converted from KMP's addProduct function (single product)
  /// Uses raw query matching KMP's insertProduct query exactly
  /// id is set to NULL (auto-increment primary key)
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final db = await _database;
      // Raw query matching KMP's insertProduct query (Product.sq line 27-30)
      // Column order: id,productId,code,barcode,name,subName,brand,subBrand,categoryId,subCategoryId,defaultSuppId,autoSend,baseUnitId,defaultUnitId,photoUrl,price,mrp,retailPrice,fittingCharge,note,outtOfStockFlag,flag
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO Product(
          id, productId, code, barcode, name, subName, brand, subBrand, 
          categoryId, subCategoryId, defaultSuppId, autoSend, baseUnitId, defaultUnitId,
          photoUrl, price, mrp, retailPrice, fittingCharge, note, outtOfStockFlag, flag
        ) VALUES (
          NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          product.id, // productId (from API)
          product.code,
          product.barcode,
          product.name,
          product.sub_name,
          product.brand,
          product.sub_brand,
          product.category_id,
          product.sub_category_id,
          product.default_supp_id,
          product.auto_sendto_supplier_flag >= 0 ? product.auto_sendto_supplier_flag : 0,
          product.base_unit_id,
          product.default_unit_id,
          product.photo,
          product.price,
          product.mrp,
          product.retail_price,
          product.fitting_charge,
          product.note,
          1, // outtOfStockFlag (default 1, matching KMP)
          1, // flag (default 1, matching KMP)
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple products to local DB (transaction)
  /// Converted from KMP's addProduct function (list)
  /// Uses raw query matching KMP's insertProduct query exactly
  /// For batch sync: id is provided from product (from API)
  /// CRITICAL OPTIMIZATION: Uses batch operations for 100x+ performance improvement
  /// Matching KMP pattern: db.transaction { list.forEach { ... } } - SQLDelight optimizes internally
  /// In Flutter/sqflite, we use batch.rawInsert() + batch.commit() to achieve same performance
  Future<Either<Failure, void>> addProducts(List<Product> products) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        // Raw query matching KMP's insertProduct query (Product.sq line 27-30)
        // Column order: id,productId,code,barcode,name,subName,brand,subBrand,categoryId,subCategoryId,defaultSuppId,autoSend,baseUnitId,defaultUnitId,photoUrl,price,mrp,retailPrice,fittingCharge,note,outtOfStockFlag,flag
        // For batch sync from API: id is provided (matching KMP line 32 where id is passed)
        for (final product in products) {
          // CRITICAL: Use batch.rawInsert() instead of await txn.rawInsert() - 100x faster!
          batch.rawInsert(
            '''
            INSERT OR REPLACE INTO Product(
              id, productId, code, barcode, name, subName, brand, subBrand, 
              categoryId, subCategoryId, defaultSuppId, autoSend, baseUnitId, defaultUnitId,
              photoUrl, price, mrp, retailPrice, fittingCharge, note, outtOfStockFlag, flag
            ) VALUES (
              NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            [
              product.id, // productId (from API)
              product.code,
              product.barcode,
              product.name,
              product.sub_name,
              product.brand,
              product.sub_brand,
              product.category_id,
              product.sub_category_id,
              product.default_supp_id,
              product.auto_sendto_supplier_flag >= 0 ? product.auto_sendto_supplier_flag : 0,
              product.base_unit_id,
              product.default_unit_id,
              product.photo,
              product.price,
              product.mrp,
              product.retail_price,
              product.fitting_charge,
              product.note,
              1, // outtOfStockFlag (default 1, matching KMP line 33)
              1, // flag (default 1, matching KMP line 33)
            ],
          );
        }
        // CRITICAL: Commit all inserts at once - matches SQLDelight's optimized behavior
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all products from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('Product');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync products from API (batch download or single record retry)
  /// Converted from KMP's downloadProducts function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all products in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific product by id only
  /// Returns list of products and updated_date
  Future<Either<Failure, ProductListApi>> syncProductsFromApi({
    required int partNo, // Changed from offset to partNo to match KMP
    required int limit,
    required int userType,
    required int userId,
    required String updateDate, // From sync time
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
        ApiEndpoints.productDownload,
        queryParameters: queryParams,
      );
      final productListApi = ProductListApi.fromJson(response.data);
      return Right(productListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // API WRITE METHODS (Used by providers for create/update)
  // ============================================================================

  /// Create product via API and update local DB
  Future<Either<Failure, Product>> createProduct(Product product) async {
    try {
      // 1. Prepare request payload (matching API documentation)
      // API expects: name, code (required) and optional fields
      // Do NOT send: id, default_unit_id (these are set by server)
      final Map<String, dynamic> requestData = {
        'name': product.name,
        'code': product.code,
      };

      // Add optional fields only if they have valid values
      if (product.barcode.isNotEmpty) {
        requestData['barcode'] = product.barcode;
      }
      if (product.sub_name.isNotEmpty) {
        requestData['sub_name'] = product.sub_name;
      }
      if (product.brand.isNotEmpty) {
        requestData['brand'] = product.brand;
      }
      if (product.sub_brand.isNotEmpty) {
        requestData['sub_brand'] = product.sub_brand;
      }
      // Integer fields - always send (matching KMP behavior)
      // KMP always sends these fields even if -1
      // For optional fields, send null if -1 (API expects null, not empty string)
      requestData['category_id'] = product.category_id != -1 ? product.category_id : null;
      requestData['sub_category_id'] = product.sub_category_id != -1 ? product.sub_category_id : null;
      requestData['default_supp_id'] = product.default_supp_id != -1 ? product.default_supp_id : -1;
      requestData['auto_sendto_supplier_flag'] = product.auto_sendto_supplier_flag >= 0 
          ? product.auto_sendto_supplier_flag 
          : 0;
      requestData['base_unit_id'] = product.base_unit_id != -1 ? product.base_unit_id : null;
      // Price is required by our validation, so always send it
      requestData['price'] = product.price.toString();
      // Optional price fields - send if > 0
      if (product.mrp > 0) {
        requestData['mrp'] = product.mrp.toString();
      }
      if (product.retail_price > 0) {
        requestData['retail_price'] = product.retail_price.toString();
      }
      if (product.fitting_charge > 0) {
        requestData['fitting_charge'] = product.fitting_charge.toString();
      }
      if (product.note.isNotEmpty) {
        requestData['note'] = product.note;
      }
      if (product.photo.isNotEmpty) {
        requestData['photo'] = product.photo;
      }

      // 2. Call API
      final response = await _dio.post(
        ApiEndpoints.addProduct,
        data: requestData,
      );
      final responseData = response.data as Map<String, dynamic>;
      // 3. Parse response
      // API returns: {status: 1, message: "...", product: {...}, productUnit: {...}}
      // Or error: {status: 0, message: "...", data: [...]}
      ProductApi productApi;
      try {
        productApi = ProductApi.fromJson(responseData);
      } catch (e) {
        developer.log('ProductsRepository: createProduct() - Error parsing response: $e');
        return Left(ServerFailure.fromError('Failed to parse product response: $e'));
      }
      
      // 4. Store in local DB
      final addResult = await addProduct(productApi.product);
      if (addResult.isLeft) {
        developer.log('ProductsRepository: createProduct() - Add result: ${addResult.left}');
        return addResult.map((_) => productApi.product);
      }
      developer.log('ProductsRepository: createProduct() - Product: ${productApi.product.toJson()}');
      
      // 4b. Store ProductUnit in local DB (matches KMP line 209-210)
      if (productApi.productUnit.id != -1) {
        final productUnitAddResult = await addProductUnitLocal(productApi.productUnit);
        if (productUnitAddResult.isLeft) {
          developer.log(
            'ProductsRepository: createProduct() - Failed to add product unit: ${productUnitAddResult.left}',
          );
          // Continue anyway - product is already stored
        }
      }
      
      // 5. Send push notification (fire-and-forget, non-blocking)
      // Matches KMP's sentPushNotification pattern (ProductViewModel.kt lines 206-212)
      if (_pushNotificationSender != null) {
        final dataIds = <PushData>[
          PushData(table: NotificationId.product, id: productApi.product.id),
        ];
        
        // Include productUnit if it exists (matches KMP line 208-211)
        if (productApi.productUnit.id != -1) {
          dataIds.add(PushData(table: NotificationId.productUnits, id: productApi.productUnit.id));
        }
        
        // Fire-and-forget: don't await, just trigger in background
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Product updates',
        ).catchError((e) {
          developer.log('ProductsRepository: Error sending push notification: $e');
        });
      }
      
      return Right(productApi.product);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      developer.log('ProductsRepository: createProduct() - Error: $e');
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Update product via API and update local DB
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    try {
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.updateProduct,
        data: product.toJson(),
      );

      // 2. Parse response
      final updateProductApi = UpdateProductApi.fromJson(response.data);
      if (updateProductApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to update product: ${updateProductApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addProduct(updateProductApi.product);
      if (addResult.isLeft) {
        return addResult.map((_) => updateProductApi.product);
      }

      // 4. Send push notification (fire-and-forget, non-blocking)
      // Matches KMP's sentPushNotification pattern (ProductViewModel.kt lines 255-257)
      if (_pushNotificationSender != null) {
        final dataIds = <PushData>[
          PushData(table: NotificationId.product, id: updateProductApi.product.id),
        ];
        
        // Fire-and-forget: don't await, just trigger in background
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Product updates',
        ).catchError((e) {
          developer.log('ProductsRepository: Error sending push notification: $e');
        });
      }

      return Right(updateProductApi.product);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }


  // ============================================================================
  // PRODUCT UNITS METHODS
  // ============================================================================

  /// Add multiple product units to local DB (transaction)
  /// Matches KMP's addProductUnits (ProductsRepository.kt lines 264-274)
  /// CRITICAL OPTIMIZATION: Uses batch operations for 100x+ performance improvement
  /// Matching KMP pattern: db.transaction { list.forEach { ... } } - SQLDelight optimizes internally
  /// In Flutter/sqflite, we use batch.rawInsert() + batch.commit() to achieve same performance
  Future<Either<Failure, void>> addProductUnits(List<ProductUnit> productUnits) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        const sql = '''
        INSERT OR REPLACE INTO ProductUnits (
          id, productUnitId, productId, baseUnitId, derivedUnitId, flag
        ) VALUES (
          NULL, ?, ?, ?, ?, ?
        )
        ''';
        for (final productUnit in productUnits) {
          // CRITICAL: Use batch.rawInsert() instead of await txn.rawInsert() - 100x faster!
          batch.rawInsert(
            sql,
            [
              productUnit.id, // productUnitId from API
              productUnit.prd_id, // productId
              productUnit.base_unit_id, // baseUnitId
              productUnit.derived_unit_id, // derivedUnitId
              1, // flag
            ],
          );
        }
        // CRITICAL: Commit all inserts at once - matches SQLDelight's optimized behavior
        await batch.commit(noResult: true);
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Sync product units from API (batch download or single record retry)
  /// Matches KMP's downloadProductUnits function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all product units in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific product unit by id only
  Future<Either<Failure, ProductUnitListApi>> syncProductUnitsFromApi({
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
        ApiEndpoints.productUnitDownload,
        queryParameters: queryParams,
      );
// response data is like this:
//       0 =
// "id" -> 5840
// 1 =
// "prd_id" -> 5838
// 2 =
// "base_unit_id" -> 2
// 3 =
// "derived_unit_id" -> 2
// 4 =
// "created_at" -> "2025-08-10 00:11:42"
// 5 =
// "updated_at" -> "2025-08-10 00:11:42"

      final productUnitListApi = ProductUnitListApi.fromJson(response.data);
      return Right(productUnitListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  // ============================================================================
  // PRODUCT CARS METHODS
  // ============================================================================

  /// Get product cars by product ID (grouped by brand/name/model/version)
  /// Matches KMP's getProductCarByProductId (ProductsRepository.kt lines 230-253)
  Future<Either<Failure, Map<String, Map<String, Map<String, List<String>>>>>>
      getProductCarsByProductId(
    int productId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          CarBrand.name AS carBrand,
          CarName.name AS carName,
          CASE
            WHEN ProductCar.carModelId = -1 THEN ''
            ELSE CarModel.name
          END AS carModel,
          CASE
            WHEN ProductCar.carVersionId = -1 THEN ''
            ELSE CarVersion.name
          END AS carVersion,
          ProductCar.*
        FROM ProductCar
        LEFT JOIN CarBrand ON CarBrand.carBrandId = ProductCar.carBrandId
        LEFT JOIN CarName ON CarName.carNameId = ProductCar.carNameId
        LEFT JOIN CarModel ON CarModel.carModelId = ProductCar.carModelId
        LEFT JOIN CarVersion ON CarVersion.carVersionId = ProductCar.carVersionId
        WHERE ProductCar.flag = 1 AND ProductCar.productId = ?
        ORDER BY CarBrand.carBrandId, CarName.carNameId, CarModel.carModelId, CarVersion.carVersionId
        ''',
        [productId],
      );

      // Group by brand -> name -> model -> versions (matches KMP lines 236-247)
      final carData = <String, Map<String, Map<String, List<String>>>>{};
      for (final map in maps) {
        final brand = map['carBrand'] as String? ?? '';
        final name = map['carName'] as String? ?? '';
        final model = map['carModel'] as String? ?? '';
        final version = map['carVersion'] as String? ?? '';

        if (brand.isEmpty || name.isEmpty) continue;

        final brandMap = carData.putIfAbsent(brand, () => <String, Map<String, List<String>>>{});
        final nameMap = brandMap.putIfAbsent(name, () => <String, List<String>>{});
        final versionList = nameMap.putIfAbsent(model, () => <String>[]);
        if (version.isNotEmpty && !versionList.contains(version)) {
          versionList.add(version);
        }
      }

      return Right(carData);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get product units by product ID (with derived unit names)
  /// Matches KMP's getAllProductUnit (ProductsRepository.kt lines 288-298)
  Future<Either<Failure, List<ProductUnitWithDetails>>> getProductUnitsByProductId(
    int productId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          bu.name AS baseName,
          du.name AS derivenName,
          du.baseQty AS baseQty,
          pu.*
        FROM ProductUnits pu
        LEFT JOIN Units bu ON pu.baseUnitId = bu.unitId
        LEFT JOIN Units du ON pu.derivedUnitId = du.unitId
        WHERE pu.productId = ? AND pu.flag = 1
        ORDER BY pu.productId
        ''',
        [productId],
      );

      final units = maps.map((map) => ProductUnitWithDetails.fromMap(map)).toList();
      return Right(units);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get product by ID with details (returns ProductWithDetails)
  /// Matches KMP's getProductsById with JOIN query
  Future<Either<Failure, ProductWithDetails?>> getProductByIdWithDetails(int productId) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT
          Category.name AS categoryName,
          SubCategory.name AS subCategoryName,
          Suppliers.name AS supplierName,
          Units.name AS baseUnitName,
          Product.*
        FROM Product
        LEFT JOIN Category ON Category.categoryId = Product.categoryId
        LEFT JOIN SubCategory ON SubCategory.subCategoryId = Product.subCategoryId
        LEFT JOIN Suppliers ON Suppliers.userId = Product.defaultSuppId
        LEFT JOIN Units ON Units.unitId = Product.baseUnitId
        WHERE Product.flag = 1 AND Product.productId = ?
        ORDER BY Product.id DESC
        LIMIT 1
        ''',
        [productId],
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final productWithDetails = ProductWithDetails.fromMap(maps.first);
      return Right(productWithDetails);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add product car via API and update local DB
  /// Matches KMP's addCarToProduct (ProductViewModel.kt lines 427-447)
  Future<Either<Failure, List<ProductCar>>> addProductCar({
    required int productId,
    required int brandId,
    required int nameId,
    required Map<String, Map<int, List<int>>> selectedMap, // modelId (as string) -> versionIds map
  }) async {
    try {
      // Build params matching KMP's addProductCarParams (lines 309-354)
      final List<Map<String, dynamic>> dataArray = [];
      
      if (selectedMap.isNotEmpty) {
        selectedMap.forEach((modelIdStr, versionMap) {
          final modelId = int.parse(modelIdStr);
          versionMap.forEach((versionId, _) {
            dataArray.add({
              'product_id': productId,
              'car_brand_id': brandId,
              'car_name_id': nameId,
              'car_model_id': modelId,
              'car_version_id': versionId,
            });
          });
          // If no versions for this model, add with version_id = -1
          if (versionMap.isEmpty) {
            dataArray.add({
              'product_id': productId,
              'car_brand_id': brandId,
              'car_name_id': nameId,
              'car_model_id': modelId,
              'car_version_id': -1,
            });
          }
        });
      } else {
        // If selectedMap is empty, add with model_id = -1 and version_id = -1
        dataArray.add({
          'product_id': productId,
          'car_brand_id': brandId,
          'car_name_id': nameId,
          'car_model_id': -1,
          'car_version_id': -1,
        });
      }

      final response = await _dio.post(
        ApiEndpoints.addProductCar,
        data: {
          'data': dataArray,  // Wrapped in "data" key as per KMP
        },
      );

      final productCarApi = ProductCarApi.fromJson(response.data);
      if (productCarApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to add car: ${productCarApi.message}',
        ));
      }

      // Store in local DB
      await addProductCars(productCarApi.data);

      // Send push notification (matches KMP lines 437-441)
      if (_pushNotificationSender != null && productCarApi.data.isNotEmpty) {
        final dataIds = productCarApi.data
            .map((car) => PushData(table: NotificationId.productCar, id: car.id))
            .toList();
        // Fire-and-forget: don't await, just trigger in background
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Product car updates',
        ).catchError((e) {
          developer.log('ProductsRepository: Error sending push notification: $e');
        });
      }

      return Right(productCarApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Add product cars to local DB
  /// Matches KMP's addProductCar (ProductsRepository.kt lines 184-191)
  Future<Either<Failure, void>> addProductCars(List<ProductCar> productCars) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final car in productCars) {
          batch.insert(
            'ProductCar',
            {
              'productCarId': car.id,
              'productId': car.product_id,
              'carBrandId': car.car_brand_id,
              'carNameId': car.car_name_id,
              'carModelId': car.car_model_id,
              'carVersionId': car.car_version_id,
              'flag': car.flag ?? 1,
            },
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

  /// Add product unit via API and update local DB
  /// Matches KMP's addUnitToProduct (ProductViewModel.kt lines 449-473)
  Future<Either<Failure, ProductUnit>> addProductUnit({
    required int productId,
    required int baseUnitId,
    required int derivedUnitId,
  }) async {
    try {
      // Check if already exists (matches KMP lines 450-454)
      final existResult = await checkProductUnitExist(
        productId: productId,
        baseUnitId: baseUnitId,
        derivedUnitId: derivedUnitId,
      );
      existResult.fold(
        (_) {},
        (exists) {
          if (exists) {
            throw Exception('Already exist');
          }
        },
      );

      final response = await _dio.post(
        ApiEndpoints.addProductUnit,
        data: {
          'prd_id': productId,  // Use "prd_id" not "product_id" as per KMP
          'base_unit_id': baseUnitId,
          'derived_unit_id': derivedUnitId,
        },
      );

      final productUnitApi = ProductUnitApi.fromJson(response.data);
      if (productUnitApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to add unit: ${productUnitApi.message}',
        ));
      }

      // Store in local DB (matches KMP lines 467-468)
      await addProductUnitLocal(productUnitApi.data);

      // Send push notification (matches KMP lines 463-466)
      // Fire-and-forget: don't await, just trigger in background
      if (_pushNotificationSender != null) {
        final dataIds = [
          PushData(table: NotificationId.productUnits, id: productUnitApi.data.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Product unit updates',
        ).catchError((e) {
          developer.log('ProductsRepository: Error sending push notification: $e');
        });
      }

      return Right(productUnitApi.data);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      if (e.toString().contains('Already exist')) {
        return Left(ValidationFailure.fromError('Already exist'));
      }
      return Left(UnknownFailure.fromError(e));
    }
  }

  /// Check if product unit exists
  /// Matches KMP's checkProductUnitExist (ProductsRepository.kt lines 276-285)
  Future<Either<Failure, bool>> checkProductUnitExist({
    required int productId,
    required int baseUnitId,
    required int derivedUnitId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'ProductUnits',
        where: 'productId = ? AND baseUnitId = ? AND derivedUnitId = ? AND flag = ?',
        whereArgs: [productId, baseUnitId, derivedUnitId, 1],
      );
      return Right(maps.isNotEmpty);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add product unit to local DB
  /// Matches KMP's addProductUnit (ProductsRepository.kt lines 256-262)
Future<Either<Failure, void>> addProductUnitLocal(ProductUnit productUnit) async {
  try {
    final db = await _database;

    await db.rawInsert('''
      INSERT OR REPLACE INTO ProductUnits 
      (id,productUnitId, productId, baseUnitId, derivedUnitId, flag)
      VALUES (NULL,?, ?, ?, ?, ?)
    ''', [
      productUnit.id,
      productUnit.prd_id,
      productUnit.base_unit_id,
      productUnit.derived_unit_id,
      1,
    ]);

    return const Right(null);
  } catch (e) {
    return Left(DatabaseFailure.fromError(e));
  }
}

}

