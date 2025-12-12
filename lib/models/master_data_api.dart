import 'package:json_annotation/json_annotation.dart';

part 'master_data_api.g.dart';
int _toIntFlexible(Object? v) => num.tryParse(v?.toString() ?? '')?.toInt() ?? -1;

// ============================================================================
// CATEGORY MODELS
// ============================================================================

/// Category API Response
/// Converted from KMP's CategoryApi.kt
@JsonSerializable()
class CategoryApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final Category data;

  const CategoryApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory CategoryApi.fromJson(Map<String, dynamic> json) =>
      _$CategoryApiFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryApiToJson(this);
}

/// Category List API Response
/// Converted from KMP's CategoryListApi
@JsonSerializable()
class CategoryListApi {
  final List<Category>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CategoryListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CategoryListApi.fromJson(Map<String, dynamic> json) =>
      _$CategoryListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryListApiToJson(this);
}

/// Category Model
/// Converted from KMP's Category class
@JsonSerializable()
class Category {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String remark;

  const Category({
    this.id = -1,
    this.name = '',
    this.remark = '',
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  /// Convert from database map (camelCase column names)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['categoryId'] as int? ?? -1,
      name: map['name'] as String? ?? '',
      remark: map['remark'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'categoryId': id,
      'name': name,
      'remark': remark,
      'flag': 1,
    };
  }
}

// ============================================================================
// SUB CATEGORY MODELS
// ============================================================================

/// SubCategory API Response
/// Converted from KMP's SubCategoryApi.kt
@JsonSerializable()
class SubCategoryApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final SubCategory data;

  const SubCategoryApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory SubCategoryApi.fromJson(Map<String, dynamic> json) =>
      _$SubCategoryApiFromJson(json);

  Map<String, dynamic> toJson() => _$SubCategoryApiToJson(this);
}

/// SubCategory List API Response
/// Converted from KMP's SubCategoryListApi
@JsonSerializable()
class SubCategoryListApi {
  final List<SubCategory>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const SubCategoryListApi({
    this.data,
    this.updatedDate = '',
  });

  factory SubCategoryListApi.fromJson(Map<String, dynamic> json) =>
      _$SubCategoryListApiFromJson(json);

  Map<String, dynamic> toJson() => _$SubCategoryListApiToJson(this);
}

/// SubCategory Model
/// Converted from KMP's SubCategory class
@JsonSerializable()
class SubCategory {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(name: 'cat_id', defaultValue: -1)
  final int catId;

  @JsonKey(defaultValue: '')
  final String remark;

  const SubCategory({
    this.id = -1,
    this.name = '',
    this.catId = -1,
    this.remark = '',
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) =>
      _$SubCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$SubCategoryToJson(this);

  /// Convert from database map (camelCase column names)
  factory SubCategory.fromMap(Map<String, dynamic> map) {
    return SubCategory(
      id: map['subCategoryId'] as int? ?? -1,
      name: map['name'] as String? ?? '',
      catId: map['parentId'] as int? ?? -1,
      remark: map['remark'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'subCategoryId': id,
      'parentId': catId,
      'name': name,
      'remark': remark,
      'flag': 1,
    };
  }
}

// ============================================================================
// UNITS MODELS
// ============================================================================

/// Unit API Response
/// Converted from KMP's UnitApi.kt
@JsonSerializable()
class UnitApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final Units data;

  const UnitApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory UnitApi.fromJson(Map<String, dynamic> json) => _$UnitApiFromJson(json);

  Map<String, dynamic> toJson() => _$UnitApiToJson(this);
}

/// Unit List API Response
/// Converted from KMP's UnitListApi
@JsonSerializable()
class UnitListApi {
  final List<Units>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const UnitListApi({
    this.data,
    this.updatedDate = '',
  });

  factory UnitListApi.fromJson(Map<String, dynamic> json) =>
      _$UnitListApiFromJson(json);

  Map<String, dynamic> toJson() => _$UnitListApiToJson(this);
}

/// Units Model
/// Converted from KMP's Units class
@JsonSerializable()
class Units {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'display_name', defaultValue: '')
  final String displayName;

  @JsonKey(defaultValue: 0)
  final int type;

  @JsonKey(name: 'base_id', defaultValue: -1)
  final int baseId;

  @JsonKey(name: 'base_qty', defaultValue: 0.0)
  final double baseQty;

  @JsonKey(defaultValue: '')
  final String comment;

  const Units({
    this.id = -1,
    this.name = '',
    this.code = '',
    this.displayName = '',
    this.type = 0,
    this.baseId = -1,
    this.baseQty = 0.0,
    this.comment = '',
  });

  factory Units.fromJson(Map<String, dynamic> json) => _$UnitsFromJson(json);

  Map<String, dynamic> toJson() => _$UnitsToJson(this);

