import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';
import 'package:my_flashcards/app_dependencies.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';

import 'fakes/fake_card_repository.dart';
import 'fakes/fake_deck_repository.dart';
import 'fakes/fake_media_repository.dart';
import 'fakes/fake_reminder_repository.dart';

void main() {
  AppDependencies dependencies({
    List<Deck> decks = const [],
    List<Flashcard> cards = const [],
  }) => AppDependencies(
    decks: FakeDeckRepository(decks),
    cards: FakeCardRepository(cards),
    media: FakeMediaRepository(),
    reminders: FakeReminderRepository(),
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

  testWidgets('deck › revisar › virar › concluir › voltar mostra o contador', (
    tester,
  ) async {
    await tester.pumpWidget(
      App(
        dependencies: dependencies(
          decks: [Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026))],
          cards: [
            Flashcard(
              id: 5,
              deckId: 1,
              front: const CardSide(text: 'to give up'),
              back: const CardSide(text: 'desistir'),
              createdAt: DateTime(2026),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar (1)'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(FlipCard), const Offset(200, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('desistir'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar ao deck'));
    await tester.pumpAndSettle();

    expect(find.text('to give up'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('⚙ abre as configurações', (tester) async {
    await tester.pumpWidget(App(dependencies: dependencies()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();

    expect(find.text('Lembrete diário'), findsOneWidget);
  });
}
