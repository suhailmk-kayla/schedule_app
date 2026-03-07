import 'package:json_annotation/json_annotation.dart';

part 'car_api.g.dart';

/// Car API Response
/// Converted from KMP's CarApi.kt
@JsonSerializable()
class CarApi {
  @JsonKey(defaultValue: 2)
  final int status;

  @JsonKey(defaultValue: '')
  final String message;

  @JsonKey(name: 'carBrand')
  final Brand carBrand;

  @JsonKey(name: 'carName')
  final Name carName;

  final List<Model> models;

  const CarApi({
    this.status = 2,
    this.message = '',
    required this.carBrand,
    required this.carName,
    required this.models,
  });

  factory CarApi.fromJson(Map<String, dynamic> json) => _$CarApiFromJson(json);

  Map<String, dynamic> toJson() => _$CarApiToJson(this);
}

/// Car Brand List API Response
/// Converted from KMP's CarBrandListApi
@JsonSerializable()
class CarBrandListApi {
  final List<Brand>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CarBrandListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CarBrandListApi.fromJson(Map<String, dynamic> json) =>
      _$CarBrandListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CarBrandListApiToJson(this);
}

/// Car Name List API Response
/// Converted from KMP's CarNameListApi
@JsonSerializable()
class CarNameListApi {
  final List<Name>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CarNameListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CarNameListApi.fromJson(Map<String, dynamic> json) =>
      _$CarNameListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CarNameListApiToJson(this);
}

/// Car Model List API Response
/// Converted from KMP's CarModelListApi
@JsonSerializable()
class CarModelListApi {
  final List<Model>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CarModelListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CarModelListApi.fromJson(Map<String, dynamic> json) =>
      _$CarModelListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CarModelListApiToJson(this);
}

/// Car Version List API Response
/// Converted from KMP's CarVersionListApi
@JsonSerializable()
class CarVersionListApi {
  final List<Version>? data;

  @JsonKey(name: 'updated_date', defaultValue: '')
  final String updatedDate;

  const CarVersionListApi({
    this.data,
    this.updatedDate = '',
  });

  factory CarVersionListApi.fromJson(Map<String, dynamic> json) =>
      _$CarVersionListApiFromJson(json);

  Map<String, dynamic> toJson() => _$CarVersionListApiToJson(this);
}

/// Brand Model
/// Converted from KMP's Brand class
@JsonSerializable()
class Brand {
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? id; // local autoincrement PK (not part of API)

  @JsonKey(name: 'id', defaultValue: -1) // API/server ID
  final int carBrandId;

  @JsonKey(name: 'brand_name', defaultValue: '')
  final String brandName;

  final int? flag;

  const Brand({
    this.id,
    this.carBrandId = -1,
    this.brandName = '',
    this.flag,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => _$BrandFromJson(json);

  Map<String, dynamic> toJson() => _$BrandToJson(this);

  /// Convert from database map (camelCase column names)
  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      id: map['id'] as int?, // local PK if present
      carBrandId: map['carBrandId'] as int? ?? -1,
      brandName: map['name'] as String? ?? '',
      flag: map['flag'] as int?,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'carBrandId': carBrandId, // server ID
      'name': brandName,
      'flag': flag ?? 1,
    };
  }
}

/// Name Model (Car Name)
/// Converted from KMP's Name class
@JsonSerializable()
class Name {
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? id; // local autoincrement PK

  @JsonKey(name: 'id', defaultValue: -1) // API/server ID
  final int carNameId;

  @JsonKey(name: 'car_brand_id', defaultValue: -1)
  final int carBrandId;

  @JsonKey(name: 'car_name', defaultValue: '')
  final String carName;

  final int? flag;

  const Name({
    this.id,
    this.carNameId = -1,
    this.carBrandId = -1,
    this.carName = '',
    this.flag,
  });

  factory Name.fromJson(Map<String, dynamic> json) => _$NameFromJson(json);

  Map<String, dynamic> toJson() => _$NameToJson(this);

