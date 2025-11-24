import 'package:either_dart/either.dart';
import '../local/database_helper.dart';
import '../../models/sync_models.dart';
import '../../helpers/errors/failures.dart';

/// FailedSync Repository
/// Handles tracking of failed sync operations
/// Converted from KMP's FailedSyncRepository.kt
class FailedSyncRepository {
  final DatabaseHelper _databaseHelper;

  FailedSyncRepository({
    required DatabaseHelper databaseHelper,
  }) : _databaseHelper = databaseHelper;

  /// Add a failed sync record
  Future<Either<Failure, void>> addFailedSync({
    required int tableId,
    required int dataId,
  }) async {
    try {
      final db = await _databaseHelper.database;
      await db.rawInsert(
        '''
        INSERT INTO FailedSync (id, table_id, data_id)
        VALUES (NULL, ?, ?)
        ''',
        [tableId, dataId],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Get all failed sync records
  Future<Either<Failure, List<FailedSync>>> getAllFailedSyncs() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query('FailedSync', orderBy: 'id ASC');

      final failedSyncs = maps.map((map) => FailedSync.fromMap(map)).toList();
      return Right(failedSyncs);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Delete a failed sync record
  Future<Either<Failure, void>> deleteFailedSync(int id) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        'FailedSync',
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }

  /// Clear all failed sync records
  Future<Either<Failure, void>> clearAll() async {
    try {
      final db = await _databaseHelper.database;
      await db.delete('FailedSync');
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure.fromError(e));
    }
  }
}

