// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductApi _$ProductApiFromJson(Map<String, dynamic> json) => ProductApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  product: Product.fromJson(json['product'] as Map<String, dynamic>),
  productUnit: ProductUnit.fromJson(
    json['productUnit'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$ProductApiToJson(ProductApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'product': instance.product.toJson(),
      'productUnit': instance.productUnit.toJson(),
    };

UpdateProductApi _$UpdateProductApiFromJson(Map<String, dynamic> json) =>
    UpdateProductApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UpdateProductApiToJson(UpdateProductApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'product': instance.product.toJson(),
    };

ProductListApi _$ProductListApiFromJson(Map<String, dynamic> json) =>
    ProductListApi(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updated_date: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$ProductListApiToJson(ProductListApi instance) =>
    <String, dynamic>{
      'data': instance.data?.map((e) => e.toJson()).toList(),
      'updated_date': instance.updated_date,
    };

ProductUnitListApi _$ProductUnitListApiFromJson(Map<String, dynamic> json) =>
    ProductUnitListApi(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => ProductUnit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updated_date: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$ProductUnitListApiToJson(ProductUnitListApi instance) =>
    <String, dynamic>{
      'data': instance.data?.map((e) => e.toJson()).toList(),
      'updated_date': instance.updated_date,
    };

ProductCarListApi _$ProductCarListApiFromJson(Map<String, dynamic> json) =>
    ProductCarListApi(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => ProductCar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updated_date: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$ProductCarListApiToJson(ProductCarListApi instance) =>
    <String, dynamic>{
      'data': instance.data?.map((e) => e.toJson()).toList(),
      'updated_date': instance.updated_date,
    };

ProductCarApi _$ProductCarApiFromJson(Map<String, dynamic> json) =>
    ProductCarApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => ProductCar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ProductCarApiToJson(ProductCarApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data.map((e) => e.toJson()).toList(),
    };

ProductUnitApi _$ProductUnitApiFromJson(Map<String, dynamic> json) =>
    ProductUnitApi(
      status: (json['status'] as num?)?.toInt() ?? 2,
      message: json['message'] as String? ?? '',
      data: ProductUnit.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProductUnitApiToJson(ProductUnitApi instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data.toJson(),
    };

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  productId: (json['id'] as num?)?.toInt() ?? -1,
  name: json['name'] as String? ?? '',
  code: json['code'] as String? ?? '',
  barcode: json['barcode'] as String? ?? '',
  sub_name: json['sub_name'] as String? ?? '',
  brand: json['brand'] as String? ?? '',
  sub_brand: json['sub_brand'] as String? ?? '',
  category_id: (json['category_id'] as num?)?.toInt() ?? -1,
  sub_category_id: (json['sub_category_id'] as num?)?.toInt() ?? -1,
  default_supp_id: (json['default_supp_id'] as num?)?.toInt() ?? -1,
  auto_sendto_supplier_flag:
      (json['auto_sendto_supplier_flag'] as num?)?.toInt() ?? -1,
  base_unit_id: (json['base_unit_id'] as num?)?.toInt() ?? -1,
  default_unit_id: (json['default_unit_id'] as num?)?.toInt() ?? -1,
  price: json['price'] == null ? 0.0 : _toDouble(json['price']),
  mrp: json['mrp'] == null ? 0.0 : _toDouble(json['mrp']),
  retail_price: json['retail_price'] == null
      ? 0.0
      : _toDouble(json['retail_price']),
  fitting_charge: json['fitting_charge'] == null
      ? 0.0
      : _toDouble(json['fitting_charge']),
  minimumPrice: _toNullableDouble(json['minimum_price']),
  note: json['note'] as String? ?? '',
  photo: json['photo'] as String? ?? '',
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.productId,
  'name': instance.name,
  'code': instance.code,
  'barcode': instance.barcode,
  'sub_name': instance.sub_name,
  'brand': instance.brand,
  'sub_brand': instance.sub_brand,
  'category_id': instance.category_id,
  'sub_category_id': instance.sub_category_id,
  'default_supp_id': instance.default_supp_id,
  'auto_sendto_supplier_flag': instance.auto_sendto_supplier_flag,
  'base_unit_id': instance.base_unit_id,
  'default_unit_id': instance.default_unit_id,
  'price': instance.price,
  'mrp': instance.mrp,
  'retail_price': instance.retail_price,
  'fitting_charge': instance.fitting_charge,
  'minimum_price': instance.minimumPrice,
  'note': instance.note,
  'photo': instance.photo,
};

ProductUnit _$ProductUnitFromJson(Map<String, dynamic> json) => ProductUnit(
  productUnitId: (json['id'] as num?)?.toInt() ?? -1,
  prd_id: (json['prd_id'] as num?)?.toInt() ?? -1,
  base_unit_id: (json['base_unit_id'] as num?)?.toInt() ?? -1,
  derived_unit_id: (json['derived_unit_id'] as num?)?.toInt() ?? -1,
);

Map<String, dynamic> _$ProductUnitToJson(ProductUnit instance) =>
    <String, dynamic>{
      'id': instance.productUnitId,
      'prd_id': instance.prd_id,
      'base_unit_id': instance.base_unit_id,
      'derived_unit_id': instance.derived_unit_id,
    };

ProductCar _$ProductCarFromJson(Map<String, dynamic> json) => ProductCar(
  id: (json['id'] as num?)?.toInt() ?? -1,
  product_id: (json['product_id'] as num?)?.toInt() ?? -1,
  car_brand_id: (json['car_brand_id'] as num?)?.toInt() ?? -1,
  car_name_id: (json['car_name_id'] as num?)?.toInt() ?? -1,
  car_model_id: (json['car_model_id'] as num?)?.toInt() ?? -1,
  car_version_id: (json['car_version_id'] as num?)?.toInt() ?? -1,
  flag: (json['flag'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductCarToJson(ProductCar instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.product_id,
      'car_brand_id': instance.car_brand_id,
      'car_name_id': instance.car_name_id,
      'car_model_id': instance.car_model_id,
      'car_version_id': instance.car_version_id,
      'flag': instance.flag,
    };
