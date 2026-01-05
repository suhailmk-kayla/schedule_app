import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import '../../repositories/users/users_repository.dart';
import '../../repositories/user_category/user_category_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/user_category_model.dart';

/// User with Category Name
/// Helper class to display user with its category name
class UserWithCategory {
  final User user;
  final String categoryName;

  const UserWithCategory({
    required this.user,
    required this.categoryName,
  });
}

class UsersProvider extends ChangeNotifier {
  final UsersRepository _usersRepository;
  final UserCategoryRepository _userCategoryRepository;

  UsersProvider({
    required UsersRepository usersRepository,
    required UserCategoryRepository userCategoryRepository,
  })  : _usersRepository = usersRepository,
        _userCategoryRepository = userCategoryRepository;

  List<User> _users = [];
  List<User> get users => _users;

  List<User> _storekeepers = [];
  List<User> get storekeepers => _storekeepers;

  UserWithCategory? _currentUser;
  UserWithCategory? get currentUser => _currentUser;

  List<UserCategory> _userCategories = [];
  List<UserCategory> get userCategories => _userCategories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isUserActive = true;
  bool get isUserActive => _isUserActive;

  Future<void> loadUsers({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.getAllUsers(searchKey: searchKey);
    result.fold(
      (failure) => _errorMessage = failure.message,
      (list) => _users = list,
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Load user by ID with category name
  /// Converted from KMP's getUserWthId
  Future<void> loadUserById(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.getUserByIdWithCategoryName(userId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      },
      (map) {
        if (map == null) {
          _errorMessage = 'User not found';
          _currentUser = null;
        } else {
          final user = User.fromMap(map);
          final categoryName = map['categoryName'] as String? ?? '';
          _currentUser = UserWithCategory(
            user: user,
            categoryName: categoryName,
          );
        }
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Change user password
  /// Converted from KMP's changeUserPassword
  Future<bool> changeUserPassword({
    required int userId,
    required String password,
    required String confirmPassword,
  }) async {
    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.changeUserPassword(
      userId: userId,
      password: password,
      confirmPassword: confirmPassword,
    );

    return await result.fold(
      (failure) async {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (_) async {
        _isLoading = false;
        // Reload user data after password change to ensure UI is updated
        await loadUserById(userId);
        notifyListeners();
        return true;
      },
    );
  }

  /// Logout user from all devices
  /// Converted from KMP's logoutFromDevices
  Future<bool> logoutFromDevices(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.logoutFromDevices(userId: userId);

    return await result.fold(
      (failure) async {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (_) async {
        _isLoading = false;
        // Clear deviceToken in local DB after logout
        await _usersRepository.clearUserDeviceToken(userId);
        // After logout, check if user is still active
        await checkUserActive(userId);
        // Reload user data to ensure UI is updated
        await loadUserById(userId);
        notifyListeners();
        return true;
      },
    );
  }

  /// Delete user
  /// Converted from KMP's deleteUser
  Future<bool> deleteUser({
    required int userId,
    required int categoryId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.deleteUser(
      userId: userId,
      categoryId: categoryId,
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
        // loadUsers();
        return true;
      },
    );
  }

  /// Check if user is active
  /// Converted from KMP's checkUserActive
  Future<void> checkUserActive(int userId) async {
    final result = await _usersRepository.checkUserActive(userId: userId);
    result.fold(
      (_) {
        developer.log('User is not active');
        _isUserActive = false;
        notifyListeners();
      },
      (isActive) {
        _isUserActive = isActive;
        developer.log('User is active: $isActive');
        notifyListeners();
      },
    );
  }

  /// Get all user categories
  /// Converted from KMP's getAllCategories
  Future<void> getAllUserCategories() async {
    final result = await _userCategoryRepository.getAllUserCategories();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (categories) {
        _userCategories = categories;
        notifyListeners();
      },
    );
  }

  /// Create new user
  /// Converted from KMP's saveUser
  Future<bool> createUser({
    required String code,
    required String name,
    required String phone,
    required int categoryId,
    required String address,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.createUser(
      code: code,
      name: name,
      phone: phone,
      categoryId: categoryId,
      address: address,
      password: password,
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

  /// Update user
  /// Converted from KMP's updateUser
  Future<bool> updateUser({
    required int userId,
    required String code,
    required String name,
    required String phone,
    required int categoryId,
    required String address,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.updateUser(
      userId: userId,
      code: code,
      name: name,
      phone: phone,
      address: address,
      categoryId: categoryId,
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

  /// Load storekeepers (category 2)
  /// Converted from KMP's getStorekeepers
  Future<void> loadStorekeepers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.getUsersByCategory(2);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _storekeepers = [];
        _isLoading = false;
        notifyListeners();
      },
      (list) {
        _storekeepers = list;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Check if code already exists (excluding specific user ID)
  /// Used for update operations to allow keeping the same code
  Future<bool> checkCodeExistsWithId(String code, int userId) async {
    final result = await _usersRepository.getUserByCodeWithId(
      code: code,
      userId: userId,
    );
    return result.fold(
      (failure) => false,
      (users) => users.isNotEmpty,
    );
  }

  /// Check if phone number already exists
  /// Used for create operations
  Future<bool> checkPhoneExists(String phone) async {
    final result = await _usersRepository.getUserByPhone(phone);
    return result.fold(
      (failure) => false,
      (users) => users.isNotEmpty,
    );
  }

/// Check if phone number already exists for any user
  Future<bool> checkPhoneNumberTaken(String phone) async {
    final result = await _usersRepository.checkPhoneNumberTaken(phone);
    return result.fold(
      (failure) => false,
      (isTaken) => isTaken,
    );
  }

  /// Check if phone number already exists for a salesman (categoryId = 3)
  /// Used for create operations in salesman screen
  Future<bool> checkSalesmanPhoneExists(String phone) async {
    final result = await _usersRepository.getSalesmanByPhone(phone);
    return result.fold(
      (failure) => false,
      (users) => users.isNotEmpty,
    );
  }

  /// Check if phone number already exists (excluding specific user ID)
  /// Used for update operations to allow keeping the same phone
  Future<bool> checkPhoneExistsWithId(String phone, int userId) async {
    final result = await _usersRepository.getUserByPhoneWithId(
      phone: phone,
      userId: userId,
    );
    return result.fold(
      (failure) => false,
      (users) => users.isNotEmpty,
    );
  }

  /// Check if phone number already exists for a salesman (excluding specific user ID)
  /// Used for update operations in salesman screen
  Future<bool> checkSalesmanPhoneExistsWithId(String phone, int userId) async {
    final result = await _usersRepository.getSalesmanByPhoneWithId(
      phone: phone,
      userId: userId,
    );
    return result.fold(
      (failure) => false,
      (users) => users.isNotEmpty,
    );
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
