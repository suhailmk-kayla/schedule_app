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

  factory UserCategory.fromMap(Map<String, dynamic> map) {
    return UserCategory(
      id: map['userCategoryId'] as int? ?? -1,
      name: map['name'] as String? ?? '',
      permissionJson: map['permissionJson'] as String? ?? '{}',
      flag: map['flag'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userCategoryId': id,
      'name': name,
      'permissionJson': permissionJson,
      'flag': flag,
    };
  }
}

