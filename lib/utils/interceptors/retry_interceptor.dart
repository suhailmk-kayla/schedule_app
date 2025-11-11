import 'package:dio/dio.dart';

/// Retry Interceptor
/// Automatically retries failed requests on network errors or timeouts
class RetryInterceptor extends Interceptor {
  final Dio _dio; // Hold a reference to the original Dio instance
  final int maxRetries;
  final Duration retryDelay;
  final List<int> retryableStatusCodes;

  RetryInterceptor({
    required Dio dio, // Pass the original Dio instance
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
  }) : _dio = dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't retry if max retries reached
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    // Only retry on network errors, timeouts, or specific status codes
    final shouldRetry = _shouldRetry(err);

    if (!shouldRetry) {
      return handler.next(err);
    }

    // Don't retry on POST/PUT/DELETE for data integrity (unless explicitly configured)
    final method = err.requestOptions.method.toUpperCase();
    if (['POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) {
      // Only retry POST/PUT/DELETE if it's a network error (not a server error)
      if (err.type != DioExceptionType.connectionTimeout &&
          err.type != DioExceptionType.sendTimeout &&
          err.type != DioExceptionType.receiveTimeout &&
          err.type != DioExceptionType.connectionError) {
        return handler.next(err);
      }
    }

    // Calculate delay with exponential backoff
    final delay = Duration(
      milliseconds: retryDelay.inMilliseconds * (1 << retryCount),
    );

    await Future.delayed(delay);

    // Update retry count
    err.requestOptions.extra['retryCount'] = retryCount + 1;

    // Retry the request
    try {
      final response = await _retry(err.requestOptions);
      return handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        return handler.next(e);
      }
      return handler.next(err);
    }
  }

  /// Check if error should be retried
  bool _shouldRetry(DioException err) {
    // Retry on network errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on specific HTTP status codes
    if (err.response != null) {
      final statusCode = err.response!.statusCode;
      if (statusCode != null && retryableStatusCodes.contains(statusCode)) {
        return true;
      }
    }

    return false;
  }

  /// Retry the request using the original Dio instance
  Future<Response> _retry(RequestOptions requestOptions) async {
    // Use the stored Dio instance to re-execute the request
    return await _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
        contentType: requestOptions.contentType,
        responseType: requestOptions.responseType,
        followRedirects: requestOptions.followRedirects,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        extra: requestOptions.extra,
      ),
    );
  }
}

