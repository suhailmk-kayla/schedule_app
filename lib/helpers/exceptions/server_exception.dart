import 'app_exception.dart';

/// Server Exception
/// Thrown when server-related errors occur (5xx errors, unexpected server responses, etc.)
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.originalError,
  });
}

