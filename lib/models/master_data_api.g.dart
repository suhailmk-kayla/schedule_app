// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master_data_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryApi _$CategoryApiFromJson(Map<String, dynamic> json) => CategoryApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  data: Category.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CategoryApiToJson(CategoryApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

CategoryListApi _$CategoryListApiFromJson(Map<String, dynamic> json) =>
    CategoryListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CategoryListApiToJson(CategoryListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  remark: json['remark'] as String? ?? '',
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'remark': instance.remark,
};

SubCategoryApi _$SubCategoryApiFromJson(Map<String, dynamic> json) =>
    SubCategoryApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: SubCategory.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SubCategoryApiToJson(SubCategoryApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

SubCategoryListApi _$SubCategoryListApiFromJson(Map<String, dynamic> json) =>
    SubCategoryListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => SubCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$SubCategoryListApiToJson(SubCategoryListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

SubCategory _$SubCategoryFromJson(Map<String, dynamic> json) => SubCategory(
  id: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  catId: (json['cat_id'] as num?)?.toInt() ?? -1,
  remark: json['remark'] as String? ?? '',
);

Map<String, dynamic> _$SubCategoryToJson(SubCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cat_id': instance.catId,
      'remark': instance.remark,
    };

UnitApi _$UnitApiFromJson(Map<String, dynamic> json) => UnitApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  data: Units.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UnitApiToJson(UnitApi instance) => <String, dynamic>{
  'status': instance.status,
  'message': instance.message,
  'data': instance.data,
};

UnitListApi _$UnitListApiFromJson(Map<String, dynamic> json) => UnitListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => Units.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$UnitListApiToJson(UnitListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

Units _$UnitsFromJson(Map<String, dynamic> json) => Units(
  id: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  displayName: json['display_name'] as String? ?? '',
  type: (json['type'] as num?)?.toInt() ?? 0,
  baseId: (json['base_id'] as num?)?.toInt() ?? -1,
  baseQty: (json['base_qty'] as num?)?.toDouble() ?? 0.0,
  comment: json['comment'] as String? ?? '',
);

Map<String, dynamic> _$UnitsToJson(Units instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
  'display_name': instance.displayName,
  'type': instance.type,
  'base_id': instance.baseId,
  'base_qty': instance.baseQty,
  'comment': instance.comment,
};

CustomerSuccessApi _$CustomerSuccessApiFromJson(Map<String, dynamic> json) =>
    CustomerSuccessApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: Customer.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CustomerSuccessApiToJson(CustomerSuccessApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

CustomerListApi _$CustomerListApiFromJson(Map<String, dynamic> json) =>
    CustomerListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CustomerListApiToJson(CustomerListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  customerId: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  phoneNo: json['phone_no'] as String? ?? '',
  routId: (json['rout_id'] as num?)?.toInt() ?? -1,
  salesManId: (json['sales_man_id'] as num?)?.toInt() ?? -1,
  rating: json['rating'] == null ? -1 : _toIntFlexible(json['rating']),
  address: json['address'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.customerId,
  'name': instance.name,
  'code': instance.code,
  'phone_no': instance.phoneNo,
  'rout_id': instance.routId,
  'sales_man_id': instance.salesManId,
  'rating': instance.rating,
  'address': instance.address,
  'flag': instance.flag,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

UserSuccessApi _$UserSuccessApiFromJson(Map<String, dynamic> json) =>
    UserSuccessApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      userData: json['userData'] == null
          ? null
          : UserData.fromJson(json['userData'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserSuccessApiToJson(UserSuccessApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'user': instance.user,
      'userData': instance.userData,
    };

UserListApi _$UserListApiFromJson(Map<String, dynamic> json) => UserListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => UserDown.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$UserListApiToJson(UserListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
  userId: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  phoneNo: json['phone_no'] as String? ?? '',
  catId: (json['cat_id'] as num?)?.toInt() ?? -1,
  address: json['address'] as String? ?? '',
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.userId,
  'name': instance.name,
  'code': instance.code,
  'phone_no': instance.phoneNo,
  'cat_id': instance.catId,
  'address': instance.address,
};

UserDown _$UserDownFromJson(Map<String, dynamic> json) => UserDown(
  userId: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  phoneNo: json['phone_no'] as String? ?? '',
  userCatId: (json['user_cat_id'] as num?)?.toInt() ?? -1,
  address: json['address'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$UserDownToJson(UserDown instance) => <String, dynamic>{
  'id': instance.userId,
  'name': instance.name,
  'code': instance.code,
  'phone_no': instance.phoneNo,
  'user_cat_id': instance.userCatId,
  'address': instance.address,
  'flag': instance.flag,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

UserDataListApi _$UserDataListApiFromJson(Map<String, dynamic> json) =>
    UserDataListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => UserData.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$UserDataListApiToJson(UserDataListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

UserData _$UserDataFromJson(Map<String, dynamic> json) => UserData(
  id: (json['id'] as num?)?.toInt() ?? -1,
  userId: (json['user_id'] as num?)?.toInt(),
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  phoneNo: json['phone_no'] as String? ?? '',
  address: json['address'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$UserDataToJson(UserData instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'name': instance.name,
  'code': instance.code,
  'phone_no': instance.phoneNo,
  'address': instance.address,
  'flag': instance.flag,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

AddRouteApi _$AddRouteApiFromJson(Map<String, dynamic> json) => AddRouteApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  data: Route.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AddRouteApiToJson(AddRouteApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

RouteListApi _$RouteListApiFromJson(Map<String, dynamic> json) => RouteListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => Route.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$RouteListApiToJson(RouteListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

Route _$RouteFromJson(Map<String, dynamic> json) => Route(
  routeId: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  salesmanId: (json['salesman_id'] as num?)?.toInt() ?? -1,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$RouteToJson(Route instance) => <String, dynamic>{
  'id': instance.routeId,
  'name': instance.name,
  'code': instance.code,
  'salesman_id': instance.salesmanId,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

OutOfStockApi _$OutOfStockApiFromJson(Map<String, dynamic> json) =>
    OutOfStockApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: OutOfStock.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OutOfStockApiToJson(OutOfStockApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

OutOfStockAllApi _$OutOfStockAllApiFromJson(Map<String, dynamic> json) =>
    OutOfStockAllApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: (json['data'] as List<dynamic>)
          .map((e) => OutOfStock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OutOfStockAllApiToJson(OutOfStockAllApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

OutOfStockListApi _$OutOfStockListApiFromJson(Map<String, dynamic> json) =>
    OutOfStockListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => OutOfStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$OutOfStockListApiToJson(OutOfStockListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

OutOfStockSubListApi _$OutOfStockSubListApiFromJson(
  Map<String, dynamic> json,
) => OutOfStockSubListApi(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => OutOfStockSub.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedDate: json['updated_date'] as String? ?? '',
);

Map<String, dynamic> _$OutOfStockSubListApiToJson(
  OutOfStockSubListApi instance,
) => <String, dynamic>{
  'data': instance.data,
  'updated_date': instance.updatedDate,
};

OutOfStock _$OutOfStockFromJson(Map<String, dynamic> json) => OutOfStock(
  id: (json['id'] as num?)?.toInt() ?? -1,
  outosOrderSubId: (json['outos_order_sub_id'] as num?)?.toInt() ?? -1,
  outosCustId: (json['outos_cust_id'] as num?)?.toInt() ?? -1,
  outosSalesManId: (json['outos_sales_man_id'] as num?)?.toInt() ?? -1,
  outosStockKeeperId: (json['outos_stock_keeper_id'] as num?)?.toInt() ?? -1,
  outosDateAndTime: json['outos_date_and_time'] as String? ?? '',
  outosProdId: (json['outos_prod_id'] as num?)?.toInt() ?? -1,
  outosUnitId: (json['outos_unit_id'] as num?)?.toInt() ?? -1,
  outosCarId: (json['outos_car_id'] as num?)?.toInt() ?? -1,
  outosQty: (json['outos_qty'] as num?)?.toDouble() ?? 0.0,
  outosAvailableQty: (json['outos_available_qty'] as num?)?.toDouble() ?? 0.0,
  outosUnitBaseQty: (json['outos_unit_base_qty'] as num?)?.toDouble() ?? 0.0,
  outosNote: json['outos_note'] as String?,
  outosNarration: json['outos_narration'] as String?,
  outosIsCompleatedFlag:
      (json['outos_is_compleated_flag'] as num?)?.toInt() ?? -1,
  outosFlag: (json['outos_flag'] as num?)?.toInt(),
  uuid: json['uuid'] as String? ?? '',
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => OutOfStockSub.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OutOfStockToJson(OutOfStock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'outos_order_sub_id': instance.outosOrderSubId,
      'outos_cust_id': instance.outosCustId,
      'outos_sales_man_id': instance.outosSalesManId,
      'outos_stock_keeper_id': instance.outosStockKeeperId,
      'outos_date_and_time': instance.outosDateAndTime,
      'outos_prod_id': instance.outosProdId,
      'outos_unit_id': instance.outosUnitId,
      'outos_car_id': instance.outosCarId,
      'outos_qty': instance.outosQty,
      'outos_available_qty': instance.outosAvailableQty,
      'outos_unit_base_qty': instance.outosUnitBaseQty,
      'outos_note': instance.outosNote,
      'outos_narration': instance.outosNarration,
      'outos_is_compleated_flag': instance.outosIsCompleatedFlag,
      'outos_flag': instance.outosFlag,
      'uuid': instance.uuid,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'items': instance.items,
    };

OutOfStockSub _$OutOfStockSubFromJson(
  Map<String, dynamic> json,
) => OutOfStockSub(
  id: (json['id'] as num?)?.toInt() ?? -1,
  outosSubOutosId: (json['outos_sub_outos_id'] as num?)?.toInt() ?? -1,
  outosSubOrderSubId: (json['outos_sub_order_sub_id'] as num?)?.toInt() ?? -1,
  outosSubCustId: (json['outos_sub_cust_id'] as num?)?.toInt() ?? -1,
  outosSubSalesManId: (json['outos_sub_sales_man_id'] as num?)?.toInt() ?? -1,
  outosSubStockKeeperId:
      (json['outos_sub_stock_keeper_id'] as num?)?.toInt() ?? -1,
  outosSubDateAndTime: json['outos_sub_date_and_time'] as String? ?? '',
  outosSubSuppId: (json['outos_sub_supp_id'] as num?)?.toInt() ?? -1,
  outosSubProdId: (json['outos_sub_prod_id'] as num?)?.toInt() ?? -1,
  outosSubUnitId: (json['outos_sub_unit_id'] as num?)?.toInt() ?? -1,
  outosSubCarId: (json['outos_sub_car_id'] as num?)?.toInt() ?? -1,
  outosSubRate: (json['outos_sub_rate'] as num?)?.toDouble() ?? 0.0,
  outosSubUpdatedRate:
      (json['outos_sub_updated_rate'] as num?)?.toDouble() ?? 0.0,
  outosSubQty: (json['outos_sub_qty'] as num?)?.toDouble() ?? 0.0,
  outosSubAvailableQty:
      (json['outos_sub_available_qty'] as num?)?.toDouble() ?? 0.0,
  outosSubUnitBaseQty:
      (json['outos_sub_unit_base_qty'] as num?)?.toDouble() ?? 0.0,
  outosSubStatusFlag: (json['outos_sub_status_flag'] as num?)?.toInt() ?? 1,
  outosSubIsCheckedFlag:
      (json['outos_sub_is_checked_flag'] as num?)?.toInt() ?? 0,
  outosSubNote: json['outos_sub_note'] as String?,
  outosSubNarration: json['outos_sub_narration'] as String?,
  outosSubFlag: (json['outos_sub_flag'] as num?)?.toInt(),
  uuid: json['uuid'] as String? ?? '',
  createdAt: json['created_at'] as String? ?? '',
  updatedAt: json['updated_at'] as String? ?? '',
);

Map<String, dynamic> _$OutOfStockSubToJson(OutOfStockSub instance) =>
    <String, dynamic>{
      'id': instance.id,
      'outos_sub_outos_id': instance.outosSubOutosId,
      'outos_sub_order_sub_id': instance.outosSubOrderSubId,
      'outos_sub_cust_id': instance.outosSubCustId,
      'outos_sub_sales_man_id': instance.outosSubSalesManId,
      'outos_sub_stock_keeper_id': instance.outosSubStockKeeperId,
      'outos_sub_date_and_time': instance.outosSubDateAndTime,
      'outos_sub_supp_id': instance.outosSubSuppId,
      'outos_sub_prod_id': instance.outosSubProdId,
      'outos_sub_unit_id': instance.outosSubUnitId,
      'outos_sub_car_id': instance.outosSubCarId,
      'outos_sub_rate': instance.outosSubRate,
      'outos_sub_updated_rate': instance.outosSubUpdatedRate,
      'outos_sub_qty': instance.outosSubQty,
      'outos_sub_available_qty': instance.outosSubAvailableQty,
      'outos_sub_unit_base_qty': instance.outosSubUnitBaseQty,
      'outos_sub_status_flag': instance.outosSubStatusFlag,
      'outos_sub_is_checked_flag': instance.outosSubIsCheckedFlag,
      'outos_sub_note': instance.outosSubNote,
      'outos_sub_narration': instance.outosSubNarration,
      'outos_sub_flag': instance.outosSubFlag,
      'uuid': instance.uuid,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

OutOfStockSubApi _$OutOfStockSubApiFromJson(Map<String, dynamic> json) =>
    OutOfStockSubApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: OutOfStockSub.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OutOfStockSubApiToJson(OutOfStockSubApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };
