import 'package:flutter/foundation.dart';

/// The outcome of an operation that can fail: [Ok] with a value, or [Error]
/// with the exception that caused the failure.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>._;

  const factory Result.error(Exception error) = Error<T>._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);

  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}

/// Runs [action] and wraps its outcome in a [Result].
///
/// Only exceptions become an [Error] result. Programming errors such as a
/// failed cast still propagate, so they get noticed during development.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } on Exception catch (error, stackTrace) {
    debugPrint('$error\n$stackTrace');
    return Result.error(error);
  }
}

class NotFoundException implements Exception {
  const NotFoundException(this.message);

  final String message;

  @override
  String toString() => 'NotFoundException: $message';
}
