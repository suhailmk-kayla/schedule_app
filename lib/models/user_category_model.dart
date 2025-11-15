/// UserCategory Model
/// Converted from KMP's UsersCategory class
class UserCategory {
  final int id;
  final String name;
  final String permissionJson;
  final int flag;

  const UserCategory({
    required this.id,
    required this.name,
    required this.permissionJson,
    required this.flag,
  });

  /// Convert from database map (camelCase column names)
  /// Used when reading from SQLite database
  factory UserCategory.fromMap(Map<String, dynamic> map) {
    return UserCategory(
      id: map['userCategoryId'] as int? ?? -1,  // DB uses 'userCategoryId'
      name: map['name'] as String? ?? '',
      permissionJson: map['permissionJson'] as String? ?? '{}',  // DB uses camelCase
      flag: map['flag'] as int? ?? 1,
    );
  }

  /// Convert from API response map (snake_case field names)
  /// Used when parsing server response
  factory UserCategory.fromMapServerData(Map<String, dynamic> map) {
    return UserCategory(
      id: map['id'] as int? ?? -1,  // API uses 'id', not 'userCategoryId'
      name: map['name'] as String? ?? '',
      permissionJson: map['permission_json'] as String? ?? '{}',  // API uses snake_case
      flag: map['flag'] as int? ?? 1,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'userCategoryId': id,  // DB expects 'userCategoryId'
      'name': name,
      'permissionJson': permissionJson,  // DB expects camelCase
      'flag': flag,
    };
  }
}

// 0 =
// "id" -> 1
// 1 =
// "name" -> "admin"
// 2 =
// "permission_json" -> null
// 3 =
// "flag" -> 1
// 4 =
// "created_at" -> "2025-02-01 09:38:14"
// 5 =
// "updated_at" -> "2025-02-01 09:38:14
