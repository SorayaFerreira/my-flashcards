import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/deck_detail/view_models/deck_detail_view_model.dart';
import 'package:my_flashcards/ui/deck_detail/widgets/deck_detail_screen.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_deck_repository.dart';

void main() {
  final deck = Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026));

  Flashcard card(int id, CardSide front, {int reviewCount = 0}) => Flashcard(
    id: id,
    deckId: 1,
    front: front,
    back: const CardSide(text: 'verso'),
    createdAt: DateTime(2026, 1, id),
    reviewCount: reviewCount,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCardRepository cards, {
    Future<void> Function(int? cardId)? onOpenEditor,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeckDetailScreen(
          viewModel: DeckDetailViewModel(
            deckId: 1,
            deckRepository: FakeDeckRepository([deck]),
            cardRepository: cards,
          ),
          onOpenEditor: onOpenEditor ?? (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o nome do deck e a mensagem de lista vazia', (
    tester,
  ) async {
    await pumpScreen(tester, FakeCardRepository());

    expect(find.text('Verbos'), findsOneWidget);
    expect(
      find.text('Nenhum card ainda. Toque em + para criar.'),
      findsOneWidget,
    );
  });

  testWidgets('lista os cards mais recentes primeiro, com o contador', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(text: 'antigo'), reviewCount: 7),
        card(2, const CardSide(text: 'novo'), reviewCount: 12),
      ]),
    );

    final antigo = tester.getTopLeft(find.text('antigo'));
    final novo = tester.getTopLeft(find.text('novo'));
    expect(novo.dy, lessThan(antigo.dy));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('mostra só a primeira linha da frente', (tester) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(text: 'primeira linha\nsegunda linha')),
      ]),
    );

    expect(find.text('primeira linha'), findsOneWidget);
    expect(find.textContaining('segunda linha'), findsNothing);
  });

  testWidgets('frente sem texto mostra (só imagem) ou (só áudio)', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(image: 'img_1.jpg')),
        card(2, const CardSide(audio: 'aud_1.m4a')),
      ]),
    );

    expect(find.text('(só imagem)'), findsOneWidget);
    expect(find.text('(só áudio)'), findsOneWidget);
  });

  testWidgets('tocar num card abre o editor dele', (tester) async {
    final opened = <int?>[];
    await pumpScreen(
      tester,
      FakeCardRepository([card(5, const CardSide(text: 'to give up'))]),
      onOpenEditor: (id) async => opened.add(id),
    );

    await tester.tap(find.text('to give up'));
    await tester.pumpAndSettle();

    expect(opened, [5]);
  });

  testWidgets('o + abre o editor de um card novo e recarrega ao voltar', (
    tester,
  ) async {
    final cards = FakeCardRepository();
    await pumpScreen(
      tester,
      cards,
      onOpenEditor: (id) async {
        expect(id, isNull);
        await cards.createCard(
          deckId: 1,
          front: const CardSide(text: 'criado no editor'),
          back: const CardSide(text: 'x'),
        );
      },
    );

    await tester.tap(find.byTooltip('Novo card'));
    await tester.pumpAndSettle();

    expect(find.text('criado no editor'), findsOneWidget);
  });

  testWidgets('falha ao carregar mostra erro e permite tentar de novo', (
    tester,
  ) async {
    final cards = FakeCardRepository()..failWith = Exception('disco');
    await pumpScreen(tester, cards);

    expect(find.text('Não foi possível carregar o deck.'), findsOneWidget);

    cards.failWith = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum card ainda. Toque em + para criar.'),
      findsOneWidget,
    );
  });
}
