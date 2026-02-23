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
  @JsonKey(includeFromJson: false, includeToJson: false, defaultValue: -1)
  final int id; // Local DB primary key (AUTOINCREMENT)
  
  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to productId
  final int productId; // Server ID
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
  @JsonKey(name: 'minimum_price', fromJson: _toNullableDouble)
  final double? minimumPrice;
  @JsonKey(defaultValue: '')
  final String note;
  @JsonKey(defaultValue: '')
  final String photo;

  const Product({
    this.id = -1,
    this.productId = -1,
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
    this.minimumPrice,
    required this.note,
    required this.photo,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  /// Convert from database map (camelCase column names)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int? ?? -1,
      productId: map['productId'] as int? ?? -1,
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
      minimumPrice: (map['minimumPrice'] as num?)?.toDouble(),
      note: map['note'] as String? ?? '',
      photo: map['photoUrl'] as String? ?? '',
    );
  }

  /// Convert to database map (camelCase column names)
  /// Note: 'id' column is omitted - SQLite will auto-increment
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
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
      'minimumPrice': minimumPrice,
      'note': note,
      'outtOfStockFlag': 1,
      'flag': 1,
    };
  }
}

@JsonSerializable()
class ProductUnit {
  @JsonKey(defaultValue: -1, includeFromJson: false, includeToJson: false)
  final int? id; // Local DB primary key (AUTOINCREMENT)

  @JsonKey(name: 'id', defaultValue: -1) // API 'id' maps to productUnitId
  final int productUnitId; // Server ID
  @JsonKey(defaultValue: -1)
  final int prd_id;
  @JsonKey(defaultValue: -1)
  final int base_unit_id;
  @JsonKey(defaultValue: -1)
  final int derived_unit_id;

  const ProductUnit({
    this.id,
    this.productUnitId = -1,
    required this.prd_id,
    required this.base_unit_id,
    required this.derived_unit_id,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) =>
      _$ProductUnitFromJson(json);
  Map<String, dynamic> toJson() => _$ProductUnitToJson(this);

  /// Convert from database map (camelCase column names)
  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'] as int?, // Local DB PK
      productUnitId: map['productUnitId'] as int? ?? -1, // Server ID
      prd_id: map['productId'] as int? ?? -1,
      base_unit_id: map['baseUnitId'] as int? ?? -1,
      derived_unit_id: map['derivedUnitId'] as int? ?? -1,
    );
  }
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

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value);
  }
  return null;
}

/// Product With Details Model
/// Contains Product with category, subcategory, supplier, and base unit names from JOIN queries
/// Converted from KMP's GetAllProductsById result
class ProductWithDetails {
  final Product product;
  
  // Joined fields from query
  final String? categoryName;
  final String? subCategoryName;
  final String? supplierName;
  final String? baseUnitName;

  const ProductWithDetails({
    required this.product,
    this.categoryName,
    this.subCategoryName,
    this.supplierName,
    this.baseUnitName,
  });

  /// Convert from database map (from JOIN query)
  factory ProductWithDetails.fromMap(Map<String, dynamic> map) {
    return ProductWithDetails(
      product: Product.fromMap(map),
      categoryName: map['categoryName'] as String?,
      subCategoryName: map['subCategoryName'] as String?,
      supplierName: map['supplierName'] as String?,
      baseUnitName: map['baseUnitName'] as String?,
    );
  }
}

/// Product Unit With Details Model
/// Contains ProductUnit with base and derived unit names from JOIN queries
/// Converted from KMP's GetDerivedUnitsByProduct
class ProductUnitWithDetails {
  final ProductUnit productUnit;
  final String? baseName;
  final String? derivenName;
  final double? baseQty;

  const ProductUnitWithDetails({
    required this.productUnit,
    this.baseName,
    this.derivenName,
    this.baseQty,
  });

  factory ProductUnitWithDetails.fromMap(Map<String, dynamic> map) {
    return ProductUnitWithDetails(
      productUnit: ProductUnit.fromMap(map),
      baseName: map['baseName'] as String?,
      derivenName: map['derivenName'] as String?,
      baseQty: (map['baseQty'] as num?)?.toDouble(),
    );
  }
}