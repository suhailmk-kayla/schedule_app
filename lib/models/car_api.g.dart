// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarApi _$CarApiFromJson(Map<String, dynamic> json) => CarApi(
  status: (json['status'] as num?)?.toInt() ?? 2,
  message: json['message'] as String? ?? '',
  carBrand: Brand.fromJson(json['carBrand'] as Map<String, dynamic>),
  carName: Name.fromJson(json['carName'] as Map<String, dynamic>),
  models: (json['models'] as List<dynamic>)
      .map((e) => Model.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CarApiToJson(CarApi instance) => <String, dynamic>{
  'status': instance.status,
  'message': instance.message,
  'carBrand': instance.carBrand,
  'carName': instance.carName,
  'models': instance.models,
};

CarBrandListApi _$CarBrandListApiFromJson(Map<String, dynamic> json) =>
    CarBrandListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Brand.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CarBrandListApiToJson(CarBrandListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

CarNameListApi _$CarNameListApiFromJson(Map<String, dynamic> json) =>
    CarNameListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Name.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CarNameListApiToJson(CarNameListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

CarModelListApi _$CarModelListApiFromJson(Map<String, dynamic> json) =>
    CarModelListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Model.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CarModelListApiToJson(CarModelListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

CarVersionListApi _$CarVersionListApiFromJson(Map<String, dynamic> json) =>
    CarVersionListApi(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => Version.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedDate: json['updated_date'] as String? ?? '',
    );

Map<String, dynamic> _$CarVersionListApiToJson(CarVersionListApi instance) =>
    <String, dynamic>{
      'data': instance.data,
      'updated_date': instance.updatedDate,
    };

Brand _$BrandFromJson(Map<String, dynamic> json) => Brand(
  id: (json['id'] as num?)?.toInt() ?? -1,
  brandName: json['brand_name'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
);

Map<String, dynamic> _$BrandToJson(Brand instance) => <String, dynamic>{
  'id': instance.id,
  'brand_name': instance.brandName,
  'flag': instance.flag,
};

Name _$NameFromJson(Map<String, dynamic> json) => Name(
  id: (json['id'] as num?)?.toInt() ?? -1,
  carBrandId: (json['car_brand_id'] as num?)?.toInt() ?? -1,
  carName: json['car_name'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
);

Map<String, dynamic> _$NameToJson(Name instance) => <String, dynamic>{
  'id': instance.id,
  'car_brand_id': instance.carBrandId,
  'car_name': instance.carName,
  'flag': instance.flag,
};

Model _$ModelFromJson(Map<String, dynamic> json) => Model(
  id: (json['id'] as num?)?.toInt() ?? -1,
  carBrandId: (json['car_brand_id'] as num?)?.toInt() ?? -1,
  carNameId: (json['car_name_id'] as num?)?.toInt() ?? -1,
  modelName: json['model_name'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
  versions: (json['versions'] as List<dynamic>?)
      ?.map((e) => Version.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ModelToJson(Model instance) => <String, dynamic>{
  'id': instance.id,
  'car_brand_id': instance.carBrandId,
  'car_name_id': instance.carNameId,
  'model_name': instance.modelName,
  'flag': instance.flag,
  'versions': instance.versions,
};

Version _$VersionFromJson(Map<String, dynamic> json) => Version(
  id: (json['id'] as num?)?.toInt() ?? -1,
  carBrandId: (json['car_brand_id'] as num?)?.toInt() ?? -1,
  carNameId: (json['car_name_id'] as num?)?.toInt() ?? -1,
  carModelId: (json['car_model_id'] as num?)?.toInt() ?? -1,
  versionName: json['version_name'] as String? ?? '',
  flag: (json['flag'] as num?)?.toInt(),
);

Map<String, dynamic> _$VersionToJson(Version instance) => <String, dynamic>{
  'id': instance.id,
  'car_brand_id': instance.carBrandId,
  'car_name_id': instance.carNameId,
  'car_model_id': instance.carModelId,
  'version_name': instance.versionName,
  'flag': instance.flag,
};
