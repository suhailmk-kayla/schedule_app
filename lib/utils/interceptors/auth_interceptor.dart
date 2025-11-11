import 'package:dio/dio.dart';
import '../storage_helper.dart';

/// Auth Interceptor
/// Automatically adds Bearer token to all API requests
/// Converted from KMP's ApiManager.getHeader() method
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for login/register endpoints
    if (_shouldSkipAuth(options.path)) {
      return handler.next(options);
    }

    // Get token from secure storage
    final token = await StorageHelper.getUserToken();

    // Add Bearer token to Authorization header if token exists
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  /// Check if endpoint should skip authentication
  bool _shouldSkipAuth(String path) {
    final skipPaths = [
      'api/login',
      'api/register',
    ];

    return skipPaths.any((skipPath) => path.contains(skipPath));
  }
}

