import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/product_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// Products Repository
/// Handles local DB operations and API sync for Products
/// Converted from KMP's ProductsRepository.kt
class ProductsRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;

  ProductsRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all products with optional search key
  Future<Either<Failure, List<Product>>> getAllProducts({
    String searchKey = '',
  }) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        'Product',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple products to local DB (transaction)
  Future<Either<Failure, void>> addProducts(List<Product> products) async {
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final product in products) {
          await txn.insert(
            'Product',
            product.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all products from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('Product');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync products from API (batch download)
  /// Returns list of products and updated_date
  /// Parameters match KMP's params() function:
  /// - part_no (not offset)
  /// - limit
  /// - user_type
  /// - user_id
  /// - update_date (from sync time)
  Future<Either<Failure, ProductListApi>> syncProductsFromApi({
    required int partNo, // Changed from offset to partNo to match KMP
    required int limit,
    required int userType,
    required int userId,
    required String updateDate, // From sync time
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.productDownload,
        queryParameters: {
          'part_no': partNo.toString(), // Changed from 'offset' to 'part_no'
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
      );
      developer.log('ProductsRepository: syncProductsFromApi() - Response: ${response.data.toString()}');
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
      // 1. Call API
      final response = await _dio.post(
        ApiEndpoints.addProduct,
        data: product.toJson(),
      );

      // 2. Parse response
      final productApi = ProductApi.fromJson(response.data);
      if (productApi.status != 1) {
        return Left(ServerFailure.fromError(
          'Failed to create product: ${productApi.message}',
        ));
      }

      // 3. Store in local DB
      final addResult = await addProduct(productApi.product);
      if (addResult.isLeft) {
        return addResult.map((_) => productApi.product);
      }

      return Right(productApi.product);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
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

      return Right(updateProductApi.product);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

