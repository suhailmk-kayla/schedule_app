/// Push Data Model
/// Represents a single data item to be sent in push notification
/// Converted from KMP's PushData.kt
class PushData {
  final int table; // NotificationId constant
  final int id; // Record ID

  const PushData({
    required this.table,
    required this.id,
  });

  /// Convert to JSON map for API request
  Map<String, dynamic> toJson() {
    return {
      'table': table,
      'id': id,
    };
  }
}

