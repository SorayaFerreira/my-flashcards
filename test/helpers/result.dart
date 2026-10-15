import 'package:my_flashcards/utils/result.dart';

/// Returns the value inside an [Ok], failing the test for an [Error].
T okValue<T>(Result<T> result) => switch (result) {
      Ok(:final value) => value,
      Error(:final error) => throw StateError('Esperava Ok, veio $error'),
    };
