import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app_version.dart';

void main() {
  test('appVersion é a mesma do pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(appVersion, version);
  });
}
