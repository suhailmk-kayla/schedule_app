import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import '../../models/auth_models.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/storage_helper.dart';
import '../../utils/push_notification_helper.dart';
import '../../helpers/errors/failures.dart';
import '../../helpers/exceptions/network_exception.dart';
import '../../helpers/exceptions/server_exception.dart';

/// Auth Provider
/// Manages authentication state and operations
/// Converted from KMP's SplashLoginScreen.kt login logic
class AuthProvider extends ChangeNotifier {
  final Dio _dio;

  AuthProvider({
    required Dio dio,
  }) : _dio = dio;

  // ============================================================================
  // State Variables
  // ============================================================================

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  int _userId = 0;
  int get userId => _userId;

  String _userName = '';
  String get userName => _userName;

  int _userType = 0;
  int get userType => _userType;
  // User types: 1-Admin, 2-Storekeeper, 3-SalesMan, 4-supplier, 5-Biller, 6-Checker

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Initialize auth state from storage
  Future<void> initialize() async {
    final isLoggedIn = await StorageHelper.getIsUserLogin();
    if (isLoggedIn == '1') {
      _isAuthenticated = true;
      _userId = await StorageHelper.getUserId();
      _userName = await StorageHelper.getUser();
      _userType = await StorageHelper.getUserType();
      notifyListeners();
    }
  }