  /// Convert from database map (camelCase column names)
  factory Units.fromMap(Map<String, dynamic> map) {
    return Units(
      id: map['unitId'] as int? ?? -1,
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      type: map['type'] as int? ?? 0,
      baseId: map['baseId'] as int? ?? -1,
      baseQty: (map['baseQty'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'unitId': id,
      'code': code,
      'name': name,
      'displayName': displayName,
      'type': type,
      'baseId': baseId,
      'baseQty': baseQty,
      'comment': comment,
      'flag': 1,
    };
  }
}

// ============================================================================
// CUSTOMER MODELS
// ============================================================================

/// Customer Success API Response
/// Converted from KMP's CustomerSuccessApi.kt
@JsonSerializable()
class CustomerSuccessApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final Customer data;

  const CustomerSuccessApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory CustomerSuccessApi.fromJson(Map<String, dynamic> json) =>
      _$CustomerSuccessApiFromJson(json);

  /// Custom fromJson with merge support for partial API responses
  /// Merges partial API response with existing customer data during deserialization
  /// This prevents default values from overwriting unchanged fields
  factory CustomerSuccessApi.fromJsonWithMerge(
    Map<String, dynamic> json, {
    Customer? existingCustomer,
  }) {
    final status = (json['status'] as num?)?.toInt() ?? 2;
    final message = json['message'] as String? ?? '';
    
    // Parse the data object manually to avoid default values
    final dataJson = json['data'] as Map<String, dynamic>?;
    if (dataJson == null) {
      throw FormatException('Missing data field in CustomerSuccessApi response');
    }
    
    // Create Customer from partial JSON without defaults
    final partialCustomer = Customer._fromJsonPartial(dataJson);
    
    // Merge with existing customer if provided
    final mergedCustomer = existingCustomer != null
        ? partialCustomer.mergeWith(existingCustomer)
        : partialCustomer;
    
    return CustomerSuccessApi(
      status: status,
      message: message,
      data: mergedCustomer,
    );
  }

  Map<String, dynamic> toJson() => _$CustomerSuccessApiToJson(this);

}

/// Customer List API Response
/// Converted from KMP's CustomerListApi
@JsonSerializable()
class CustomerListApi {
  final List<Customer>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CustomerListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CustomerListApi.fromJson(Map<String, dynamic> json) =>
      _$CustomerListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerListApiToJson(this);
}

/// Customer Model
/// Converted from KMP's Customer class
@JsonSerializable()
class Customer {
    // ❌ this should not participate in JSON mapping
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? id;

  // ✔ API id should map to customerId
  @JsonKey(name: 'id', defaultValue: -1)
  final int? customerId;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'phone_no', defaultValue: '')
  final String phoneNo;

  @JsonKey(name: 'rout_id', defaultValue: -1)
  final int routId;

  @JsonKey(name: 'sales_man_id', defaultValue: -1)
  final int salesManId;

  @JsonKey(fromJson: _toIntFlexible, defaultValue: -1)
  final int rating;

  @JsonKey(defaultValue: '')
  final String address;

  final int? flag;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Customer({
    this.customerId,
    this.id = -1,
    this.name = '',
    this.code = '',
    this.phoneNo = '',
    this.routId = -1,
    this.salesManId = -1,
    this.rating = -1,
    this.address = '',
    this.flag,
    this.createdAt,
    this.updatedAt,
  });


  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  /// Private factory for parsing partial JSON responses without applying defaults
  /// Used internally by CustomerSuccessApi.fromJsonWithMerge
  /// Creates Customer with only fields present in JSON
  /// Fields not present will use sentinel values that mergeWith can detect
  factory Customer._fromJsonPartial(Map<String, dynamic> json) {
    // Check which fields are actually present in JSON
    final hasId = json.containsKey('id');
    final hasName = json.containsKey('name');
    final hasCode = json.containsKey('code');
    final hasPhoneNo = json.containsKey('phone_no');
    final hasAddress = json.containsKey('address');
    final hasRoutId = json.containsKey('rout_id');
    final hasSalesManId = json.containsKey('sales_man_id');
    final hasRating = json.containsKey('rating');
    final hasFlag = json.containsKey('flag');
    final hasCreatedAt = json.containsKey('created_at');
    final hasUpdatedAt = json.containsKey('updated_at');
    
    return Customer(
      // Only set values for fields that were present in JSON
      // Use sentinel values (-2 for ints, null for nullable) for missing fields
      // mergeWith will detect these and preserve existing values
      customerId: hasId ? (json['id'] as num?)?.toInt() : null,
      name: hasName ? (json['name'] as String? ?? '') : '',
      code: hasCode ? (json['code'] as String? ?? '') : '',
      phoneNo: hasPhoneNo ? (json['phone_no'] as String? ?? '') : '',
      address: hasAddress ? (json['address'] as String? ?? '') : '',
      routId: hasRoutId ? ((json['rout_id'] as num?)?.toInt() ?? -1) : -2, // -2 is sentinel for "not present"
      salesManId: hasSalesManId ? ((json['sales_man_id'] as num?)?.toInt() ?? -1) : -2, // -2 is sentinel
      rating: hasRating ? _toIntFlexible(json['rating']) : -2, // -2 is sentinel
      flag: hasFlag ? (json['flag'] as num?)?.toInt() : null,
      createdAt: hasCreatedAt ? (json['created_at'] as String?) : null,
      updatedAt: hasUpdatedAt ? (json['updated_at'] as String?) : null,
    );
  }

  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  /// Convert from database map (camelCase column names)
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int? ?? -1, // Local DB primary key (AUTOINCREMENT)
      customerId: map['customerId'] as int? ?? -1, // Server ID
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      phoneNo: map['phone'] as String? ?? '',
      routId: map['routId'] as int? ?? -1,
      salesManId: map['salesmanId'] as int? ?? -1,
      rating: map['rating'] as int? ?? -1,
      address: map['address'] as String? ?? '',
      flag: map['flag'] as int?,
      createdAt: map['createdDateTime'] as String?,
      updatedAt: map['updatedDateTime'] as String?,
    );
  }

  /// Convert to database map (camelCase column names)
  /// Note: id (local PK) is not included as it's AUTOINCREMENT
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId ?? -1, // Use server ID, not local id
      'code': code,
      'name': name,
      'phone': phoneNo,
      'address': address,
      'routId': routId,
      'salesmanId': salesManId,
      'rating': rating,
      'deviceToken': '',
      'createdDateTime': createdAt ?? '',
      'updatedDateTime': updatedAt ?? '',
      'flag': flag ?? 1,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? code,
    String? phoneNo,
    int? routId,
    int? salesManId,
    int? rating,
    String? address,
    int? flag,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      phoneNo: phoneNo ?? this.phoneNo,
      routId: routId ?? this.routId,
      salesManId: salesManId ?? this.salesManId,
      rating: rating ?? this.rating,
      address: address ?? this.address,
      flag: flag ?? this.flag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Merge partial API response with existing customer data
  /// Only uses API response values if they were present in the response
  /// Uses sentinel values (-2 for ints) to detect missing fields
  /// This handles cases where API returns only changed fields
  Customer mergeWith(Customer existing) {
    return Customer(
      id: existing.id, // Always preserve local DB primary key
      customerId: customerId ?? existing.customerId,
      // For strings: use API value if not empty, otherwise preserve existing
      // For ints: use API value if not sentinel (-2), otherwise preserve existing
      code: code.isNotEmpty ? code : existing.code,
      name: name.isNotEmpty ? name : existing.name,
      phoneNo: phoneNo.isNotEmpty ? phoneNo : existing.phoneNo,
      address: address.isNotEmpty ? address : existing.address,
      routId: routId != -2 ? routId : existing.routId, // -2 means field was not in JSON
      salesManId: salesManId != -2 ? salesManId : existing.salesManId, // -2 means field was not in JSON
      rating: rating != -2 ? rating : existing.rating, // -2 means field was not in JSON
      flag: flag ?? existing.flag, // null means field was not in JSON
      createdAt: createdAt ?? existing.createdAt, // null means field was not in JSON
      updatedAt: updatedAt ?? existing.updatedAt, // null means field was not in JSON
    );
  }
}

