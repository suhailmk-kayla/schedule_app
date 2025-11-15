import 'package:flutter/foundation.dart' hide Category;
import '../../repositories/categories/categories_repository.dart';
import '../../models/master_data_api.dart';

/// Categories Provider
/// Manages categories-related state and operations
/// Converted from KMP's CategoryViewModel.kt
class CategoriesProvider extends ChangeNotifier {
  final CategoriesRepository _categoriesRepository;

  CategoriesProvider({
    required CategoriesRepository categoriesRepository,
  }) : _categoriesRepository = categoriesRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Category> _categoriesList = [];
  List<Category> get categoriesList => _categoriesList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load all categories with optional search key
  /// Converted from KMP's getCategory function
  Future<void> getCategories({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _categoriesRepository.getAllCategories(searchKey: searchKey);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (categories) {
        _categoriesList = categories;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Create a new category
  /// Converted from KMP's addCategory function
  Future<bool> createCategory({
    required String name,
    String remark = '',
  }) async {
    // Validate name doesn't exist
    final nameResult = await _categoriesRepository.getCategoryByName(name);
    nameResult.fold(
      (_) {},
      (existingCategories) {
        if (existingCategories.isNotEmpty) {
          _errorMessage = 'Category name already exist';
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

    final result = await _categoriesRepository.createCategory(
      name: name,
      remark: remark,
    );

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

  /// Update an existing category
  /// Converted from KMP's updateCategory function
  Future<bool> updateCategory({
    required int categoryId,
    required String name,
  }) async {
    // Validate name doesn't exist (excluding current category)
    final nameResult = await _categoriesRepository.getCategoryByNameWithId(
      name: name,
      categoryId: categoryId,
    );
    nameResult.fold(
      (_) {},
      (existingCategories) {
        if (existingCategories.isNotEmpty) {
          _errorMessage = 'Category name already exist';
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

    final result = await _categoriesRepository.updateCategory(
      categoryId: categoryId,
      name: name,
    );

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

