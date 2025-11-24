import 'package:either_dart/either.dart';
import '../local/database_helper.dart';
import '../../models/packed_subs_model.dart';
import '../../helpers/errors/failures.dart';

/// PackedSubs Repository
/// Handles local DB operations for Packed Order Subs
/// Converted from KMP's PackedSubsRepository.kt
class PackedSubsRepository {
  final DatabaseHelper _databaseHelper;

  PackedSubsRepository({
    required DatabaseHelper databaseHelper,
  }) : _databaseHelper = databaseHelper;

  // ============================================================================
  // LOCAL DB READ METHODS (Used by providers for display)
  // ============================================================================

  /// Get packed list by order sub ID
  Future<Either<Failure, List<PackedSubs>>> getPackedList(int orderSubId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'PackedSubs',
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );

      final packedSubs = maps.map((map) => PackedSubs.fromMap(map)).toList();
      return Right(packedSubs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  // ============================================================================
  // LOCAL DB WRITE METHODS (Used by sync and write operations)
  // ============================================================================

  /// Add packed sub to local DB
  Future<Either<Failure, void>> addPackedSub({
    required int orderSubId,
    required double quantity,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO PackedSubs (orderSubId, quantity)
        VALUES (?, ?)
        ''',
        [orderSubId, quantity],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Delete packed sub by order sub ID
  Future<Either<Failure, void>> deletePackedSub(int orderSubId) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        'PackedSubs',
        where: 'orderSubId = ?',
        whereArgs: [orderSubId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all packed subs from local DB
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('PackedSubs');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }
}