  /// Convert from database map (camelCase column names)
  factory Name.fromMap(Map<String, dynamic> map) {
    return Name(
      id: map['id'] as int?, // local PK
      carNameId: map['carNameId'] as int? ?? -1,
      carBrandId: map['carBrandId'] as int? ?? -1,
      carName: map['name'] as String? ?? '',
      flag: map['flag'] as int?,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'carNameId': carNameId, // server ID
      'carBrandId': carBrandId,
      'name': carName,
      'flag': flag ?? 1,
    };
  }
}

/// Model (Car Model)
/// Converted from KMP's Model class
@JsonSerializable()
class Model {
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? id; // local autoincrement PK

  @JsonKey(name: 'id', defaultValue: -1) // API/server ID
  final int carModelId;

  @JsonKey(name: 'car_brand_id', defaultValue: -1)
  final int carBrandId;

  @JsonKey(name: 'car_name_id', defaultValue: -1)
  final int carNameId;

  @JsonKey(name: 'model_name', defaultValue: '')
  final String modelName;

  final int? flag;

  final List<Version>? versions;

  const Model({
    this.id,
    this.carModelId = -1,
    this.carBrandId = -1,
    this.carNameId = -1,
    this.modelName = '',
    this.flag,
    this.versions,
  });

  factory Model.fromJson(Map<String, dynamic> json) => _$ModelFromJson(json);

  Map<String, dynamic> toJson() => _$ModelToJson(this);

  /// Convert from database map (camelCase column names)
  factory Model.fromMap(Map<String, dynamic> map) {
    return Model(
      id: map['id'] as int?, // local PK
      carModelId: map['carModelId'] as int? ?? -1,
      carBrandId: map['carBrandId'] as int? ?? -1,
      carNameId: map['carNameId'] as int? ?? -1,
      modelName: map['name'] as String? ?? '',
      flag: map['flag'] as int?,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'carModelId': carModelId, // server ID
      'carBrandId': carBrandId,
      'carNameId': carNameId,
      'name': modelName,
      'flag': flag ?? 1,
    };
  }
}

/// Version Model (Car Version)
/// Converted from KMP's Version class
@JsonSerializable()
class Version {
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int? id; // local autoincrement PK

  @JsonKey(name: 'id', defaultValue: -1) // API/server ID
  final int carVersionId;

  @JsonKey(name: 'car_brand_id', defaultValue: -1)
  final int carBrandId;

  @JsonKey(name: 'car_name_id', defaultValue: -1)
  final int carNameId;

  @JsonKey(name: 'car_model_id', defaultValue: -1)
  final int carModelId;

  @JsonKey(name: 'version_name', defaultValue: '')
  final String versionName;

  final int? flag;

  const Version({
    this.id,
    this.carVersionId = -1,
    this.carBrandId = -1,
    this.carNameId = -1,
    this.carModelId = -1,
    this.versionName = '',
    this.flag,
  });

  factory Version.fromJson(Map<String, dynamic> json) =>
      _$VersionFromJson(json);

  Map<String, dynamic> toJson() => _$VersionToJson(this);

  /// Convert from database map (camelCase column names)
  factory Version.fromMap(Map<String, dynamic> map) {
    return Version(
      id: map['id'] as int?, // local PK
      carVersionId: map['carVersionId'] as int? ?? -1,
      carBrandId: map['carBrandId'] as int? ?? -1,
      carNameId: map['carNameId'] as int? ?? -1,
      carModelId: map['carModelId'] as int? ?? -1,
      versionName: map['name'] as String? ?? '',
      flag: map['flag'] as int?,
    );
  }

  /// Convert to database map (camelCase column names)
  Map<String, dynamic> toMap() {
    return {
      'carVersionId': carVersionId, // server ID
      'carBrandId': carBrandId,
      'carNameId': carNameId,
      'carModelId': carModelId,
      'name': versionName,
      'flag': flag ?? 1,
    };
  }
}

