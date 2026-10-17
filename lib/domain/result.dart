/// Outcome of a repository call: either a value or a user-friendly message.
///
/// Repositories never throw to the UI; they return a [Result] so that raw
/// exceptions and stack traces can never reach the screen.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(String message) = Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.message);
  final String message;
}
