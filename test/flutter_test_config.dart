import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs before every test file. Silences [debugPrint] in plain `test()` files,
/// where repositories run `guard` against real failures. Widget tests restore
/// the default `debugPrint` through their binding.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugPrint = (String? message, {int? wrapWidth}) {};
  await testMain();
}
