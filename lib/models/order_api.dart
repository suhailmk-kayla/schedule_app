import 'package:json_annotation/json_annotation.dart';

part 'order_api.g.dart';

/// Order API Response
/// Converted from KMP's OrderApi.kt
@JsonSerializable()
class OrderApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final Order data;

  const OrderApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory OrderApi.fromJson(Map<String, dynamic> json) =>
      _$OrderApiFromJson(json);

  Map<String, dynamic> toJson() => _$OrderApiToJson(this);
}

/// Order List API Response
/// Converted from KMP's OrderListApi
@JsonSerializable()
class OrderListApi {
  final List<Order>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const OrderListApi({
    this.data,
    this.updatedDate = '',
  });

  factory OrderListApi.fromJson(Map<String, dynamic> json) =>
      _$OrderListApiFromJson(json);

  Map<String, dynamic> toJson() => _$OrderListApiToJson(this);
}

/// Order Sub List API Response
/// Converted from KMP's OrderSubListApi
@JsonSerializable()
class OrderSubListApi {
  final List<OrderSub>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const OrderSubListApi({
    this.data,
    this.updatedDate = '',
  });

  factory OrderSubListApi.fromJson(Map<String, dynamic> json) =>
      _$OrderSubListApiFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSubListApiToJson(this);
}

/// Order Sub Suggestions List API Response
/// Converted from KMP's OrderSubSuggestionsListApi
@JsonSerializable()
class OrderSubSuggestionsListApi {
  final List<OrderSubSuggestion>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const OrderSubSuggestionsListApi({
    this.data,
    this.updatedDate = '',
  });

  factory OrderSubSuggestionsListApi.fromJson(Map<String, dynamic> json) =>
      _$OrderSubSuggestionsListApiFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSubSuggestionsListApiToJson(this);
}

/// Order Sub API Response (single item wrapper)
/// Converted from KMP's OrderSubApi.kt
@JsonSerializable()
class OrderSubApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  final OrderSub data;

  const OrderSubApi({
    this.status = 2,
    this.message = '',
    required this.data,
  });

  factory OrderSubApi.fromJson(Map<String, dynamic> json) =>
      _$OrderSubApiFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSubApiToJson(this);
}

/// Order Model
/// Converted from KMP's Order class
@JsonSerializable()

/// Order Model
class Order {
  @JsonKey(defaultValue: -1, includeFromJson: false, includeToJson: false)
  final int id; // Local DB primary key (AUTOINCREMENT)

  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to orderId
  final int orderId; // Server ID

  @JsonKey(defaultValue: '')
  final String uuid;

  @JsonKey(
    name: 'order_inv_no',
    defaultValue: 0,
    fromJson: _intFromJsonZero,
  )
  final int orderInvNo;

