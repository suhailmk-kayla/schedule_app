import 'package:json_annotation/json_annotation.dart';

part 'product_api.g.dart';

@JsonSerializable(explicitToJson: true)
class ProductApi {
  @JsonKey(defaultValue: 2)
  final int status;
  @JsonKey(defaultValue: '')
  final String message;
  final Product product;
  @JsonKey(name: 'productUnit')
  final ProductUnit productUnit;

  const ProductApi({
    required this.status,
    required this.message,
    required this.product,
    required this.productUnit,
  });

  factory ProductApi.fromJson(Map<String, dynamic> json) =>
      _$ProductApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UpdateProductApi {
  @JsonKey(defaultValue: 2)
  final int status;
  @JsonKey(defaultValue: '')
  final String message;
  final Product product;

  const UpdateProductApi({
    required this.status,
    required this.message,
    required this.product,
  });

  factory UpdateProductApi.fromJson(Map<String, dynamic> json) =>
      _$UpdateProductApiFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateProductApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProductListApi {
  @JsonKey(defaultValue: [])
  final List<Product>? data;
  @JsonKey(defaultValue: '')
  final String updated_date;

  const ProductListApi({
    required this.data,
    required this.updated_date,
  });

  factory ProductListApi.fromJson(Map<String, dynamic> json) =>
      _$ProductListApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductListApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProductUnitListApi {
  @JsonKey(defaultValue: [])
  final List<ProductUnit>? data;
  @JsonKey(defaultValue: '')
  final String updated_date;

  const ProductUnitListApi({
    required this.data,
    required this.updated_date,
  });

  factory ProductUnitListApi.fromJson(Map<String, dynamic> json) =>
      _$ProductUnitListApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductUnitListApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProductCarListApi {
  @JsonKey(defaultValue: [])
  final List<ProductCar>? data;
  @JsonKey(defaultValue: '')
  final String updated_date;

  const ProductCarListApi({
    required this.data,
    required this.updated_date,
  });

  factory ProductCarListApi.fromJson(Map<String, dynamic> json) =>
      _$ProductCarListApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductCarListApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProductCarApi {
  @JsonKey(defaultValue: 2)
  final int status;
  @JsonKey(defaultValue: '')
  final String message;
  @JsonKey(defaultValue: [])
  final List<ProductCar> data;

  const ProductCarApi({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ProductCarApi.fromJson(Map<String, dynamic> json) =>
      _$ProductCarApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductCarApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProductUnitApi {
  @JsonKey(defaultValue: 2)
  final int status;
  @JsonKey(defaultValue: '')
  final String message;
  final ProductUnit data;

  const ProductUnitApi({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ProductUnitApi.fromJson(Map<String, dynamic> json) =>
      _$ProductUnitApiFromJson(json);
  Map<String, dynamic> toJson() => _$ProductUnitApiToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Product {
  @JsonKey(defaultValue: -1)
  final int id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: '')
  final String code;
  @JsonKey(defaultValue: '')
  final String barcode;
  @JsonKey(defaultValue: '')
  final String sub_name;
  @JsonKey(defaultValue: '')
  final String brand;
  @JsonKey(defaultValue: '')
  final String sub_brand;
  @JsonKey(defaultValue: -1)
  final int category_id;
  @JsonKey(defaultValue: -1)
  final int sub_category_id;
  @JsonKey(defaultValue: -1)
  final int default_supp_id;
  @JsonKey(defaultValue: -1)
  final int auto_sendto_supplier_flag;
  @JsonKey(defaultValue: -1)
  final int base_unit_id;
  @JsonKey(defaultValue: -1)
  final int default_unit_id;
  @JsonKey(defaultValue: 0.0,fromJson: _toDouble)
  final double price;
  @JsonKey(defaultValue: 0.0,fromJson: _toDouble)
  final double mrp;
  @JsonKey(defaultValue: 0.0,fromJson: _toDouble)
  final double retail_price;
  @JsonKey(defaultValue: 0.0,fromJson: _toDouble)
  final double fitting_charge;
  @JsonKey(defaultValue: '')
  final String note;
  @JsonKey(defaultValue: '')
  final String photo;

  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.barcode,
    required this.sub_name,
    required this.brand,
    required this.sub_brand,
    required this.category_id,
    required this.sub_category_id,
    required this.default_supp_id,
    required this.auto_sendto_supplier_flag,
    required this.base_unit_id,
    required this.default_unit_id,
    required this.price,
    required this.mrp,
    required this.retail_price,
    required this.fitting_charge,
    required this.note,
    required this.photo,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  /// Convert from database map (camelCase column names)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['productId'] as int? ?? -1,
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      sub_name: map['subName'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      sub_brand: map['subBrand'] as String? ?? '',
      category_id: map['categoryId'] as int? ?? -1,
      sub_category_id: map['subCategoryId'] as int? ?? -1,
      default_supp_id: map['defaultSuppId'] as int? ?? -1,
      auto_sendto_supplier_flag: map['autoSend'] as int? ?? -1,
      base_unit_id: map['baseUnitId'] as int? ?? -1,
      default_unit_id: map['defaultUnitId'] as int? ?? -1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      retail_price: (map['retailPrice'] as num?)?.toDouble() ?? 0.0,
      fitting_charge: (map['fittingCharge'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String? ?? '',
      photo: map['photoUrl'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'productId': id,
      'code': code,
      'barcode': barcode,
      'name': name,
      'subName': sub_name,
      'brand': brand,
      'subBrand': sub_brand,
      'categoryId': category_id,
      'subCategoryId': sub_category_id,
      'defaultSuppId': default_supp_id,
      'autoSend': auto_sendto_supplier_flag,
      'baseUnitId': base_unit_id,
      'defaultUnitId': default_unit_id,
      'photoUrl': photo,
      'price': price,
      'mrp': mrp,
      'retailPrice': retail_price,
      'fittingCharge': fitting_charge,
      'note': note,
      'outtOfStockFlag': 1,
      'flag': 1,
    };
  }
}

@JsonSerializable()
class ProductUnit {
  @JsonKey(defaultValue: -1)
  final int id;
  @JsonKey(defaultValue: -1)
  final int prd_id;
  @JsonKey(defaultValue: -1)
  final int base_unit_id;
  @JsonKey(defaultValue: -1)
  final int derived_unit_id;

  const ProductUnit({
    required this.id,
    required this.prd_id,
    required this.base_unit_id,
    required this.derived_unit_id,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) =>
      _$ProductUnitFromJson(json);
  Map<String, dynamic> toJson() => _$ProductUnitToJson(this);
}

@JsonSerializable()
class ProductCar {
  @JsonKey(defaultValue: -1)
  final int id;
  @JsonKey(defaultValue: -1)
  final int product_id;
  @JsonKey(defaultValue: -1)
  final int car_brand_id;
  @JsonKey(defaultValue: -1)
  final int car_name_id;
  @JsonKey(defaultValue: -1)
  final int car_model_id;
  @JsonKey(defaultValue: -1)
  final int car_version_id;
  final int? flag;

  const ProductCar({
    required this.id,
    required this.product_id,
    required this.car_brand_id,
    required this.car_name_id,
    required this.car_model_id,
    required this.car_version_id,
    this.flag,
  });

  factory ProductCar.fromJson(Map<String, dynamic> json) =>
      _$ProductCarFromJson(json);
  Map<String, dynamic> toJson() => _$ProductCarToJson(this);
}


double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}