/// Customer With Names Model
/// Represents Customer with joined Salesman and Route names
/// Converted from KMP's GetAllCustomersWithNames data class
/// Used for displaying customers in list with salesman and route names
class CustomerWithNames {
  // Customer fields
  final int id;
  final int customerId;
  final String code;
  final String name;
  final String phone;
  final String address;
  final int routId;
  final int salesmanId;
  final int rating;
  final String deviceToken;
  final String createdDateTime;
  final String updatedDateTime;
  final int flag;

  // Joined fields from SalesMan and Routes tables
  final String? saleman; // Salesman name (nullable)
  final String? route; // Route name (nullable)

  const CustomerWithNames({
    required this.id,
    required this.customerId,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.routId,
    required this.salesmanId,
    required this.rating,
    required this.deviceToken,
    required this.createdDateTime,
    required this.updatedDateTime,
    required this.flag,
    this.saleman,
    this.route,
  });

  /// Convert from database map (JOIN query result)
  /// Matches KMP's GetAllCustomersWithNames constructor
  factory CustomerWithNames.fromMap(Map<String, dynamic> map) {
    return CustomerWithNames(
      id: map['id'] as int? ?? 0,
      customerId: map['customerId'] as int? ?? map['id'] as int? ?? 0,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      routId: map['routId'] as int? ?? -1,
      salesmanId: map['salesmanId'] as int? ?? -1,
      rating: map['rating'] as int? ?? -1,
      deviceToken: map['deviceToken'] as String? ?? '',
      createdDateTime: map['createdDateTime'] as String? ?? '',
      updatedDateTime: map['updatedDateTime'] as String? ?? '',
      flag: map['flag'] as int? ?? 1,
      saleman: map['saleman'] as String?,
      route: map['route'] as String?,
    );
  }

  /// Convert to Customer model (for compatibility)
  Customer toCustomer() {
    return Customer(
      id: id, // Local DB primary key
      customerId: customerId, // Server ID
      name: name,
      code: code,
      phoneNo: phone,
      address: address,
      routId: routId,
      salesManId: salesmanId,
      rating: rating,
      flag: flag,
      createdAt: createdDateTime.isNotEmpty ? createdDateTime : null,
      updatedAt: updatedDateTime.isNotEmpty ? updatedDateTime : null,
    );
  }
}

// ============================================================================
// USER MODELS
// ============================================================================

/// User Success API Response
/// Converted from KMP's UserSuccessApi.kt
@JsonSerializable()
class UserSuccessApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final User user;

  @JsonKey(name: 'userData')
  final UserData? userData;

  const UserSuccessApi({
    this.status = 2,
    this.message = '',
    required this.user,
    this.userData,
  });

  factory UserSuccessApi.fromJson(Map<String, dynamic> json) =>
      _$UserSuccessApiFromJson(json);

  /// Custom fromJson with merge support for partial API responses
  /// Handles cases where API returns partial data in 'data' field instead of 'user' field
  /// Merges partial API response with existing user data during deserialization
  /// This prevents default values from overwriting unchanged fields
  factory UserSuccessApi.fromJsonWithMerge(
    Map<String, dynamic> json, {
    User? existingUser,
  }) {
    final status = (json['status'] as num?)?.toInt() ?? 2;
    final message = json['message'] as String? ?? '';
    
    // Check if response has 'data' field (partial update) or 'user' field (full user object)
    final dataJson = json['data'] as Map<String, dynamic>?;
    final userJson = json['user'] as Map<String, dynamic>?;
    
    User mergedUser;
    
    if (dataJson != null && userJson == null) {
      // Partial update response: data field contains partial user data
      // Parse the data object manually to avoid default values
      final partialUser = User._fromJsonPartial(dataJson);
      
      // Merge with existing user if provided
      mergedUser = existingUser != null
          ? partialUser.mergeWith(existingUser)
          : partialUser;
    } else if (userJson != null) {
      // Full user response: use standard parsing
      final user = User.fromJson(userJson);
      
      // Merge with existing user if provided (for consistency)
      mergedUser = existingUser != null
          ? user.mergeWith(existingUser)
          : user;
    } else {
      throw FormatException('Missing both data and user fields in UserSuccessApi response');
    }
    
    // Parse userData if present (for supplier/salesman creation)
    UserData? userData;
    final userDataJson = json['userData'] as Map<String, dynamic>?;
    if (userDataJson != null) {
      userData = UserData.fromJson(userDataJson);
    }
    
    return UserSuccessApi(
      status: status,
      message: message,
      user: mergedUser,
      userData: userData,
    );
  }

  Map<String, dynamic> toJson() => _$UserSuccessApiToJson(this);
}

