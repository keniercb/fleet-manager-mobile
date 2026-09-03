/// Resultado funcional `Either<Failure, T>` (ADR-06).
///
/// Uso:
/// ```dart
/// final result = await loginUseCase(...);
/// result.when(
///   success: (user) => ...,
///   failure: (f) => showBanner(f.userMessage),
/// );
/// ```
import 'failures.dart';

sealed class Result<T> {
  const Result();

  static Result<T> success<T>(T value) => SuccessResult<T>(value);
  static Result<T> failure<T>(Failure failure) => FailureResult<T>(failure);

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  });

  /// Valor si es éxito, `null` en caso contrario.
  T? get valueOrNull => switch (this) {
        final SuccessResult<T> s => s.value,
        _ => null,
      };

  /// `Failure` si es fallo, `null` en caso contrario.
  Failure? get failureOrNull => switch (this) {
        final FailureResult<T> f => f.failure,
        _ => null,
      };
}

class SuccessResult<T> extends Result<T> {
  const SuccessResult(this.value);
  final T value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) =>
      success(value);
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) =>
      failure(this.failure);
}
