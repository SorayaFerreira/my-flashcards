import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/card_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late CardRepository repository;
  late int deckId;
  late int otherDeckId;

  setUp(() async {
    database = await openTestDatabase();
    var clock = DateTime(2026, 10, 12, 9);
    repository = CardRepository(
      database: database,
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
    deckId = await database.db.insert('decks', {'name': 'A', 'created_at': 0});
    otherDeckId = await database.db.insert('decks', {
      'name': 'B',
      'created_at': 0,
    });
  });
  tearDown(() => database.close());

  test('cria um card com o texto aparado e o contador em zero', () async {
    final card = okValue(
      await repository.createCard(
        deckId: deckId,
        front: const CardSide(text: '  to give up  '),
        back: const CardSide(text: 'desistir\n'),
      ),
    );

    expect(card.front.text, 'to give up');
    expect(card.back.text, 'desistir');
    expect(card.reviewCount, 0);
    expect(okValue(await repository.getCard(card.id)), card);
  });

  test('texto só com espaços é gravado como nulo', () async {
    final card = okValue(
      await repository.createCard(
        deckId: deckId,
        front: const CardSide(text: '   ', image: 'img_1.jpg'),
        back: const CardSide(text: 'b'),
      ),
    );

    expect(card.front.text, isNull);
    expect(card.front.image, 'img_1.jpg');
  });

  test(
    'getCards traz só os cards do deck, os mais recentes primeiro',
    () async {
      final first = okValue(
        await repository.createCard(
          deckId: deckId,
          front: const CardSide(text: 'primeiro'),
          back: const CardSide(text: 'x'),
        ),
      );
      await repository.createCard(
        deckId: otherDeckId,
        front: const CardSide(text: 'de outro deck'),
        back: const CardSide(text: 'x'),
      );
      final second = okValue(
        await repository.createCard(
          deckId: deckId,
          front: const CardSide(text: 'segundo'),
          back: const CardSide(text: 'x'),
        ),
      );

      final cards = okValue(await repository.getCards(deckId));

      expect(cards.map((c) => c.id), [second.id, first.id]);
    },
  );

  test('getCard de um id inexistente devolve NotFoundException', () async {
    final result = await repository.getCard(999);

    expect(
      result,
      isA<Error<dynamic>>().having(
        (r) => r.error,
        'error',
        isA<NotFoundException>(),
      ),
    );
  });

  test('updateCard troca a frente e o verso e mantém o contador', () async {
    final card = okValue(
      await repository.createCard(
        deckId: deckId,
        front: const CardSide(text: 'a'),
        back: const CardSide(text: 'b'),
      ),
    );
    await database.db.update('cards', {'review_count': 3});

    okValue(
      await repository.updateCard(
        id: card.id,
        front: const CardSide(text: 'novo a'),
        back: const CardSide(text: 'novo b'),
      ),
    );

    final updated = okValue(await repository.getCard(card.id));
    expect(updated.front.text, 'novo a');
    expect(updated.back.text, 'novo b');
    expect(updated.reviewCount, 3);
  });

  test('updateCard de um id inexistente devolve erro', () async {
    final result = await repository.updateCard(
      id: 999,
      front: const CardSide(text: 'a'),
      back: const CardSide(text: 'b'),
    );

    expect(result, isA<Error<void>>());
  });

  test('deleteCard apaga o card', () async {
    final card = okValue(
      await repository.createCard(
        deckId: deckId,
        front: const CardSide(text: 'a'),
        back: const CardSide(text: 'b'),
      ),
    );

    okValue(await repository.deleteCard(card.id));

    expect(okValue(await repository.getCards(deckId)), isEmpty);
  });

  test('incrementReviewCount soma um e devolve o novo valor', () async {
    final card = okValue(
      await repository.createCard(
        deckId: deckId,
        front: const CardSide(text: 'a'),
        back: const CardSide(text: 'b'),
      ),
    );

    expect(okValue(await repository.incrementReviewCount(card.id)), 1);
    expect(okValue(await repository.incrementReviewCount(card.id)), 2);
    expect(okValue(await repository.getCard(card.id)).reviewCount, 2);
  });

  test('incrementReviewCount de um card inexistente devolve erro', () async {
    expect(await repository.incrementReviewCount(999), isA<Error<int>>());
  });
}
