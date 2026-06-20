sealed class Result<T> {
  const Result();

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String message, String? code) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Failure<T>(:final message, :final code) => onFailure(message, code),
    };
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        _ => null,
      };

  String? get messageOrNull => switch (this) {
        Failure<T>(:final message) => message,
        _ => null,
      };
}

class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

class Failure<T> extends Result<T> {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.message == message && other.code == code;

  @override
  int get hashCode => Object.hash(message, code);

  @override
  String toString() => 'Failure($message${code != null ? ', $code' : ''})';
}
