import 'app_exception.dart';

/// Validation Exception
/// Thrown when validation errors occur (invalid input, missing required fields, etc.)
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

