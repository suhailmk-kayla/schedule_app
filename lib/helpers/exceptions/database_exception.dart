import 'app_exception.dart';

/// Database Exception
/// Thrown when database-related errors occur (SQL errors, constraint violations, etc.)
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