/// User List API Response
/// Converted from KMP's UserListApi
@JsonSerializable()
class UserListApi {
  final List<UserDown>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const UserListApi({
    this.data,
    this.updatedDate = '',
  });

  factory UserListApi.fromJson(Map<String, dynamic> json) =>
      _$UserListApiFromJson(json);

  Map<String, dynamic> toJson() => _$UserListApiToJson(this);
}

/// User Model
/// Converted from KMP's User class
/// CRITICAL: Distinguishes between local database id (PK) and server userId
@JsonSerializable(explicitToJson: true)
class User {
  @JsonKey(includeFromJson: false, includeToJson: false, defaultValue: -1)
  final int id; // Local database primary key (not in API JSON)

  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to userId
  final int? userId; // Server ID from API

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'phone_no', defaultValue: '')
  final String phoneNo;

  @JsonKey(name: 'cat_id', defaultValue: -1)
  final int catId;

  @JsonKey(defaultValue: '')
  final String address;

  const User({
    this.id = -1, // Local PK, not required with default value
    this.userId,
    this.name = '',
    this.code = '',
    this.phoneNo = '',
    this.catId = -1,
    this.address = '',
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Private factory for parsing partial JSON responses without applying defaults
  /// Used internally by UserSuccessApi.fromJsonWithMerge
  /// Creates User with only fields present in JSON
  /// Fields not present will use sentinel values that mergeWith can detect
  factory User._fromJsonPartial(Map<String, dynamic> json) {
    // Check which fields are actually present in JSON
    final hasId = json.containsKey('id');
    final hasName = json.containsKey('name');
    final hasCode = json.containsKey('code');
    final hasPhoneNo = json.containsKey('phone_no');
    final hasCatId = json.containsKey('cat_id');
    final hasAddress = json.containsKey('address');
    
    return User(
      // Only set values for fields that were present in JSON
      // Use sentinel values (-2 for ints, null for nullable) for missing fields
      // mergeWith will detect these and preserve existing values
      userId: hasId ? (json['id'] as num?)?.toInt() : null,
      name: hasName ? (json['name'] as String? ?? '') : '',
      code: hasCode ? (json['code'] as String? ?? '') : '',
      phoneNo: hasPhoneNo ? (json['phone_no'] as String? ?? '') : '',
      catId: hasCatId ? ((json['cat_id'] as num?)?.toInt() ?? -1) : -2, // -2 is sentinel for "not present"
      address: hasAddress ? (json['address'] as String? ?? '') : '',
    );
  }

  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Convert from database map (camelCase column names)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int? ?? -1, // Local PK from database
      userId: map['userId'] as int? ?? -1, // Server ID from database
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      phoneNo: map['phone'] as String? ?? '',
      catId: map['categoryId'] as int? ?? -1,
      address: map['address'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      // Note: 'id' (local PK) is not included - handled separately in repository
      'userId': userId ?? -1, // Server ID
      'code': code,
      'name': name,
      'phone': phoneNo,
      'address': address,
      'categoryId': catId,
      'password': '',
      'createdDateTime': '',
      'updatedDateTime': '',
      'deviceToken': '',
      'multiDeviceLogin': 0,
      'flag': 1,
    };
  }

  /// Merge partial API response with existing user data
  /// Only uses API response values if they were present in the response
  /// Uses sentinel values (-2 for ints) to detect missing fields
  /// This handles cases where API returns only changed fields
  User mergeWith(User existing) {
    return User(
      id: existing.id, // Always preserve local DB primary key
      userId: userId ?? existing.userId,
      // For strings: use API value if not empty, otherwise preserve existing
      // For ints: use API value if not sentinel (-2), otherwise preserve existing
      code: code.isNotEmpty ? code : existing.code,
      name: name.isNotEmpty ? name : existing.name,
      phoneNo: phoneNo.isNotEmpty ? phoneNo : existing.phoneNo,
      address: address.isNotEmpty ? address : existing.address,
      catId: catId != -2 ? catId : existing.catId, // -2 means field was not in JSON
    );
  }
}

/// User Down Model (for download/sync)
/// Converted from KMP's UserDown class
@JsonSerializable()
class UserDown {

  @JsonKey(defaultValue: -1,includeToJson: false,includeFromJson: false)
  final int? id;

  @JsonKey(name: 'id', defaultValue: -1)
  final int? userId;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'phone_no', defaultValue: '')
  final String phoneNo;

  @JsonKey(name: 'user_cat_id', defaultValue: -1)
  final int userCatId;

  @JsonKey(defaultValue: '')
  final String address;

  final int? flag;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const UserDown({
    this.userId,
    this.id,
    this.name = '',
    this.code = '',
    this.phoneNo = '',
    this.userCatId = -1,
    this.address = '',
    this.flag,
    this.createdAt,
    this.updatedAt,
  });

  factory UserDown.fromJson(Map<String, dynamic> json) =>
      _$UserDownFromJson(json);

  Map<String, dynamic> toJson() => _$UserDownToJson(this);
}

/// User Data List API Response
/// Converted from KMP's UserDataListApi
@JsonSerializable()
class UserDataListApi {
  final List<UserData>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const UserDataListApi({
    this.data,
    this.updatedDate = '',
  });

