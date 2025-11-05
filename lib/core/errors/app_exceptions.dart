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

