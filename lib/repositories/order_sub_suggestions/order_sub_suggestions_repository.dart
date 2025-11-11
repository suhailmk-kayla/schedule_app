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

  OrderSubSuggestionsRepository({
    required DatabaseHelper databaseHelper,
    required Dio dio,
  })  : _databaseHelper = databaseHelper,
        _dio = dio;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get all suggestions by order sub ID (includes product name)
  Future<Either<Failure, List<OrderSubSuggestion>>> getAllSuggestionsBySubId(
    int orderSubId,
  ) async {
    try {
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
      await db.insert(
        'OrderSubSuggestions',
        suggestion.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
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
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        for (final suggestion in suggestions) {
          await txn.insert(
            'OrderSubSuggestions',
            suggestion.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
      final db = await _databaseHelper.database;
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
  Future<Either<Failure, OrderSubSuggestionsListApi>> syncSuggestionsFromApi({
    required int partNo,
    required int limit,
    required int userType,
    required int userId,
    required String updateDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.orderSubSuggestionDownload,
        queryParameters: {
          'part_no': partNo.toString(),
          'limit': limit.toString(),
          'user_type': userType.toString(),
          'user_id': userId.toString(),
          'update_date': updateDate,
        },
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