  factory UserDataListApi.fromJson(Map<String, dynamic> json) =>
      _$UserDataListApiFromJson(json);

  Map<String, dynamic> toJson() => _$UserDataListApiToJson(this);
}

/// User Data Model
/// Converted from KMP's UserData class
@JsonSerializable()
class UserData {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(name: 'user_id')
  final int? userId;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'phone_no', defaultValue: '')
  final String phoneNo;

  @JsonKey(defaultValue: '')
  final String address;

  final int? flag;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const UserData({
    this.id = -1,
    this.userId,
    this.name = '',
    this.code = '',
    this.phoneNo = '',
    this.address = '',
    this.flag,
    this.createdAt,
    this.updatedAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) =>
      _$UserDataFromJson(json);

  Map<String, dynamic> toJson() => _$UserDataToJson(this);
}

// ============================================================================
// ROUTE MODELS
// ============================================================================

/// Add Route API Response
/// Converted from KMP's AddRouteApi.kt
@JsonSerializable()
class AddRouteApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final Route data;

  const AddRouteApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory AddRouteApi.fromJson(Map<String, dynamic> json) =>
      _$AddRouteApiFromJson(json);

  Map<String, dynamic> toJson() => _$AddRouteApiToJson(this);
}

/// Route List API Response
/// Converted from KMP's RouteListApi
@JsonSerializable()
class RouteListApi {
  final List<Route>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const RouteListApi({
    this.data,
    this.updatedDate = '',
  });

  factory RouteListApi.fromJson(Map<String, dynamic> json) =>
      _$RouteListApiFromJson(json);

  Map<String, dynamic> toJson() => _$RouteListApiToJson(this);
}

/// Route Model
/// Converted from KMP's Route class
/// CRITICAL: Distinguishes between local database id (PK) and server routeId
@JsonSerializable()
class Route {
  @JsonKey(defaultValue: -1, includeToJson: false, includeFromJson: false)
  final int? id; // Local DB primary key (AUTOINCREMENT)

  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to routeId
  final int? routeId; // Server ID from API

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String code;

  @JsonKey(name: 'salesman_id', defaultValue: -1)
  final int salesmanId;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Route({
    this.id,
    this.routeId,
    this.name = '',
    this.code = '',
    this.salesmanId = -1,
    this.createdAt,
    this.updatedAt,
  });

  factory Route.fromJson(Map<String, dynamic> json) => _$RouteFromJson(json);

  Map<String, dynamic> toJson() => _$RouteToJson(this);

  /// Convert from database map (camelCase column names)
  factory Route.fromMap(Map<String, dynamic> map) {
    return Route(
      id: map['id'] as int? ?? -1, // Local DB primary key (AUTOINCREMENT)
      routeId: map['routeId'] as int? ?? -1, // Server ID from database
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      salesmanId: map['salesmanId'] as int? ?? -1,
      createdAt: map['createdDateTime'] as String?,
      updatedAt: map['updatedDateTime'] as String?,
    );
  }

  /// Convert to database map (camelCase column names)
  /// Note: id (local PK) is not included as it's AUTOINCREMENT
  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId ?? -1, // Use server ID, not local id
      'code': code,
      'name': name,
      'salesmanId': salesmanId,
      'createdDateTime': createdAt ?? '',
      'updatedDateTime': updatedAt ?? '',
      'flag': 1,
    };
  }
}

/// Route with Salesman Model
/// Used for join query results (GetAllRoutesWithSaleman)
/// Converted from KMP's GetAllRoutesWithSaleman
class RouteWithSalesman {
  final String salesman; // Salesman name from join
  final Route route; // Route data

  const RouteWithSalesman({
    required this.salesman,
    required this.route,
  });

  /// Convert from database map (join query result)
  factory RouteWithSalesman.fromMap(Map<String, dynamic> map) {
    return RouteWithSalesman(
      salesman: map['salesman'] as String? ?? '',
      route: Route.fromMap(map),
    );
  }

  /// Get route ID (for compatibility)
  int get routeId => route.routeId ?? -1;
  
  /// Get route name (for compatibility)
  String get name => route.name;
}

// ============================================================================
// OUT OF STOCK MODELS
// ============================================================================

/// OutOfStock API Response
/// Converted from KMP's OutOfStockApi.kt
@JsonSerializable()
class OutOfStockApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final OutOfStock data;

  const OutOfStockApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory OutOfStockApi.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockApiFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockApiToJson(this);
}

/// OutOfStock All API Response
/// Converted from KMP's OutOfStockAllApi
@JsonSerializable()
class OutOfStockAllApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final List<OutOfStock> data;

  const OutOfStockAllApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory OutOfStockAllApi.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockAllApiFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockAllApiToJson(this);
}

/// OutOfStock List API Response
/// Converted from KMP's OutOfStockListApi
@JsonSerializable()
class OutOfStockListApi {
  final List<OutOfStock>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const OutOfStockListApi({
    this.data,
    this.updatedDate = '',
  });

  factory OutOfStockListApi.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockListApiFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockListApiToJson(this);
}

/// OutOfStock Sub List API Response
/// Converted from KMP's OutOfStockSubListApi
@JsonSerializable()
class OutOfStockSubListApi {
  final List<OutOfStockSub>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const OutOfStockSubListApi({
    this.data,
    this.updatedDate = '',
  });

  factory OutOfStockSubListApi.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockSubListApiFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockSubListApiToJson(this);
}

/// OutOfStock Model
/// Converted from KMP's OutOfStock class
@JsonSerializable()
class OutOfStock {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(name: 'outos_order_sub_id', defaultValue: -1)
  final int outosOrderSubId;

