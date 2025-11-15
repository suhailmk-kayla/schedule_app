import 'car_api.dart';

/// Cars Model
/// Composite object containing car brand, name, and model list
/// Converted from KMP's Cars.kt
class Cars {
  final String carBrand;
  final Name? carName;
  final List<CarModelAndVersion> carModelList;

  const Cars({
    this.carBrand = '',
    this.carName,
    this.carModelList = const [],
  });

  Cars copyWith({
    String? carBrand,
    Name? carName,
    List<CarModelAndVersion>? carModelList,
  }) {
    return Cars(
      carBrand: carBrand ?? this.carBrand,
      carName: carName ?? this.carName,
      carModelList: carModelList ?? this.carModelList,
    );
  }
}

/// Car Model and Version
/// Contains a car model with its associated versions
/// Converted from KMP's CarModelAndVersion
class CarModelAndVersion {
  final Model carModel;
  final List<Version> carVersionList;

  const CarModelAndVersion({
    required this.carModel,
    this.carVersionList = const [],
  });

  CarModelAndVersion copyWith({
    Model? carModel,
    List<Version>? carVersionList,
  }) {
    return CarModelAndVersion(
      carModel: carModel ?? this.carModel,
      carVersionList: carVersionList ?? this.carVersionList,
    );
  }
}

