import 'app_exceptions.dart';
/// Result type for handling success/failure without exceptions
sealed class AppResult<T> {
  const AppResult();
  
  factory AppResult.success(T data) => Success<T>(data);
  factory AppResult.failure(AppException error) => Failure<T>(error);
}

final class Success<T> extends AppResult<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends AppResult<T> {
  final AppException error;
  const Failure(this.error);
}

/// Extension methods for easy result handling
extension AppResultExtensions<T> on AppResult<T> {
  /// Returns data if successful, null otherwise
  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Failure() => null,
  };
  
  /// Returns error if failed, null otherwise
  AppException? get errorOrNull => switch (this) {
    Success() => null,
    Failure(:final error) => error,
  };
  
  /// Returns data if successful, default value otherwise
  T dataOr(T defaultValue) => switch (this) {
    Success(:final data) => data,
    Failure() => defaultValue,
  };
}

/// Extension for Future<AppResult<T>>
extension FutureAppResultExtensions<T> on Future<AppResult<T>> {
  /// Transforms the result using a mapper
  Future<AppResult<R>> map<R>(R Function(T) mapper) async {
    final result = await this;
    return switch (result) {
      Success(:final data) => AppResult.success(mapper(data)),
      Failure(:final error) => AppResult.failure(error),
    };
  }
}
