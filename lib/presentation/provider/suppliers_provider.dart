import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../repositories/suppliers/suppliers_repository.dart';
import '../../models/supplier_model.dart';

/// Suppliers Provider
/// Manages suppliers state and operations
/// Converted from KMP's SuppliersViewModel.kt
class SuppliersProvider extends ChangeNotifier {
  final SuppliersRepository _suppliersRepository;

  SuppliersProvider({
    required SuppliersRepository suppliersRepository,
  }) : _suppliersRepository = suppliersRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Supplier> _suppliersList = [];
  List<Supplier> get suppliersList => _suppliersList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Get all suppliers with optional search key (matching KMP's getSuppliers)
  Future<void> getSuppliers({String searchKey = ''}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _suppliersRepository.getAllSuppliers(
        searchKey: searchKey,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('SuppliersProvider: Failed to get suppliers: ${failure.message}');
        },
        (list) {
          _suppliersList = list;
          developer.log('SuppliersProvider: Loaded ${list.length} suppliers');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('SuppliersProvider: Error in getSuppliers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear provider state
  void clear() {
    _suppliersList = [];
    _errorMessage = null;
    notifyListeners();
  }
}

