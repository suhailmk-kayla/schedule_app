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

  const SalesMan({
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
      id: map['salesManId'] as int? ?? -1,
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

  Map<String, dynamic> toMap() {
    return {
      'salesManId': id,
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

