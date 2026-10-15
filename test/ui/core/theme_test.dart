import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/core/theme.dart';

void main() {
  test('o tema claro usa o magenta do logo como cor principal', () {
    final scheme = buildLightTheme().colorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, AppColors.magenta);
  });

  test('o tema escuro usa o rosa do logo com texto preto', () {
    final scheme = buildDarkTheme().colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, AppColors.pink);
    expect(scheme.onPrimary, Colors.black);
  });
}
