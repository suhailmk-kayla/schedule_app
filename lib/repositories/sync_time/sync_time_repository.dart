import 'package:either_dart/either.dart';
import '../local/database_helper.dart';
import '../../models/sync_models.dart';
import '../../helpers/errors/failures.dart';

/// SyncTime Repository
/// Handles sync time tracking for tables
/// Converted from KMP's SyncTimeRepository.kt
class SyncTimeRepository {
  final DatabaseHelper _databaseHelper;

  SyncTimeRepository({
    required DatabaseHelper databaseHelper,
  }) : _databaseHelper = databaseHelper;

  /// Add or update sync time for a table
  Future<Either<Failure, void>> addSyncTime({
    required String tableName,
    required String updateDate,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO SyncTime (id, table_name, update_date)
        VALUES (NULL, ?, ?)
        ''',
        [tableName, updateDate],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get sync time for a table
  Future<Either<Failure, SyncTime?>> getSyncTime(String tableName) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'SyncTime',
        where: 'table_name = ?',
        whereArgs: [tableName],
        limit: 1,
      );

      if (maps.isEmpty) {
        return const Right(null);
      }

      final syncTime = SyncTime.fromMap(maps.first);
      return Right(syncTime);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all sync times
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('SyncTime');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }
}

