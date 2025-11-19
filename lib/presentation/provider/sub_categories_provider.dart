import 'package:flutter/foundation.dart' hide Category;
import 'dart:developer' as developer;
import '../../repositories/sub_categories/sub_categories_repository.dart';
import '../../repositories/categories/categories_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/push_data.dart';
import '../../utils/push_notification_sender.dart';
import '../../utils/notification_id.dart';

/// SubCategories Provider
/// Manages sub-categories-related state and operations
/// Converted from KMP's SubCategoryViewModel.kt
class SubCategoriesProvider extends ChangeNotifier {
  final SubCategoriesRepository _subCategoriesRepository;
  final CategoriesRepository _categoriesRepository;
  final PushNotificationSender _pushNotificationSender;

  SubCategoriesProvider({
    required SubCategoriesRepository subCategoriesRepository,
    required CategoriesRepository categoriesRepository,
    required PushNotificationSender pushNotificationSender,
  })  : _subCategoriesRepository = subCategoriesRepository,
        _categoriesRepository = categoriesRepository,
        _pushNotificationSender = pushNotificationSender;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<SubCategoryWithCategory> _subCategoriesList = [];
  List<SubCategoryWithCategory> get subCategoriesList => _subCategoriesList;

  List<Category> _categoriesList = [];
  List<Category> get categoriesList => _categoriesList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load all sub categories with optional search key
  /// Converted from KMP's getSubCategory function
  Future<void> getSubCategories({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _subCategoriesRepository.getAllSubCategoriesWithCategoryName(
      searchKey: searchKey,
    );
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (maps) {
        // Extract categoryName from raw query result
        _subCategoriesList = maps.map((map) {
          final subCategory = SubCategory.fromMap(map);
          final categoryName = map['categoryName'] as String? ?? '';
          return SubCategoryWithCategory(
            subCategory: subCategory,
            categoryName: categoryName,
          );
        }).toList();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Load all categories (for selection in dialog)
  /// Converted from KMP's getCategory function
  Future<void> getAllCategories() async {
    final result = await _categoriesRepository.getAllCategories();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (categories) {
        _categoriesList = categories;
        notifyListeners();
      },
    );
  }

  /// Create a new sub category
  /// Converted from KMP's addSubCategory function
  Future<bool> createSubCategory({
    required String name,
    required int parentId,
    String remark = '',
  }) async {
    // Validate name doesn't exist for this parent
    final nameResult = await _subCategoriesRepository.getSubCategoryByName(
      name: name,
      parentId: parentId,
    );
    nameResult.fold(
      (_) {},
      (existingSubCategories) {
        if (existingSubCategories.isNotEmpty) {
          _errorMessage = 'Sub-Category name already exist';
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

    final result = await _subCategoriesRepository.createSubCategory(
      name: name,
      parentId: parentId,
      remark: remark,
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (createdSubCategory) {
        // Send push notification (matches KMP lines 71-73)
        final dataIds = [
          PushData(table: NotificationId.subCategory, id: createdSubCategory.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Sub-Category updates',
        ).catchError((e) {
          developer.log('SubCategoriesProvider: Error sending push notification: $e');
        });

        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Update an existing sub category
  /// Converted from KMP's updateSubCategory function
  Future<bool> updateSubCategory({
    required int subCategoryId,
    required int parentId,
    required String name,
  }) async {
    // Validate name doesn't exist (excluding current sub category)
    final nameResult = await _subCategoriesRepository.getSubCategoryByNameAndId(
      name: name,
      parentId: parentId,
      subCategoryId: subCategoryId,
    );
    nameResult.fold(
      (_) {},
      (existingSubCategories) {
        if (existingSubCategories.isNotEmpty) {
          _errorMessage = 'Sub-Category name already exist';
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

    final result = await _subCategoriesRepository.updateSubCategory(
      subCategoryId: subCategoryId,
      parentId: parentId,
      name: name,
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (updatedSubCategory) {
        // Send push notification (matches KMP lines 104-106)
        final dataIds = [
          PushData(table: NotificationId.subCategory, id: updatedSubCategory.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Sub-Category updates',
        ).catchError((e) {
          developer.log('SubCategoriesProvider: Error sending push notification: $e');
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

/// SubCategory with Category Name
/// Helper class to display sub-category with its parent category name
/// Converted from KMP's SubCategoryWithCategory
class SubCategoryWithCategory {
  final SubCategory subCategory;
  final String categoryName;

  const SubCategoryWithCategory({
    required this.subCategory,
    required this.categoryName,
  });
}