  /// Login with user code and password
  Future<Either<Failure, LoginResponseData>> login({
    required String userCode,
    required String password,
    String? deviceToken,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Get device token (OneSignal User ID)
      // First try to get from parameter, then from storage, then fetch from OneSignal
      String? token = deviceToken;
      
      if (token == null || token.isEmpty) {
        // Try to get from storage first
        token = await StorageHelper.getDeviceToken();
        
        // If still empty, try to fetch from OneSignal (like KMP does)
        if (token.isEmpty) {
          developer.log('Device token not in storage, fetching from OneSignal...');
          token = await PushNotificationHelper.fetchPushId(maxRetries: 20);
          
          // If we got a token, save it to storage
          if (token != null && token.isNotEmpty) {
            await StorageHelper.setDeviceToken(token);
            developer.log('OneSignal User ID saved to storage: $token');
          }
        }
      }

      // Create login request payload (matching KMP's structure exactly)
      final requestPayload = <String, dynamic>{
        'code': userCode.trim(),
        'password': password,
      };

      // Backend requires device_token to be non-null
      // If we still don't have a token after retrying, use placeholder
      if (token != null && token.isNotEmpty) {
        requestPayload['token'] = token;
        developer.log('Using OneSignal User ID as device token: $token');
      } else {
        // Use placeholder - backend requires non-null device_token
        // This should rarely happen if OneSignal is properly initialized
        requestPayload['token'] = 'not_available';
        developer.log('Warning: Device token is empty after retries, using placeholder');
      }

      // Debug: Log request payload
      developer.log('Login request payload: $requestPayload');

      // Call login API
      // Use Options to ensure JSON content type (matching KMP's jsonRaw)
      final response = await _dio.post(
        ApiEndpoints.login,
        data: requestPayload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Debug: Log response structure
      developer.log('Login response type: ${response.data.runtimeType}');
      developer.log('Login response: ${response.data}');
      developer.log('Login status code: ${response.statusCode}');

      // Handle different response types
      // The API might return a List in some error cases, or the response might be wrapped
      Map<String, dynamic> responseData;
      
      if (response.data is List) {
        // If response is a List, it might be an error response
        // Check if it's a single-item list that should be unwrapped
        final listData = response.data as List;
        developer.log('Warning: Login response is a List with ${listData.length} items');
        
        if (listData.isEmpty) {
          throw Exception('Empty response from server');
        }
        
        // If it's a list with one item that's a map, use that
        if (listData.length == 1 && listData[0] is Map) {
          responseData = Map<String, dynamic>.from(listData[0] as Map);
          developer.log('Unwrapped single-item list to Map');
        } else {
          // Otherwise, try to construct a proper error response
          throw Exception('Invalid response format: Expected Map but got List with ${listData.length} items');
        }
      } else if (response.data is Map<String, dynamic>) {
        responseData = response.data as Map<String, dynamic>;
      } else if (response.data is Map) {
        // Handle Map<dynamic, dynamic>
        responseData = Map<String, dynamic>.from(response.data as Map);
      } else {
        developer.log('Error: Unexpected response type: ${response.data.runtimeType}');
        throw Exception('Invalid response format: ${response.data.runtimeType}');
      }

      // Parse response
      final loginResponse = LoginResponse.fromJson(responseData);

      if (loginResponse.isSuccess && loginResponse.data != null) {
        final userData = loginResponse.data!;

        // Store user data in secure storage
        await StorageHelper.setUserToken(userData.token);
        await StorageHelper.setUserId(userData.id);
        await StorageHelper.setUser(userData.name);
        await StorageHelper.setUserType(userData.catId);
        await StorageHelper.setIsUserLogin('1');
        if (token != null && token.isNotEmpty) {
          await StorageHelper.setDeviceToken(token);
        }

        // Update state
        _isAuthenticated = true;
        _userId = userData.id;
        _userName = userData.name;
        _userType = userData.catId;

        _setLoading(false);
        notifyListeners();

        return Right(userData);
      } else {
        final errorMsg = loginResponse.errorMessage;
        developer.log('Login error message: $errorMsg');
        _setError(errorMsg);
        _setLoading(false);
        return Left(ServerFailure(
          message: errorMsg,
          exception: ServerException(message: errorMsg),
        ));
      }
    } on DioException catch (e) {
      final errorMsg = _getErrorMessage(e);
      _setError(errorMsg);
      _setLoading(false);
      return Left(NetworkFailure(
        message: errorMsg,
        exception: NetworkException(
          message: errorMsg,
          originalError: e,
        ),
      ));
    } catch (e) {
      developer.log('Login error: $e');
      final errorMsg = 'An unexpected error occurred. Please try again.';
      _setError(errorMsg);
      _setLoading(false);
      return Left(ServerFailure(
        message: errorMsg,
        exception: ServerException(
          message: errorMsg,
          originalError: e,
        ),
      ));
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Call logout API (optional - may fail if token is invalid)
      try {
        await _dio.post(ApiEndpoints.logout);
      } catch (e) {
        // Ignore logout API errors - we'll clear local data anyway
        debugPrint('Logout API call failed: $e');
      }

      // Clear local storage
      await StorageHelper.clearAll();

      // Reset state
      _isAuthenticated = false;
      _userId = 0;
      _userName = '';
      _userType = 0;
      _errorMessage = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      // Even if logout fails, clear local data
      await StorageHelper.clearAll();
      _isAuthenticated = false;
      _userId = 0;
      _userName = '';
      _userType = 0;
      notifyListeners();
    }
  }

  /// Check if user is logged in
  Future<bool> checkIsLoggedIn() async {
    final isLoggedIn = await StorageHelper.getIsUserLogin();
    return isLoggedIn == '1';
  }

  /// Get current user info from storage
  Future<Map<String, dynamic>> getCurrentUserInfo() async {
    return {
      'userId': await StorageHelper.getUserId(),
      'userName': await StorageHelper.getUser(),
      'userType': await StorageHelper.getUserType(),
      'isLoggedIn': await checkIsLoggedIn(),
    };
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    developer.log('Set error message: $message');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getErrorMessage(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      if (data is Map<String, dynamic>) {
        final message = data['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      switch (statusCode) {
        case 401:
          return 'Invalid credentials. Please check your username and password.';
        case 403:
          return 'Access denied. Please contact administrator.';
        case 404:
          return 'Server not found. Please check your connection.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Network error occurred. Please try again.';
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    } else {
      return 'Network error occurred. Please try again.';
    }
  }
}

