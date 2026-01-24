import 'package:flutter/foundation.dart' hide Category;
import 'dart:developer' as developer;
import '../../repositories/categories/categories_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/push_data.dart';
import '../../utils/push_notification_sender.dart';
import '../../utils/notification_id.dart';

/// Categories Provider
/// Manages categories-related state and operations
/// Converted from KMP's CategoryViewModel.kt
class CategoriesProvider extends ChangeNotifier {
  final CategoriesRepository _categoriesRepository;
  final PushNotificationSender _pushNotificationSender;

  CategoriesProvider({
    required CategoriesRepository categoriesRepository,
    required PushNotificationSender pushNotificationSender,
  })  : _categoriesRepository = categoriesRepository,
        _pushNotificationSender = pushNotificationSender;

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
      (createdCategory) {
        // Send push notification (matches KMP lines 60-62)
        final dataIds = [
          PushData(table: NotificationId.category, id: createdCategory.categoryId),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Category updates',
        ).catchError((e) {
          developer.log('CategoriesProvider: Error sending push notification: $e');
        });

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
      (updatedCategory) {
        // Send push notification (matches KMP lines 92-94)
        final dataIds = [
          PushData(table: NotificationId.category, id: updatedCategory.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Category updates',
        ).catchError((e) {
          developer.log('CategoriesProvider: Error sending push notification: $e');
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

