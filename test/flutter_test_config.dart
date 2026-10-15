import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs before every test file. Silences [debugPrint], so expected failures
/// logged by `guard` don't flood the test output.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugPrint = (String? message, {int? wrapWidth}) {};
  await testMain();
}
