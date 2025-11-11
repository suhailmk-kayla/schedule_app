import '../exceptions/network_exception.dart';
import '../exceptions/database_exception.dart';
import '../exceptions/validation_exception.dart';
import '../exceptions/server_exception.dart';

/// Base Failure Class
/// Used with Either pattern for error handling
abstract class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});
}

/// Network Failure
/// Wraps NetworkException for Either pattern
class NetworkFailure extends Failure {
  final NetworkException? exception;

  const NetworkFailure({
    required super.message,
    super.code,
    this.exception,
  });

  /// Create NetworkFailure from DioException
  factory NetworkFailure.fromDioError(dynamic error) {
    String message = 'Network error occurred';
    String? code;

    if (error is Exception) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('timeout')) {
        message = 'Connection timed out. Please check your internet connection.';
      } else if (errorString.contains('socket') || errorString.contains('connection')) {
        message = 'Network connection failed. Please check your internet connection.';
      } else if (errorString.contains('host')) {
        message = 'Unable to reach server. Please check your internet connection.';
      }
    }

    return NetworkFailure(
      message: message,
      code: code,
      exception: NetworkException(
        message: message,
        code: code,
        originalError: error,
      ),
    );
  }
}

/// Database Failure
/// Wraps DatabaseException for Either pattern
class DatabaseFailure extends Failure {
  final DatabaseException? exception;

  const DatabaseFailure({
    required super.message,
    super.code,
    this.exception,
  });

  /// Create DatabaseFailure from database error
  factory DatabaseFailure.fromError(dynamic error) {
    return DatabaseFailure(
      message: error.toString(),
      exception: DatabaseException(
        message: error.toString(),
        originalError: error,
      ),
    );
  }
}

/// Validation Failure
/// Wraps ValidationException for Either pattern
class ValidationFailure extends Failure {
  final ValidationException? exception;

  const ValidationFailure({
    required super.message,
    super.code,
    this.exception,
  });

  /// Create ValidationFailure from validation error
  factory ValidationFailure.fromError(String message, {String? code}) {
    return ValidationFailure(
      message: message,
      code: code,
      exception: ValidationException(
        message: message,
        code: code,
      ),
    );
  }
}

/// Server Failure
/// Wraps ServerException for Either pattern
class ServerFailure extends Failure {
  final ServerException? exception;

  const ServerFailure({
    required super.message,
    super.code,
    this.exception,
  });

  /// Create ServerFailure from server error
  factory ServerFailure.fromError(dynamic error) {
    return ServerFailure(
      message: 'An unexpected error occurred',
      exception: ServerException(
        message: error.toString(),
        originalError: error,
      ),
    );
  }
}

/// Unknown Failure
/// For unexpected errors that don't fit other categories
class UnknownFailure extends Failure {
  final dynamic originalError;

  const UnknownFailure({
    required super.message,
    super.code,
    this.originalError,
  });

  /// Create UnknownFailure from any error
  factory UnknownFailure.fromError(dynamic error) {
    return UnknownFailure(
      message: error.toString(),
      originalError: error,
    );
  }
}

