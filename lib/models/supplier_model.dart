/// Supplier Model
/// Converted from KMP's Suppliers class
class Supplier {
  /// Business identifier from server (supplierId in DB)
  final int? id;
  final int? userId;
  final String code;
  final String name;
  final String phone;
  final String address;
  final String deviceToken;
  final String createdDateTime;
  final String updatedDateTime;
  final int flag;

  const Supplier({
    this.id,
    this.userId,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.deviceToken,
    required this.createdDateTime,
    required this.updatedDateTime,
    required this.flag,
  });

  /// Create Supplier from local SQLite row (Suppliers table)
  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['supplierId'] as int? ?? -1,
      userId: map['userId'] as int? ?? -1,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      deviceToken: map['deviceToken'] as String? ?? '',
      createdDateTime: map['createdDateTime'] as String? ?? '',
      updatedDateTime: map['updatedDateTime'] as String? ?? '',
      flag: map['flag'] as int? ?? 1,
    );
  }

  /// Create Supplier from server response (snake_case fields)
  factory Supplier.fromMapServerData(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int? ?? -1,
      userId: map['user_id'] as int? ?? -1,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone_no'] as String? ?? '',
      address: map['address'] as String? ?? '',
      deviceToken: map['device_token'] as String? ?? '',
      createdDateTime: map['created_at'] as String? ?? '',
      updatedDateTime: map['updated_at'] as String? ?? '',
      flag: map['flag'] as int? ?? 1,
    );
  }
//server response
//   0 =
// "id" -> 12
// 1 =
// "user_id" -> 65
// 2 =
// "code" -> "FBHR"
// 3 =
// "name" -> "FABHR"
// 4 =
// "phone_no" -> "1"
// 5 =
// "address" -> "foms"
// 6 =
// "device_token" -> ""
// 7 =
// "flag" -> 1
// 8 =
// "created_at" -> "2025-08-10 13:42:05"
// 9 =
// "updated_at" -> "2025-08-16 20:10:04"

  /// Convert to map for local SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'supplierId': id,
      'userId': userId,
      'code': code,
      'name': name,
      'phone': phone,
      'address': address,
      'deviceToken': deviceToken,
      'createdDateTime': createdDateTime,
      'updatedDateTime': updatedDateTime,
      'flag': flag,
    };
  }
}

