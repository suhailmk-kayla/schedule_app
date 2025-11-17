/// SalesMan Model
/// Converted from KMP's SalesMan class
class SalesMan {
  final int id;
  final int userId;
  final String code;
  final String name;
  final String phone;
  final String address;
  final String deviceToken;
  final String createdDateTime;
  final String updatedDateTime;
  final int flag;
  final int salesManId;

  const SalesMan({
    required this.salesManId,
    required this.id,
    required this.userId,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.deviceToken,
    required this.createdDateTime,
    required this.updatedDateTime,
    required this.flag,
  });

  factory SalesMan.fromMap(Map<String, dynamic> map) {

    return SalesMan(
      salesManId: map['salesManId'] as int? ?? -1,
      id: map['id'] as int? ?? -1,
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

factory SalesMan.fromMapServerData(Map<String, dynamic> map) {
  return SalesMan(
    // Server 'id' maps to 'salesManId' (business ID, not auto-increment PK)
    salesManId: map['id'] as int? ?? -1,
    // Auto-increment primary key is set to -1 (DB will generate it)
    id: -1,
    // Server uses snake_case 'user_id', maps to camelCase 'userId'
    userId: map['user_id'] as int? ?? -1,
    code: map['code'] as String? ?? '',
    name: map['name'] as String? ?? '',
    // Server uses 'phone_no', maps to 'phone'
    phone: map['phone_no'] as String? ?? '',
    address: map['address'] as String? ?? '',
    // Server uses 'device_token', maps to 'deviceToken'
    deviceToken: map['device_token'] as String? ?? '',
    // Server uses 'created_at', maps to 'createdDateTime'
    createdDateTime: map['created_at'] as String? ?? '',
    // Server uses 'updated_at', maps to 'updatedDateTime'
    updatedDateTime: map['updated_at'] as String? ?? '',
    flag: map['flag'] as int? ?? 1,
  );
}

     //server response data
      //   "id": 12,
      // "user_id": 56,
      // "code": "1",
      // "name": "azad",
      // "phone_no": "9038714044",
      // "address": "foms",
      // "device_token": "",
      // "flag": 0,
      // "created_at": "2025-08-10 13:21:17",
      // "updated_at": "2025-08-10 14:21:18"

  Map<String, dynamic> toMap() {
    return {
      'salesManId': salesManId,
      'id': id,
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

    Map<String, dynamic> toMapLocalDatabase() {
    return {
      'salesManId': salesManId,
      // 'id': id,
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