  @JsonKey(name: 'outos_cust_id', defaultValue: -1)
  final int outosCustId;

  @JsonKey(name: 'outos_sales_man_id', defaultValue: -1)
  final int outosSalesManId;

  @JsonKey(name: 'outos_stock_keeper_id', defaultValue: -1)
  final int outosStockKeeperId;

  @JsonKey(name: 'outos_date_and_time', defaultValue: '')
  final String outosDateAndTime;

  @JsonKey(name: 'outos_prod_id', defaultValue: -1)
  final int outosProdId;

  @JsonKey(name: 'outos_unit_id', defaultValue: -1)
  final int outosUnitId;

  @JsonKey(name: 'outos_car_id', defaultValue: -1)
  final int outosCarId;

  @JsonKey(name: 'outos_qty', defaultValue: 0.0)
  final double outosQty;

  @JsonKey(name: 'outos_available_qty', defaultValue: 0.0)
  final double outosAvailableQty;

  @JsonKey(name: 'outos_unit_base_qty', defaultValue: 0.0)
  final double outosUnitBaseQty;

  @JsonKey(name: 'outos_note')
  final String? outosNote;

  @JsonKey(name: 'outos_narration')
  final String? outosNarration;

  @JsonKey(name: 'outos_is_compleated_flag', defaultValue: -1)
  final int outosIsCompleatedFlag;

  @JsonKey(name: 'outos_flag')
  final int? outosFlag;

  @JsonKey(defaultValue: '')
  final String uuid;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  final List<OutOfStockSub>? items;

  const OutOfStock({
    this.id = -1,
    this.outosOrderSubId = -1,
    this.outosCustId = -1,
    this.outosSalesManId = -1,
    this.outosStockKeeperId = -1,
    this.outosDateAndTime = '',
    this.outosProdId = -1,
    this.outosUnitId = -1,
    this.outosCarId = -1,
    this.outosQty = 0.0,
    this.outosAvailableQty = 0.0,
    this.outosUnitBaseQty = 0.0,
    this.outosNote,
    this.outosNarration,
    this.outosIsCompleatedFlag = -1,
    this.outosFlag,
    this.uuid = '',
    this.createdAt,
    this.updatedAt,
    this.items,
  });

  factory OutOfStock.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockToJson(this);

  /// Convert from database map (camelCase column names) - OutOfStockMaster table
  factory OutOfStock.fromMap(Map<String, dynamic> map) {
    return OutOfStock(
      id: map['oospMasterId'] as int? ?? -1,
      outosOrderSubId: map['orderSubId'] as int? ?? -1,
      outosCustId: map['custId'] as int? ?? -1,
      outosSalesManId: map['salesmanId'] as int? ?? -1,
      outosStockKeeperId: map['storekeeperId'] as int? ?? -1,
      outosDateAndTime: map['dateAndTime'] as String? ?? '',
      outosProdId: map['productId'] as int? ?? -1,
      outosUnitId: map['unitId'] as int? ?? -1,
      outosCarId: map['carId'] as int? ?? -1,
      outosQty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      outosAvailableQty: (map['availQty'] as num?)?.toDouble() ?? 0.0,
      outosUnitBaseQty: (map['baseQty'] as num?)?.toDouble() ?? 0.0,
      outosNote: map['note'] as String?,
      outosNarration: map['narration'] as String?,
      outosIsCompleatedFlag: map['isCompleteflag'] as int? ?? -1,
      outosFlag: map['flag'] as int?,
      uuid: map['UUID'] as String? ?? '',
      createdAt: map['createdDateTime'] as String?,
      updatedAt: map['updatedDateTime'] as String?,
    );
  }

  /// Convert to database map (camelCase column names) - OutOfStockMaster table
  Map<String, dynamic> toMap() {
    return {
      'oospMasterId': id,
      'orderSubId': outosOrderSubId,
      'custId': outosCustId,
      'salesmanId': outosSalesManId,
      'storekeeperId': outosStockKeeperId,
      'dateAndTime': outosDateAndTime,
      'productId': outosProdId,
      'unitId': outosUnitId,
      'carId': outosCarId,
      'qty': outosQty,
      'availQty': outosAvailableQty,
      'baseQty': outosUnitBaseQty,
      'note': outosNote ?? '',
      'narration': outosNarration ?? '',
      'createdDateTime': createdAt ?? '',
      'updatedDateTime': updatedAt ?? '',
      'isCompleteflag': outosIsCompleatedFlag,
      'flag': outosFlag ?? 0,
      'UUID': uuid,
      'isViewed': 0,
    };
  }
}

/// OutOfStock Sub Model
/// Converted from KMP's OutOfStockSub class
@JsonSerializable()
class OutOfStockSub {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(name: 'outos_sub_outos_id', defaultValue: -1)
  final int outosSubOutosId;

  @JsonKey(name: 'outos_sub_order_sub_id', defaultValue: -1)
  final int outosSubOrderSubId;

  @JsonKey(name: 'outos_sub_cust_id', defaultValue: -1)
  final int outosSubCustId;

  @JsonKey(name: 'outos_sub_sales_man_id', defaultValue: -1)
  final int outosSubSalesManId;

  @JsonKey(name: 'outos_sub_stock_keeper_id', defaultValue: -1)
  final int outosSubStockKeeperId;

  @JsonKey(name: 'outos_sub_date_and_time', defaultValue: '')
  final String outosSubDateAndTime;

  @JsonKey(name: 'outos_sub_supp_id', defaultValue: -1)
  final int outosSubSuppId;

  @JsonKey(name: 'outos_sub_prod_id', defaultValue: -1)
  final int outosSubProdId;

  @JsonKey(name: 'outos_sub_unit_id', defaultValue: -1)
  final int outosSubUnitId;

