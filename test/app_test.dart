import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';
import 'package:my_flashcards/app_dependencies.dart';

import 'fakes/fake_deck_repository.dart';

void main() {
  testWidgets('abre na lista de decks, seguindo o tema do sistema',
      (tester) async {
    await tester.pumpWidget(
      App(dependencies: AppDependencies(decks: FakeDeckRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Flashcards'), findsOneWidget);
    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });
}
