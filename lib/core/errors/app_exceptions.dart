/// Base exception for all app errors
sealed class AppException implements Exception {
  final String message;
  final Object? originalError;
  
  const AppException({
    required this.message,
    this.originalError,
  });
  
  @override
  String toString() => message;
}

/// Network-related errors
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.originalError,
  });
}

/// Authentication errors
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.originalError,
  });
}

/// Database/repository errors
class RepositoryException extends AppException {
  const RepositoryException({
    required super.message,
    super.originalError,
  });
}

/// Validation errors
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.originalError,
  });
}

/// Unknown/unexpected errors
class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.originalError,
  });
}
