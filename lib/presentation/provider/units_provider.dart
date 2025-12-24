import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../repositories/units/units_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/push_data.dart';
import '../../utils/push_notification_sender.dart';
import '../../utils/notification_id.dart';

/// Units Provider
/// Manages units-related state and operations
/// Converted from KMP's UnitsViewModel.kt
class UnitsProvider extends ChangeNotifier {
  final UnitsRepository _unitsRepository;
  final PushNotificationSender _pushNotificationSender;

  UnitsProvider({
    required UnitsRepository unitsRepository,
    required PushNotificationSender pushNotificationSender,
  })  : _unitsRepository = unitsRepository,
        _pushNotificationSender = pushNotificationSender;

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
          developer.log('UnitsProvider: Error creating unit: ${_errorMessage}');
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
          developer.log('UnitsProvider: Error creating unit: ${_errorMessage}');
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
      (createdUnit) {
        // Send push notification (matches KMP lines 74-76)
        final dataIds = [
          PushData(table: NotificationId.units, id: createdUnit.unitId), // Use server ID
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Unit updates',
        ).catchError((e) {
          developer.log('UnitsProvider: Error sending push notification: $e');
        });

        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Update an existing unit
  /// Only updates fields that are provided (not null) and actually changed
  /// Uses server ID (unitId) for API calls, not local ID
  /// Converted from KMP's updateUnit function (UnitsViewModel.kt lines 140-165)
  Future<bool> updateUnit({
    required Units unit,
    String? name,
    String? displayName,
  }) async {
    // Extract trimmed values for comparison
    final String? trimmedName = name?.trim();
    final String? trimmedDisplayName = displayName?.trim();

    // Check if there are any actual changes
    final hasNameChange =
        trimmedName != null && trimmedName != unit.name.trim();
    final hasDisplayNameChange =
        trimmedDisplayName != null && trimmedDisplayName != unit.displayName.trim();

    if (!hasNameChange && !hasDisplayNameChange) {
      // No changes to update
      return true;
    }

    // Only validate name if it's being changed
    if (hasNameChange && trimmedName != null) {
      // Use server ID (unitId) for validation, not local id
      final nameResult = await _unitsRepository.getUnitByName(
        trimmedName,
        unitId: unit.unitId, // Use server ID
      );
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
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Pass only changed fields to repository
    // Repository will use server ID (unitId) for API call
    final result = await _unitsRepository.updateUnit(
      unit: unit, // Pass original unit (contains server ID)
      name: hasNameChange ? trimmedName : null, // Only pass if changed
      displayName: hasDisplayNameChange ? trimmedDisplayName : null, // Only pass if changed
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (updatedUnitResult) {
        // Send push notification (matches KMP lines 158-160)
        // Use server ID (unitId) for push notification
        final dataIds = [
          PushData(table: NotificationId.units, id: updatedUnitResult.unitId),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Unit updates',
        ).catchError((e) {
          developer.log('UnitsProvider: Error sending push notification: $e');
        });

        // Refresh units list to reflect the changes
        getUnits().catchError((e) {
          developer.log('UnitsProvider: Error refreshing units after update: $e');
        });

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