  @JsonKey(
    name: 'order_cust_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderCustId;

  @JsonKey(name: 'order_cust_name', defaultValue: '')
  final String orderCustName;

  @JsonKey(
    name: 'order_salesman_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSalesmanId;

  @JsonKey(
    name: 'order_stock_keeper_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderStockKeeperId;

  @JsonKey(
    name: 'order_biller_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderBillerId;

  @JsonKey(
    name: 'order_checker_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderCheckerId;

  @JsonKey(name: 'order_date_time', defaultValue: '')
  final String orderDateTime;

  @JsonKey(
    name: 'order_total',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderTotal;

  @JsonKey(
    name: 'order_freight_charge',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderFreightCharge;

  @JsonKey(name: 'order_note')
  final String? orderNote;

  @JsonKey(
    name: 'order_approve_flag',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderApproveFlag;

  @JsonKey(
    name: 'order_flag',
    defaultValue: 1,
    fromJson: _intFromJsonOne,
  )
  final int orderFlag;

  @JsonKey(name: 'created_at', defaultValue: '')
  final String createdAt;

  @JsonKey(name: 'updated_at', defaultValue: '')
  final String updatedAt;

  final List<OrderSub>? items;

  const Order({
    this.id = -1,
    this.orderId = -1,
    this.uuid = '',
    this.orderInvNo = 0,
    this.orderCustId = -1,
    this.orderCustName = '',
    this.orderSalesmanId = -1,
    this.orderStockKeeperId = -1,
    this.orderBillerId = -1,
    this.orderCheckerId = -1,
    this.orderDateTime = '',
    this.orderTotal = 0.0,
    this.orderFreightCharge = 0.0,
    this.orderNote,
    this.orderApproveFlag = -1,
    this.orderFlag = 1,
    this.createdAt = '',
    this.updatedAt = '',
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);

  /// Convert from database map (camelCase column names)
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int? ?? -1, // Local DB PK
      orderId: map['orderId'] as int? ?? -1, // Server ID
      uuid: map['UUID'] as String? ?? '',
      orderInvNo: int.tryParse(map['invoiceNo'] as String? ?? '0') ?? 0,
      orderCustId: map['customerId'] as int? ?? -1,
      orderCustName: map['customerName'] as String? ?? '',
      orderSalesmanId: map['salesmanId'] as int? ?? -1,
      orderStockKeeperId: map['storeKeeperId'] as int? ?? -1,
      orderBillerId: map['billerId'] as int? ?? -1,
      orderCheckerId: map['checkerId'] as int? ?? -1,
      orderDateTime: map['dateAndTime'] as String? ?? '',
      orderTotal: (map['total'] as num?)?.toDouble() ?? 0.0,
      orderFreightCharge: (map['freightCharge'] as num?)?.toDouble() ?? 0.0,
      orderNote: map['note'] as String?,
      orderApproveFlag: map['approveFlag'] as int? ?? -1,
      orderFlag: map['flag'] as int? ?? 1,
      createdAt: map['createdDateTime'] as String? ?? '',
      updatedAt: map['updatedDateTime'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  /// Note: 'id' column is omitted - SQLite will auto-increment
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'invoiceNo': orderInvNo.toString(),
      'UUID': uuid,
      'customerId': orderCustId,
      'customerName': orderCustName,
      'salesmanId': orderSalesmanId,
      'storeKeeperId': orderStockKeeperId,
      'billerId': orderBillerId,
      'checkerId': orderCheckerId,
      'dateAndTime': orderDateTime,
      'note': orderNote ?? '',
      'total': orderTotal,
      'freightCharge': orderFreightCharge,
      'approveFlag': orderApproveFlag,
      'createdDateTime': createdAt,
      'updatedDateTime': updatedAt,
      'flag': orderFlag,
      'isProcessFinish': 1,
    };
  }
}

/// Order Sub Model
/// Converted from KMP's OrderSub class
@JsonSerializable()
class OrderSub {
  @JsonKey(defaultValue: -1, includeFromJson: false, includeToJson: false)
  final int id; // Local DB primary key (AUTOINCREMENT)

  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to orderSubId
  final int orderSubId; // Server ID

  @JsonKey(
    name: 'order_sub_ordr_inv_id',
    defaultValue: 0,
    fromJson: _intFromJsonZero,
  )
  final int orderSubOrdrInvId;

  @JsonKey(
    name: 'order_sub_ordr_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubOrdrId;

  @JsonKey(
    name: 'order_sub_cust_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubCustId;

  @JsonKey(
    name: 'order_sub_salesman_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubSalesmanId;

  @JsonKey(
    name: 'order_sub_stock_keeper_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubStockKeeperId;

  @JsonKey(name: 'order_sub_date_time', defaultValue: '')
  final String orderSubDateTime;

  @JsonKey(
    name: 'order_sub_prd_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubPrdId;

  @JsonKey(
    name: 'order_sub_unit_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubUnitId;

  @JsonKey(
    name: 'order_sub_car_id',
    defaultValue: -1,
    fromJson: _intFromJsonNegOne,
  )
  final int orderSubCarId;

  @JsonKey(
    name: 'order_sub_rate',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderSubRate;

  @JsonKey(
    name: 'order_sub_update_rate',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderSubUpdateRate;

  @JsonKey(
    name: 'order_sub_qty',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderSubQty;

  @JsonKey(
    name: 'order_sub_available_qty',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderSubAvailableQty;

  @JsonKey(
    name: 'order_sub_unit_base_qty',
    defaultValue: 0.0,
    fromJson: _doubleFromJsonZero,
  )
  final double orderSubUnitBaseQty;

  @JsonKey(
    name: 'order_sub_is_checked_flag',
    defaultValue: 0,
    fromJson: _intFromJsonZero,
  )
  final int orderSubIsCheckedFlag;

  @JsonKey(
    name: 'order_sub_ordr_flag',
    defaultValue: 0,
    fromJson: _intFromJsonZero,
  )
  final int orderSubOrdrFlag;

  @JsonKey(name: 'order_sub_note')
  final String? orderSubNote;

  @JsonKey(name: 'order_sub_narration')
  final String? orderSubNarration;

  @JsonKey(
    name: 'order_sub_flag',
    defaultValue: 1,
    fromJson: _intFromJsonOne,
  )
  final int orderSubFlag;

  @JsonKey(name: 'created_at', defaultValue: '')
  final String createdAt;

  @JsonKey(name: 'updated_at', defaultValue: '')
  final String updatedAt;

  @JsonKey(name: 'order_sub_checker_image')
  final String? checkerImage;

  final List<OrderSubSuggestion>? suggestions;

  const OrderSub({
    this.id = -1,
    this.orderSubId = -1,
    this.orderSubOrdrInvId = 0,
    this.orderSubOrdrId = -1,
    this.orderSubCustId = -1,
    this.orderSubSalesmanId = -1,
    this.orderSubStockKeeperId = -1,
    this.orderSubDateTime = '',
    this.orderSubPrdId = -1,
    this.orderSubUnitId = -1,
    this.orderSubCarId = -1,
    this.orderSubRate = 0.0,
    this.orderSubUpdateRate = 0.0,
    this.orderSubQty = 0.0,
    this.orderSubAvailableQty = 0.0,
    this.orderSubUnitBaseQty = 0.0,
    this.orderSubIsCheckedFlag = 0,
    this.orderSubOrdrFlag = 0,
      this.orderSubNote,
      this.orderSubNarration,
      this.orderSubFlag = 1,
      this.createdAt = '',
      this.updatedAt = '',
      this.checkerImage,
      this.suggestions,
    });

  factory OrderSub.fromJson(Map<String, dynamic> json) =>
      _$OrderSubFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSubToJson(this);

  /// Convert from database map (camelCase column names)
  factory OrderSub.fromMap(Map<String, dynamic> map) {
    return OrderSub(
      id: map['id'] as int? ?? -1, // Local DB PK
      orderSubId: map['orderSubId'] as int? ?? -1, // Server ID
      orderSubOrdrInvId: int.tryParse(map['invoiceNo'] as String? ?? '0') ?? 0,
      orderSubOrdrId: map['orderId'] as int? ?? -1,
      orderSubCustId: map['customerId'] as int? ?? -1,
      orderSubSalesmanId: map['salesmanId'] as int? ?? -1,
      orderSubStockKeeperId: map['storeKeeperId'] as int? ?? -1,
      orderSubDateTime: map['dateAndTime'] as String? ?? '',
      orderSubPrdId: map['productId'] as int? ?? -1,
      orderSubUnitId: map['unitId'] as int? ?? -1,
      orderSubCarId: map['carId'] as int? ?? -1,
      orderSubRate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      orderSubUpdateRate: (map['updateRate'] as num?)?.toDouble() ?? 0.0,
      orderSubQty: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      orderSubAvailableQty: (map['availQty'] as num?)?.toDouble() ?? 0.0,
      orderSubUnitBaseQty: (map['unitBaseQty'] as num?)?.toDouble() ?? 0.0,
      orderSubIsCheckedFlag: map['isCheckedflag'] as int? ?? 0,
      orderSubOrdrFlag: map['orderFlag'] as int? ?? 0,
      orderSubNote: map['note'] as String?,
      orderSubNarration: map['narration'] as String?,
      orderSubFlag: map['flag'] as int? ?? 1,
      createdAt: map['createdDateTime'] as String? ?? '',
      updatedAt: map['updatedDateTime'] as String? ?? '',
      checkerImage: map['checkerImage'] as String?,
    );
  }

  /// Convert to database map (camelCase column names)
  /// Note: 'id' column is omitted - SQLite will auto-increment
  Map<String, dynamic> toMap() {
    return {
      'orderSubId': orderSubId,
      'orderId': orderSubOrdrId,
      'invoiceNo': orderSubOrdrInvId.toString(),
      'UUID': '',
      'customerId': orderSubCustId,
      'salesmanId': orderSubSalesmanId,
      'storeKeeperId': orderSubStockKeeperId,
      'dateAndTime': orderSubDateTime,
      'productId': orderSubPrdId,
      'unitId': orderSubUnitId,
      'carId': orderSubCarId,
      'rate': orderSubRate,
      'updateRate': orderSubUpdateRate,
      'quantity': orderSubQty,
      'availQty': orderSubAvailableQty,
      'unitBaseQty': orderSubUnitBaseQty,
      'note': orderSubNote ?? '',
      'narration': orderSubNarration ?? '',
      'orderFlag': orderSubOrdrFlag,
      'createdDateTime': createdAt,
      'updatedDateTime': updatedAt,
      'isCheckedflag': orderSubIsCheckedFlag,
      'flag': orderSubFlag,
      'checkerImage': checkerImage,
    };
  }
}

/// Order Sub Suggestion Model
/// Converted from KMP's OrderSubSuggestion class
@JsonSerializable()
class OrderSubSuggestion {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(name: 'order_sub_id', defaultValue: -1)
  final int orderSubId;

  @JsonKey(name: 'prod_id', defaultValue: -1)
  final int prodId;

  @JsonKey(defaultValue: 0.0)
  final double price;

  final String? note;

  final int? flag;

  /// Product name (from JOIN query, not stored in DB)
  final String? productName;

  const OrderSubSuggestion({
    this.id = -1,
    this.orderSubId = -1,
    this.prodId = -1,
    this.price = 0.0,
    this.note,
    this.flag,
    this.productName,
  });

  factory OrderSubSuggestion.fromJson(Map<String, dynamic> json) =>
      _$OrderSubSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSubSuggestionToJson(this);

  /// Convert from database map (camelCase column names)
  factory OrderSubSuggestion.fromMap(Map<String, dynamic> map) {
    return OrderSubSuggestion(
      id: map['sugId'] as int? ?? -1,
      orderSubId: map['orderSubId'] as int? ?? -1,
      prodId: map['productId'] as int? ?? -1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
      flag: map['flag'] as int?,
      productName: map['productName'] as String?,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'sugId': id,
      'orderSubId': orderSubId,
      'productId': prodId,
      'price': price,
      'note': note ?? '',
      'flag': flag ?? 1,
    };
  }
}

// ============================================================================
// JSON Helper Functions
// ============================================================================

int _parseInt(dynamic value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String && value.trim().isNotEmpty) {
    return int.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

double _parseDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

int _intFromJsonNegOne(dynamic value) => _parseInt(value, -1);
int _intFromJsonZero(dynamic value) => _parseInt(value, 0);
int _intFromJsonOne(dynamic value) => _parseInt(value, 1);
double _doubleFromJsonZero(dynamic value) => _parseDouble(value, 0.0);

