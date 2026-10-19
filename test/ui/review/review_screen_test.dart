import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/review/view_models/review_view_model.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';
import 'package:my_flashcards/ui/review/widgets/review_screen.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_media_repository.dart';
import '../../helpers/temp_media.dart';

void main() {
  const hint = '⟵ arraste para virar ⟶';
  late FakeCardRepository cards;
  late FakeMediaRepository media;

  Flashcard card(int id, int reviewCount) => Flashcard(
    id: id,
    deckId: 1,
    front: CardSide(text: 'frente $id'),
    back: CardSide(text: 'verso $id'),
    createdAt: DateTime(2026, 1, id),
    reviewCount: reviewCount,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    List<Flashcard> deck, {
    String mediaRoot = '',
  }) async {
    cards = FakeCardRepository(deck);
    media = FakeMediaRepository()..root = mediaRoot;
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          deckName: 'Verbos',
          viewModel: ReviewViewModel(
            deckId: 1,
            cardRepository: cards,
            mediaRepository: media,
            random: Random(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flip(WidgetTester tester) async {
    await tester.fling(find.byType(FlipCard), const Offset(200, 0), 1500);
    await tester.pumpAndSettle();
  }

  String counter(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('review-count'))).data!;

  ButtonStyleButton button(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );

  testWidgets('mostra o deck, a posição, a frente, o contador e a dica', (
    tester,
  ) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3), card(3, 7)]);

    expect(find.text('Verbos'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text('frente 1'), findsOneWidget);
    expect(counter(tester), '0');
    expect(find.text(hint), findsOneWidget);
    expect(button(tester, '‹ Anterior').onPressed, isNull);
  });

  testWidgets('virar mostra o verso e soma uma revisão', (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);

    await flip(tester);

    expect(find.text('Verso'), findsOneWidget);
    expect(find.text('verso 1'), findsOneWidget);
    expect(counter(tester), '1');
    expect(find.text(hint), findsNothing);
  });

  testWidgets('desvirar e virar de novo não conta outra vez', (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);

    await flip(tester);
    await flip(tester);
    await flip(tester);

    expect(counter(tester), '1');
    expect(cards.cards.first.reviewCount, 1);
  });

  testWidgets('Próximo e Anterior trocam de card, sempre pela frente', (
    tester,
  ) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);
    await flip(tester);

    await tester.tap(find.text('Próximo ›'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('frente 2'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);

    await tester.tap(find.text('‹ Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('frente 1'), findsOneWidget);

    await flip(tester);
    expect(counter(tester), '1');
  });

  testWidgets('deck com um card já mostra Concluir', (tester) async {
    await pumpScreen(tester, [card(1, 0)]);

    expect(find.text('Concluir'), findsOneWidget);
    expect(button(tester, '‹ Anterior').onPressed, isNull);
  });

  testWidgets('Concluir mostra o resumo, e Revisar de novo recomeça', (
    tester,
  ) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);
    await flip(tester);
    await tester.tap(find.text('Próximo ›'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Revisão concluída!'), findsOneWidget);
    expect(find.text('Você revisou 1 de 2 cards.'), findsOneWidget);

    await tester.tap(find.text('Revisar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('falha ao salvar a revisão mostra uma mensagem', (tester) async {
    await pumpScreen(tester, [card(1, 0)]);
    cards.failWith = Exception('disco');

    await flip(tester);

    expect(find.text('Não foi possível salvar a revisão.'), findsOneWidget);
  });

  testWidgets('mostra a imagem do lado, ou o aviso se o arquivo sumiu', (
    tester,
  ) async {
    await pumpScreen(tester, [
      Flashcard(
        id: 1,
        deckId: 1,
        front: const CardSide(text: 'apple', image: 'img_1.jpg'),
        back: const CardSide(text: 'maçã'),
        createdAt: DateTime(2026),
      ),
    ]);

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('Imagem não encontrada'), findsOneWidget);
  });

  testWidgets('▶ toca o áudio e virar o card para o som', (tester) async {
    final root = createFakeMediaRoot(['media/aud_1.m4a']);
    await pumpScreen(tester, [
      Flashcard(
        id: 1,
        deckId: 1,
        front: const CardSide(text: 'apple', audio: 'aud_1.m4a'),
        back: const CardSide(text: 'maçã'),
        createdAt: DateTime(2026),
      ),
    ], mediaRoot: root);

    await tester.tap(find.byTooltip('Ouvir'));
    await tester.pumpAndSettle();
    expect(media.played, ['$root/media/aud_1.m4a']);
    expect(find.byTooltip('Parar'), findsOneWidget);

    await flip(tester);

    expect(media.playingPath.value, isNull);
  });

  testWidgets('Próximo logo após virar conta o card virado', (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);
    media.stopPlaybackGate = Completer();

    await tester.fling(find.byType(FlipCard), const Offset(200, 0), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Verso'), findsOneWidget);
    await tester.tap(find.text('Próximo ›'));
    await tester.pump();
    media.stopPlaybackGate!.complete();
    await tester.pumpAndSettle();

    expect(cards.cards.first.reviewCount, 1);
    expect(cards.cards.last.reviewCount, 3);
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
