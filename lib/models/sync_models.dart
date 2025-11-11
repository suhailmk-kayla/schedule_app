/// SyncTime Model
/// Simple model for tracking sync times per table
class SyncTime {
  final int id;
  final String tableName;
  final String updateDate;

  const SyncTime({
    required this.id,
    required this.tableName,
    required this.updateDate,
  });

  factory SyncTime.fromMap(Map<String, dynamic> map) {
    return SyncTime(
      id: map['id'] as int? ?? 0,
      tableName: map['table_name'] as String? ?? '',
      updateDate: map['update_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'update_date': updateDate,
    };
  }
}

/// FailedSync Model
/// Simple model for tracking failed sync operations
class FailedSync {
  final int id;
  final int tableId;
  final int dataId;

  const FailedSync({
    required this.id,
    required this.tableId,
    required this.dataId,
  });

  factory FailedSync.fromMap(Map<String, dynamic> map) {
    return FailedSync(
      id: map['id'] as int? ?? 0,
      tableId: map['table_id'] as int? ?? 0,
      dataId: map['data_id'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'table_id': tableId,
      'data_id': dataId,
    };
  }
}

