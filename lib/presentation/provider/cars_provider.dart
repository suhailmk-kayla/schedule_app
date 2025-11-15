import 'package:flutter/foundation.dart';
import '../../repositories/cars/car_brand_repository.dart';
import '../../repositories/cars/car_name_repository.dart';
import '../../repositories/cars/car_model_repository.dart';
import '../../repositories/cars/car_version_repository.dart';
import '../../models/car_api.dart';
import '../../models/cars.dart';

/// Cars Provider
/// Manages cars-related state and operations
/// Converted from KMP's CarsViewModel.kt
class CarsProvider extends ChangeNotifier {
  final CarBrandRepository _carBrandRepository;
  final CarNameRepository _carNameRepository;
  final CarModelRepository _carModelRepository;
  final CarVersionRepository _carVersionRepository;

  CarsProvider({
    required CarBrandRepository carBrandRepository,
    required CarNameRepository carNameRepository,
    required CarModelRepository carModelRepository,
    required CarVersionRepository carVersionRepository,
  })  : _carBrandRepository = carBrandRepository,
        _carNameRepository = carNameRepository,
        _carModelRepository = carModelRepository,
        _carVersionRepository = carVersionRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Cars> _carsList = [];
  List<Cars> get carsList => _carsList;

  List<Brand> _brandList = [];
  List<Brand> get brandList => _brandList;

  List<Name> _nameList = [];
  List<Name> get nameList => _nameList;

  List<Model> _modelList = [];
  List<Model> get modelList => _modelList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load all cars with optional search key
  /// Converted from KMP's getCars function
  Future<void> getCars({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get cars with brand names
      final carsResult = await _carNameRepository.getAllCars(searchKey: searchKey);
      
      final result = await carsResult.fold(
        (failure) async {
          _errorMessage = failure.message;
          _isLoading = false;
          notifyListeners();
          return <Cars>[];
        },
        (maps) async {
          // Convert maps to Cars objects and load models/versions
          final List<Cars> cars = [];
          
          for (final map in maps) {
            final carName = Name.fromMap(map);
            final carBrand = map['carBrand'] as String? ?? '';
            
            // Load models for this car
            final modelsResult = await _carModelRepository.getCarModels(
              brandId: carName.carBrandId,
              nameId: carName.id,
            );
            
            final List<CarModelAndVersion> carModelAndVersionList = [];
            
            await modelsResult.fold(
              (_) async {},
              (models) async {
                for (final model in models) {
                  // Load versions for this model
                  final versionsResult = await _carVersionRepository.getAllCarVersions(
                    brandId: model.carBrandId,
                    nameId: model.carNameId,
                    modelId: model.id,
                  );
                  
                  final List<Version> versions = [];
                  versionsResult.fold(
                    (_) {},
                    (vers) {
                      versions.addAll(vers);
                    },
                  );
                  
                  carModelAndVersionList.add(
                    CarModelAndVersion(
                      carModel: model,
                      carVersionList: versions,
                    ),
                  );
                }
              },
            );
            
            cars.add(
              Cars(
                carBrand: carBrand,
                carName: carName,
                carModelList: carModelAndVersionList,
              ),
            );
          }
          
          return cars;
        },
      );
      
      if (result.isNotEmpty || _errorMessage == null) {
        _carsList = result;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all car brands
  /// Converted from KMP's checkCarBrandExist function
  Future<void> getAllCarBrands() async {
    final result = await _carBrandRepository.getAllCarBrands();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (brands) {
        _brandList = brands;
        notifyListeners();
      },
    );
  }

  /// Load car names by brand ID
  /// Converted from KMP's getCarNames function
  Future<void> getCarNames(int brandId) async {
    if (brandId == -1) {
      _nameList = [];
      notifyListeners();
      return;
    }

    final result = await _carNameRepository.getCarNamesByBrandId(brandId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (names) {
        _nameList = names;
        notifyListeners();
      },
    );
  }

  /// Load car models by brand ID and name ID
  /// Converted from KMP's getCarModels function
  Future<void> getCarModels({required int brandId, required int nameId}) async {
    if (brandId == -1 || nameId == -1) {
      _modelList = [];
      notifyListeners();
      return;
    }

    final result = await _carModelRepository.getCarModels(
      brandId: brandId,
      nameId: nameId,
    );
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (models) {
        _modelList = models;
        notifyListeners();
      },
    );
  }

  /// Check if car brand exists
  /// Converted from KMP's checkCarBrandExist function
  Future<bool> checkCarBrandExist(String name) async {
    final result = await _carBrandRepository.getCarBrandByName(name);
    return result.fold(
      (_) => false,
      (brands) => brands.isNotEmpty,
    );
  }

  /// Check if car name exists
  /// Converted from KMP's checkCarNameExist function
  Future<bool> checkCarNameExist(String name, int brandId) async {
    final result = await _carNameRepository.getCarNameByName(
      name: name,
      brandId: brandId,
    );
    return result.fold(
      (_) => false,
      (names) => names.isNotEmpty,
    );
  }

  /// Check if car model exists
  /// Converted from KMP's checkCarModelExist function
  Future<bool> checkCarModelExist(String name, int brandId, int nameId) async {
    final result = await _carModelRepository.getCarModelByName(
      name: name,
      brandId: brandId,
      nameId: nameId,
    );
    return result.fold(
      (_) => false,
      (models) => models.isNotEmpty,
    );
  }

  /// Check if car version exists
  /// Converted from KMP's checkCarVersionExist function
  Future<bool> checkCarVersionExist(
    String name,
    int brandId,
    int nameId,
    int modelId,
  ) async {
    final result = await _carVersionRepository.getCarVersionByName(
      name: name,
      brandId: brandId,
      nameId: nameId,
      modelId: modelId,
    );
    return result.fold(
      (_) => false,
      (versions) => versions.isNotEmpty,
    );
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

