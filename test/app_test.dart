import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';
import 'package:my_flashcards/app_dependencies.dart';
import 'package:my_flashcards/domain/models/deck.dart';

import 'fakes/fake_card_repository.dart';
import 'fakes/fake_deck_repository.dart';

void main() {
  AppDependencies dependencies({List<Deck> decks = const []}) =>
      AppDependencies(
        decks: FakeDeckRepository(decks),
        cards: FakeCardRepository(),
      );

  testWidgets('abre na lista de decks, seguindo o tema do sistema', (
    tester,
  ) async {
    await tester.pumpWidget(App(dependencies: dependencies()));
    await tester.pumpAndSettle();

    expect(find.text('My Flashcards'), findsOneWidget);
    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('deck › novo card › salvar volta para o deck com o card', (
    tester,
  ) async {
    await tester.pumpWidget(
      App(
        dependencies: dependencies(
          decks: [Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'to give up');
    await tester.enterText(find.byType(TextField).at(1), 'desistir');
    await tester.pump();
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('Verbos'), findsOneWidget);
    expect(find.text('to give up'), findsOneWidget);
  });
}
