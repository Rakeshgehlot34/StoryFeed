/// A generic Result type representing either a [Success] or a [Failure].
sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>() => null,
  };

  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Failure<T, E>(:final error) => error,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(E error, StackTrace? stackTrace) failure,
  }) {
    return switch (this) {
      Success<T, E>(:final value) => success(value),
      Failure<T, E>(:final error, :final stackTrace) => failure(
        error,
        stackTrace,
      ),
    };
  }

  Result<R, E> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T, E>(:final value) => Success(transform(value)),
      Failure<T, E>(:final error, :final stackTrace) => Failure(
        error,
        stackTrace,
      ),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Result.success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  final StackTrace? stackTrace;
  const Failure(this.error, [this.stackTrace]);

  @override
  String toString() => 'Result.failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode ^ stackTrace.hashCode;
}
