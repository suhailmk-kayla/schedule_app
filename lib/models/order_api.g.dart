// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderApi _$OrderApiFromJson(Map<String, dynamic> json) => OrderApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  data: Order.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OrderApiToJson(OrderApi instance) => <String, dynamic>{
  'status': instance.status,
  'message': instance.message,
  'data': instance.data,
};

OrderListApi _$OrderListApiFromJson(Map<String, dynamic> json) => OrderListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => Order.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$OrderListApiToJson(OrderListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

OrderSubListApi _$OrderSubListApiFromJson(Map<String, dynamic> json) =>
    OrderSubListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => OrderSub.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$OrderSubListApiToJson(OrderSubListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

OrderSubSuggestionsListApi _$OrderSubSuggestionsListApiFromJson(
  Map<String, dynamic> json,
) => OrderSubSuggestionsListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => OrderSubSuggestion.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$OrderSubSuggestionsListApiToJson(
  OrderSubSuggestionsListApi instance,
) => <String, dynamic>{
  'data': instance.data,
  'updated_date': instance.updatedDate,
};

OrderSubApi _$OrderSubApiFromJson(Map<String, dynamic> json) => OrderSubApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  data: OrderSub.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OrderSubApiToJson(OrderSubApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  orderId: (json['id'] as num?)?.toInt() ?? -1,
  uuid: json['uuid'] as String? ?? '',
  orderInvNo: json['order_inv_no'] == null
      ? 0
      : _intFromJsonZero(json['order_inv_no']),
  orderCustId: json['order_cust_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_cust_id']),
  orderCustName: json['order_cust_name'] as String? ?? '',
  orderSalesmanId: json['order_salesman_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_salesman_id']),
  orderStockKeeperId: json['order_stock_keeper_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_stock_keeper_id']),
  orderBillerId: json['order_biller_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_biller_id']),
  orderCheckerId: json['order_checker_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_checker_id']),
  orderDateTime: json['order_date_time'] as String? ?? '',
  orderTotal: json['order_total'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_total']),
  orderFreightCharge: json['order_freight_charge'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_freight_charge']),
  orderNote: json['order_note'] as String?,
  orderApproveFlag: json['order_approve_flag'] == null
      ? -1
      : _intFromJsonNegOne(json['order_approve_flag']),
  orderFlag: json['order_flag'] == null
      ? 1
      : _intFromJsonOne(json['order_flag']),
  createdAt: json['created_at'] as String? ?? '',
  updatedAt: json['updated_at'] as String? ?? '',
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => OrderSub.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.orderId,
  'uuid': instance.uuid,
  'order_inv_no': instance.orderInvNo,
  'order_cust_id': instance.orderCustId,
  'order_cust_name': instance.orderCustName,
  'order_salesman_id': instance.orderSalesmanId,
  'order_stock_keeper_id': instance.orderStockKeeperId,
  'order_biller_id': instance.orderBillerId,
  'order_checker_id': instance.orderCheckerId,
  'order_date_time': instance.orderDateTime,
  'order_total': instance.orderTotal,
  'order_freight_charge': instance.orderFreightCharge,
  'order_note': instance.orderNote,
  'order_approve_flag': instance.orderApproveFlag,
  'order_flag': instance.orderFlag,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'items': instance.items,
};

OrderSub _$OrderSubFromJson(Map<String, dynamic> json) => OrderSub(
  orderSubId: (json['id'] as num?)?.toInt() ?? -1,
  orderSubOrdrInvId: json['order_sub_ordr_inv_id'] == null
      ? 0
      : _intFromJsonZero(json['order_sub_ordr_inv_id']),
  orderSubOrdrId: json['order_sub_ordr_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_ordr_id']),
  orderSubCustId: json['order_sub_cust_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_cust_id']),
  orderSubSalesmanId: json['order_sub_salesman_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_salesman_id']),
  orderSubStockKeeperId: json['order_sub_stock_keeper_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_stock_keeper_id']),
  orderSubDateTime: json['order_sub_date_time'] as String? ?? '',
  orderSubPrdId: json['order_sub_prd_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_prd_id']),
  orderSubUnitId: json['order_sub_unit_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_unit_id']),
  orderSubCarId: json['order_sub_car_id'] == null
      ? -1
      : _intFromJsonNegOne(json['order_sub_car_id']),
  orderSubRate: json['order_sub_rate'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_sub_rate']),
  orderSubUpdateRate: json['order_sub_update_rate'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_sub_update_rate']),
  orderSubQty: json['order_sub_qty'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_sub_qty']),
  orderSubAvailableQty: json['order_sub_available_qty'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_sub_available_qty']),
  orderSubUnitBaseQty: json['order_sub_unit_base_qty'] == null
      ? 0.0
      : _doubleFromJsonZero(json['order_sub_unit_base_qty']),
  orderSubIsCheckedFlag: json['order_sub_is_checked_flag'] == null
      ? 0
      : _intFromJsonZero(json['order_sub_is_checked_flag']),
  orderSubOrdrFlag: json['order_sub_ordr_flag'] == null
      ? 0
      : _intFromJsonZero(json['order_sub_ordr_flag']),
  orderSubNote: json['order_sub_note'] as String?,
  orderSubNarration: json['order_sub_narration'] as String?,
  orderSubFlag: json['order_sub_flag'] == null
      ? 1
      : _intFromJsonOne(json['order_sub_flag']),
  createdAt: json['created_at'] as String? ?? '',
  updatedAt: json['updated_at'] as String? ?? '',
  suggestions: (json['suggestions'] as List<dynamic>?)
      ?.map((e) => OrderSubSuggestion.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OrderSubToJson(OrderSub instance) => <String, dynamic>{
  'id': instance.orderSubId,
  'order_sub_ordr_inv_id': instance.orderSubOrdrInvId,
  'order_sub_ordr_id': instance.orderSubOrdrId,
  'order_sub_cust_id': instance.orderSubCustId,
  'order_sub_salesman_id': instance.orderSubSalesmanId,
  'order_sub_stock_keeper_id': instance.orderSubStockKeeperId,
  'order_sub_date_time': instance.orderSubDateTime,
  'order_sub_prd_id': instance.orderSubPrdId,
  'order_sub_unit_id': instance.orderSubUnitId,
  'order_sub_car_id': instance.orderSubCarId,
  'order_sub_rate': instance.orderSubRate,
  'order_sub_update_rate': instance.orderSubUpdateRate,
  'order_sub_qty': instance.orderSubQty,
  'order_sub_available_qty': instance.orderSubAvailableQty,
  'order_sub_unit_base_qty': instance.orderSubUnitBaseQty,
  'order_sub_is_checked_flag': instance.orderSubIsCheckedFlag,
  'order_sub_ordr_flag': instance.orderSubOrdrFlag,
  'order_sub_note': instance.orderSubNote,
  'order_sub_narration': instance.orderSubNarration,
  'order_sub_flag': instance.orderSubFlag,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'suggestions': instance.suggestions,
};

OrderSubSuggestion _$OrderSubSuggestionFromJson(Map<String, dynamic> json) =>
    OrderSubSuggestion(
      id: (json['id'] as num?)?.toInt() ?? -1,
      orderSubId: (json['order_sub_id'] as num?)?.toInt() ?? -1,
      prodId: (json['prod_id'] as num?)?.toInt() ?? -1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      flag: (json['flag'] as num?)?.toInt(),
      productName: json['productName'] as String?,
    );

Map<String, dynamic> _$OrderSubSuggestionToJson(OrderSubSuggestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_sub_id': instance.orderSubId,
      'prod_id': instance.prodId,
      'price': instance.price,
      'note': instance.note,
      'flag': instance.flag,
      'productName': instance.productName,
    };