  @JsonKey(name: 'outos_sub_car_id', defaultValue: -1)
  final int outosSubCarId;

  @JsonKey(name: 'outos_sub_rate', defaultValue: 0.0)
  final double outosSubRate;

  @JsonKey(name: 'outos_sub_updated_rate', defaultValue: 0.0)
  final double outosSubUpdatedRate;

  @JsonKey(name: 'outos_sub_qty', defaultValue: 0.0)
  final double outosSubQty;

  @JsonKey(name: 'outos_sub_available_qty', defaultValue: 0.0)
  final double outosSubAvailableQty;

  @JsonKey(name: 'outos_sub_unit_base_qty', defaultValue: 0.0)
  final double outosSubUnitBaseQty;

  @JsonKey(name: 'outos_sub_status_flag', defaultValue: 1)
  final int outosSubStatusFlag;

  @JsonKey(name: 'outos_sub_is_checked_flag', defaultValue: 0)
  final int outosSubIsCheckedFlag;

  @JsonKey(name: 'outos_sub_note')
  final String? outosSubNote;

  @JsonKey(name: 'outos_sub_narration')
  final String? outosSubNarration;

  @JsonKey(name: 'outos_sub_flag')
  final int? outosSubFlag;

  @JsonKey(defaultValue: '')
  final String uuid;

  @JsonKey(name: 'created_at', defaultValue: '')
  final String createdAt;

  @JsonKey(name: 'updated_at', defaultValue: '')
  final String updatedAt;

