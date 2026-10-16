import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/domain/review_order.dart';

void main() {
  Flashcard card(int id, int reviewCount) => Flashcard(
    id: id,
    deckId: 1,
    front: const CardSide(text: 'f'),
    back: const CardSide(text: 'v'),
    createdAt: DateTime(2026),
    reviewCount: reviewCount,
  );

  test('os menos revisados vêm primeiro', () {
    final ordered = orderForReview([
      card(1, 3),
      card(2, 0),
      card(3, 1),
    ], Random(1));

    expect(ordered.map((c) => c.reviewCount), [0, 1, 3]);
  });

  test('cards empatados ficam juntos, antes dos mais revisados', () {
    final ordered = orderForReview([
      card(1, 1),
      card(2, 0),
      card(3, 1),
      card(4, 0),
      card(5, 0),
    ], Random(1));

    expect(ordered.map((c) => c.reviewCount), [0, 0, 0, 1, 1]);
    expect(ordered.map((c) => c.id).toSet(), {1, 2, 3, 4, 5});
  });

  test('a ordem dos empatados depende do sorteio', () {
    final cards = [for (var id = 1; id <= 10; id++) card(id, 0)];

    final a = orderForReview(cards, Random(1)).map((c) => c.id).toList();
    final b = orderForReview(cards, Random(2)).map((c) => c.id).toList();

    expect(a, isNot(b));
    expect(a.toSet(), b.toSet());
  });

  test('não altera a lista recebida', () {
    final cards = [card(1, 2), card(2, 0)];

    orderForReview(cards, Random(1));

    expect(cards.map((c) => c.id), [1, 2]);
  });

  test('deck vazio dá fila vazia', () {
    expect(orderForReview(const [], Random(1)), isEmpty);
  });
}
