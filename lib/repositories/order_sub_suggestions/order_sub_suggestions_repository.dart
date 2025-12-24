import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../../models/order_api.dart';
import '../../helpers/errors/failures.dart';
import '../../utils/api_endpoints.dart';

/// OrderSubSuggestions Repository
/// Handles local DB operations and API sync for Order Sub Suggestions
/// Converted from KMP's OrderSubSuggestionRepository.kt
class OrderSubSuggestionsRepository {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  
  // Cache database instance to avoid async getter overhead on every call
  Database? _cachedDatabase;

  OrderSubSuggestionsRepository({
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

  /// Get all suggestions by order sub ID (includes product name)
  Future<Either<Failure, List<OrderSubSuggestion>>> getAllSuggestionsBySubId(
    int orderSubId,
  ) async {
    try {
      final db = await _database;
      final maps = await db.rawQuery(
        '''
        SELECT sug.*, pro.name AS productName
        FROM OrderSubSuggestions sug
        LEFT JOIN Product pro ON pro.productId = sug.productId
        WHERE sug.orderSubId = ? AND sug.flag = 1
        ORDER BY pro.name
        ''',
        [orderSubId],
      );

      final suggestions = maps.map((map) => OrderSubSuggestion.fromMap(map)).toList();
      return Right(suggestions);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Check if suggestion exists for order sub and product
  Future<Either<Failure, List<OrderSubSuggestion>>> getSuggestionExist({
    required int orderSubId,
    required int productId,
  }) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSubSuggestions',
        where: 'orderSubId = ? AND productId = ? AND flag = 1',
        whereArgs: [orderSubId, productId],
      );

      final suggestions = maps.map((map) => OrderSubSuggestion.fromMap(map)).toList();
      return Right(suggestions);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get last inserted suggestion ID
  Future<Either<Failure, int?>> getLastEntryId() async {
    try {
      final db = await _database;
      final maps = await db.query(
        'OrderSubSuggestions',
        columns: ['sugId'],
        orderBy: 'sugId DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      return Right(maps.first['sugId'] as int?);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add single suggestion to local DB
  Future<Either<Failure, void>> addSuggestion(
    OrderSubSuggestion suggestion,
  ) async {
    try {
      final db = await _database;
      
      // Generate unique sugId for new suggestions (id = -1)
      int sugId = suggestion.id;
      if (sugId == -1) {
        // Get last entry ID and increment to ensure uniqueness
        final lastIdResult = await getLastEntryId();
        final lastId = lastIdResult.fold(
          (_) => 0,
          (id) => id ?? 0,
        );
        sugId = lastId + 1;
      }
      
      // Use INSERT OR REPLACE (matches KMP pattern)
      // For new suggestions: inserts with unique sugId
      // For updates from server: replaces existing row with same sugId
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO OrderSubSuggestions (
          id,
          sugId,
          orderSubId,
          productId,
          price,
          note,
          flag
        ) VALUES (
          NULL, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          sugId,
          suggestion.orderSubId,
          suggestion.prodId,
          suggestion.price,
          suggestion.note ?? '',
          suggestion.flag ?? 1,
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Add multiple suggestions to local DB (transaction)
  Future<Either<Failure, void>> addSuggestions(
    List<OrderSubSuggestion> suggestions,
  ) async {
    try {
      final db = await _database;
      
      // Get starting sugId for new suggestions
      final lastIdResult = await getLastEntryId();
      int nextSugId = lastIdResult.fold(
        (_) => 1,
        (id) => (id ?? 0) + 1,
      );
      
      await db.transaction((txn) async {
        const sql = '''
        INSERT OR REPLACE INTO OrderSubSuggestions (
          sugId,
          orderSubId,
          productId,
          price,
          note,
          flag
        ) VALUES (
          ?, ?, ?, ?, ?, ?
        )
        ''';
        for (final suggestion in suggestions) {
          // Generate unique sugId for new suggestions
          int sugId = suggestion.id;
          if (sugId == -1) {
            sugId = nextSugId++;
          }
          
          await txn.rawInsert(
            sql,
            [
              sugId,
              suggestion.orderSubId,
              suggestion.prodId,
              suggestion.price,
              suggestion.note ?? '',
              suggestion.flag ?? 1,
            ],
          );
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Remove suggestions by order sub ID
  Future<Either<Failure, void>> removeSuggestionsByOrderSubId(
    int orderSubId,
  ) async {
    try {
      final db = await _database;
      await db.delete(
        'OrderSubSuggestions',
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Remove suggestion by ID
  Future<Either<Failure, void>> removeSuggestion(int sugId) async {
    try {
      final db = await _database;
      await db.delete(
        'OrderSubSuggestions',
        where: 'sugId = ?',
        whereArgs: [sugId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all suggestions from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _database;
      await db.delete('OrderSubSuggestions');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // API SYNC METHODS (Used by sync repository)
  // ============================================================================

  /// Sync order sub suggestions from API (batch download)
  /// Sync order sub suggestions from API (batch download or single record retry)
  /// Converted from KMP's downloadOrderSubSuggestion function
  /// Supports two modes:
  /// 1. Full sync (id == -1): Downloads all suggestions in batches with part_no, limit, user_type, user_id, update_date
  /// 2. Single record retry (id != -1): Downloads specific suggestion by id only
  Future<Either<Failure, OrderSubSuggestionsListApi>> syncSuggestionsFromApi({
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
        ApiEndpoints.orderSubSuggestionDownload,
        queryParameters: queryParams,
      );

      final suggestionsListApi = OrderSubSuggestionsListApi.fromJson(response.data);
      return Right(suggestionsListApi);
    } on DioException catch (e) {
      return Left(NetworkFailure.fromDioError(e));
    } catch (e) {
      return Left(UnknownFailure.fromError(e));
    }
  }
}

