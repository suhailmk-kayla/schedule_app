import 'app_exception.dart';

/// Network Exception
/// Thrown when network-related errors occur (connection failures, timeouts, etc.)
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