  const OutOfStockSub({
    this.id = -1,
    this.outosSubOutosId = -1,
    this.outosSubOrderSubId = -1,
    this.outosSubCustId = -1,
    this.outosSubSalesManId = -1,
    this.outosSubStockKeeperId = -1,
    this.outosSubDateAndTime = '',
    this.outosSubSuppId = -1,
    this.outosSubProdId = -1,
    this.outosSubUnitId = -1,
    this.outosSubCarId = -1,
    this.outosSubRate = 0.0,
    this.outosSubUpdatedRate = 0.0,
    this.outosSubQty = 0.0,
    this.outosSubAvailableQty = 0.0,
    this.outosSubUnitBaseQty = 0.0,
    this.outosSubStatusFlag = 1,
    this.outosSubIsCheckedFlag = 0,
    this.outosSubNote,
    this.outosSubNarration,
    this.outosSubFlag,
    this.uuid = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory OutOfStockSub.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockSubFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockSubToJson(this);

  /// Convert from database map (camelCase column names) - OutOfStockProducts table
  factory OutOfStockSub.fromMap(Map<String, dynamic> map) {
    return OutOfStockSub(
      id: map['oospId'] as int? ?? -1,
      outosSubOutosId: map['oospMasterId'] as int? ?? -1,
      outosSubOrderSubId: map['orderSubId'] as int? ?? -1,
      outosSubCustId: map['custId'] as int? ?? -1,
      outosSubSalesManId: map['salesmanId'] as int? ?? -1,
      outosSubStockKeeperId: map['storekeeperId'] as int? ?? -1,
      outosSubDateAndTime: map['dateAndTime'] as String? ?? '',
      outosSubSuppId: map['supplierId'] as int? ?? -1,
      outosSubProdId: map['productId'] as int? ?? -1,
      outosSubUnitId: map['unitId'] as int? ?? -1,
      outosSubCarId: map['carId'] as int? ?? -1,
      outosSubRate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      outosSubUpdatedRate: (map['updateRate'] as num?)?.toDouble() ?? 0.0,
      outosSubQty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      outosSubAvailableQty: (map['availQty'] as num?)?.toDouble() ?? 0.0,
      outosSubUnitBaseQty: (map['baseQty'] as num?)?.toDouble() ?? 0.0,
      outosSubStatusFlag: map['oospFlag'] as int? ?? 1,
      outosSubIsCheckedFlag: map['isCheckedflag'] as int? ?? 0,
      outosSubNote: map['note'] as String?,
      outosSubNarration: map['narration'] as String?,
      outosSubFlag: map['flag'] as int?,
      uuid: map['UUID'] as String? ?? '',
      createdAt: map['createdDateTime'] as String? ?? '',
      updatedAt: map['updatedDateTime'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names) - OutOfStockProducts table
  Map<String, dynamic> toMap() {
    return {
      'oospId': id,
      'oospMasterId': outosSubOutosId,
      'orderSubId': outosSubOrderSubId,
      'custId': outosSubCustId,
      'salesmanId': outosSubSalesManId,
      'storekeeperId': outosSubStockKeeperId,
      'dateAndTime': outosSubDateAndTime,
      'supplierId': outosSubSuppId,
      'productId': outosSubProdId,
      'unitId': outosSubUnitId,
      'carId': outosSubCarId,
      'rate': outosSubRate,
      'updateRate': outosSubUpdatedRate,
      'qty': outosSubQty,
      'availQty': outosSubAvailableQty,
      'baseQty': outosSubUnitBaseQty,
      'note': outosSubNote ?? '',
      'narration': outosSubNarration ?? '',
      'oospFlag': outosSubStatusFlag,
      'createdDateTime': createdAt,
      'updatedDateTime': updatedAt,
      'isCheckedflag': outosSubIsCheckedFlag,
      'flag': outosSubFlag ?? 0,
      'UUID': uuid,
      'isViewed': 0,
    };
  }
}

/// OutOfStock Sub API Response (single item wrapper)
/// Converted from KMP's OutOfStockSubApi.kt
@JsonSerializable()
class OutOfStockSubApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final OutOfStockSub data;

  const OutOfStockSubApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory OutOfStockSubApi.fromJson(Map<String, dynamic> json) =>
      _$OutOfStockSubApiFromJson(json);

  Map<String, dynamic> toJson() => _$OutOfStockSubApiToJson(this);
}

// ============================================================================
// OUT OF STOCK "WITH DETAILS" MODELS (for join queries)
// ============================================================================

/// OutOfStockMasterWithDetails
/// Wrapper model that includes joined fields from database queries
/// Matching KMP's OutOFStockMasterWithDetails
class OutOfStockMasterWithDetails {
  final OutOfStock outOfStock;
  
  // Joined fields from query
  final String unitName;
  final String unitDispName;
  final String productName;
  final String salesman;
  final String supplier;
  final String storekeeper;
  final String customerName;
  final int isViewed; // From OutOfStockMaster table

  const OutOfStockMasterWithDetails({
    required this.outOfStock,
    this.unitName = '',
    this.unitDispName = '',
    this.productName = '',
    this.salesman = '',
    this.supplier = '',
    this.storekeeper = '',
    this.customerName = '',
    this.isViewed = 0,
  });

  /// Convert from database map (join query result)
  factory OutOfStockMasterWithDetails.fromMap(Map<String, dynamic> map) {
    return OutOfStockMasterWithDetails(
      outOfStock: OutOfStock.fromMap(map),
      unitName: map['unitName'] as String? ?? '',
      unitDispName: map['unitDispName'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      salesman: map['salesman'] as String? ?? '',
      supplier: map['supplier'] as String? ?? '',
      storekeeper: map['storekeeper'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      isViewed: map['isViewed'] as int? ?? 0,
    );
  }

  // Convenience getters matching KMP property names
  int get oospMasterId => outOfStock.id;
  int get orderSubId => outOfStock.outosOrderSubId;
  int get custId => outOfStock.outosCustId;
  int get salesmanId => outOfStock.outosSalesManId;
  int get storekeeperId => outOfStock.outosStockKeeperId;
  String get dateAndTime => outOfStock.outosDateAndTime;
  int get productId => outOfStock.outosProdId;
  int get unitId => outOfStock.outosUnitId;
  int get carId => outOfStock.outosCarId;
  double get qty => outOfStock.outosQty;
  double get availQty => outOfStock.outosAvailableQty;
  double get baseQty => outOfStock.outosUnitBaseQty;
  String get note => outOfStock.outosNote ?? '';
  String get narration => outOfStock.outosNarration ?? '';
  String get createdDateTime => outOfStock.createdAt ?? '';
  String get updatedDateTime => outOfStock.updatedAt ?? '';
  int get isCompleteflag => outOfStock.outosIsCompleatedFlag;
  int get flag => outOfStock.outosFlag ?? 0;
  String get UUID => outOfStock.uuid;
}

/// OutOfStockSubWithDetails
/// Wrapper model that includes joined fields from database queries
/// Matching KMP's OutOFStockWithDetails
class OutOfStockSubWithDetails {
  final OutOfStockSub outOfStockSub;
  
  // Joined fields from query
  final String unitName;
  final String unitDispName;
  final String productName;
  final String salesman;
  final String storekeeper;
  final String supplierName;
  final String customerName;
  final int isPacked; // From PackedSubs check
  final int isViewed; // From OutOfStockProducts table

  const OutOfStockSubWithDetails({
    required this.outOfStockSub,
    this.unitName = '',
    this.unitDispName = '',
    this.productName = '',
    this.salesman = '',
    this.storekeeper = '',
    this.supplierName = '',
    this.customerName = '',
    this.isPacked = 0,
    this.isViewed = 0,
  });

  /// Convert from database map (join query result)
  factory OutOfStockSubWithDetails.fromMap(Map<String, dynamic> map) {
    return OutOfStockSubWithDetails(
      outOfStockSub: OutOfStockSub.fromMap(map),
      unitName: map['unitName'] as String? ?? '',
      unitDispName: map['unitDispName'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      salesman: map['salesman'] as String? ?? '',
      storekeeper: map['storekeeper'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      isPacked: map['isPacked'] as int? ?? 0,
      isViewed: map['isViewed'] as int? ?? 0,
    );
  }

  // Convenience getters matching KMP property names
  int get oospId => outOfStockSub.id;
  int get oospMasterId => outOfStockSub.outosSubOutosId;
  int get orderSubId => outOfStockSub.outosSubOrderSubId;
  int get custId => outOfStockSub.outosSubCustId;
  int get salesmanId => outOfStockSub.outosSubSalesManId;
  int get storekeeperId => outOfStockSub.outosSubStockKeeperId;
  String get dateAndTime => outOfStockSub.outosSubDateAndTime;
  int get supplierId => outOfStockSub.outosSubSuppId;
  int get productId => outOfStockSub.outosSubProdId;
  int get unitId => outOfStockSub.outosSubUnitId;
  int get carId => outOfStockSub.outosSubCarId;
  double get rate => outOfStockSub.outosSubRate;
  double get updateRate => outOfStockSub.outosSubUpdatedRate;
  double get qty => outOfStockSub.outosSubQty;
  double get availQty => outOfStockSub.outosSubAvailableQty;
  double get baseQty => outOfStockSub.outosSubUnitBaseQty;
  String get note => outOfStockSub.outosSubNote ?? '';
  String get narration => outOfStockSub.outosSubNarration ?? '';
  int get oospFlag => outOfStockSub.outosSubStatusFlag;
  String get createdDateTime => outOfStockSub.createdAt;
  String get updatedDateTime => outOfStockSub.updatedAt;
  int get isCheckedflag => outOfStockSub.outosSubIsCheckedFlag;
  int get flag => outOfStockSub.outosSubFlag ?? 0;
  String get UUID => outOfStockSub.uuid;
}

