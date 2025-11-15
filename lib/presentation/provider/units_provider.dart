import 'package:flutter/foundation.dart';
import '../../repositories/units/units_repository.dart';
import '../../models/master_data_api.dart';

/// Units Provider
/// Manages units-related state and operations
/// Converted from KMP's UnitsViewModel.kt
class UnitsProvider extends ChangeNotifier {
  final UnitsRepository _unitsRepository;

  UnitsProvider({
    required UnitsRepository unitsRepository,
  }) : _unitsRepository = unitsRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Units> _unitsList = [];
  List<Units> get unitsList => _unitsList;

  List<Units> _baseUnitsList = [];
  List<Units> get baseUnitsList => _baseUnitsList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load all units with optional search key
  /// Converted from KMP's getUnits function
  Future<void> getUnits({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _unitsRepository.getAllUnits(searchKey: searchKey);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (units) {
        _unitsList = units;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load all base units (type = 0)
  /// Converted from KMP's getAllBaseUnits function
  Future<void> getAllBaseUnits() async {
    final result = await _unitsRepository.getAllBaseUnits();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (units) {
        _baseUnitsList = units;
        notifyListeners();
      },
    );
  }

  /// Get unit by unit ID
  /// Converted from KMP's getUnitByUnitId function
  Future<Units?> getUnitByUnitId(int unitId) async {
    final result = await _unitsRepository.getUnitByUnitId(unitId);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (unit) => unit,
    );
  }

  /// Create a new unit
  /// Converted from KMP's saveUnit function
  Future<bool> createUnit({
    required int type,
    required int baseUnitId,
    required String code,
    required String name,
    required String displayName,
    required double baseQty,
    required String comment,
  }) async {
    // Validate code doesn't exist
    final codeResult = await _unitsRepository.getUnitByCode(code);
    codeResult.fold(
      (_) {},
      (existingUnit) {
        if (existingUnit != null) {
          _errorMessage = 'Item code already exist';
          notifyListeners();
          return;
        }
      },
    );
    if (_errorMessage != null) {
      return false;
    }

    // Validate name doesn't exist
    final nameResult = await _unitsRepository.getUnitByName(name);
    nameResult.fold(
      (_) {},
      (existingUnit) {
        if (existingUnit != null) {
          _errorMessage = 'Item name already exist';
          notifyListeners();
          return;
        }
      },
    );
    if (_errorMessage != null) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final unit = Units(
      id: -1,
      name: name,
      code: code,
      displayName: displayName,
      type: type,
      baseId: type == 1 ? baseUnitId : -1,
      baseQty: baseQty,
      comment: comment,
    );

    final result = await _unitsRepository.createUnit(unit);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Update an existing unit
  /// Converted from KMP's updateUnit function
  Future<bool> updateUnit({
    required Units unit,
    required String name,
    required String displayName,
  }) async {
    // Validate name doesn't exist (excluding current unit)
    final nameResult = await _unitsRepository.getUnitByName(name, unitId: unit.id);
    nameResult.fold(
      (_) {},
      (existingUnit) {
        if (existingUnit != null) {
          _errorMessage = 'Item name already exist';
          notifyListeners();
          return;
        }
      },
    );
    if (_errorMessage != null) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final updatedUnit = Units(
      id: unit.id,
      name: name,
      code: unit.code,
      displayName: displayName,
      type: unit.type,
      baseId: unit.baseId,
      baseQty: unit.baseQty,
      comment: unit.comment,
    );

    final result = await _unitsRepository.updateUnit(unit: updatedUnit);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

