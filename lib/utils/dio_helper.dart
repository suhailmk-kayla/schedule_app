import 'package:dio/dio.dart';
import 'config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Dio Helper
/// Centralized Dio instance management with interceptors
/// Provides a singleton Dio instance configured with all interceptors
class DioHelper {
  static Dio? _instance;

  /// Get the singleton Dio instance
  /// Creates and configures the instance on first access
  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// Create and configure Dio instance with interceptors
  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors in order (order matters):
    // 1. AuthInterceptor - adds Bearer token to requests
    dio.interceptors.add(AuthInterceptor());

    // 2. LoggingInterceptor - logs requests/responses (disabled in production)
    dio.interceptors.add(
      LoggingInterceptor(enabled: !ApiConfig.isProductionMode),
    );

    // 3. RetryInterceptor - retries failed requests with exponential backoff
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 1),
      ),
    );

    return dio;
  }

  /// Reset the Dio instance (useful for testing or reconfiguration)
  static void reset() {
    _instance = null;
  }

  /// Reinitialize the Dio instance (useful after configuration changes)
  static void reinitialize() {
    _instance = _createDio();
  }
}

