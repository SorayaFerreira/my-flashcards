import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/deck_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late DeckRepository repository;
  final now = DateTime(2026, 10, 12, 9, 30);

  setUp(() async {
    database = await openTestDatabase();
    repository = DeckRepository(database: database, now: () => now);
  });
  tearDown(() => database.close());

  Future<void> insertCard(int deckId) => database.db.insert('cards', {
    'deck_id': deckId,
    'front_text': 'frente',
    'back_text': 'verso',
    'created_at': 0,
  });

  test('cria um deck com o nome aparado e a data de criação', () async {
    final deck = okValue(await repository.createDeck('  Inglês  '));

    expect(deck.name, 'Inglês');
    expect(deck.createdAt, now);
    expect(okValue(await repository.getDecks()), [deck]);
  });

  test('o deck criado é igual ao lido, mesmo com microssegundos', () async {
    repository = DeckRepository(
      database: database,
      now: () => DateTime(2026, 10, 12, 9, 30, 0, 0, 123),
    );

    final deck = okValue(await repository.createDeck('Inglês'));

    expect(okValue(await repository.getDecks()), [deck]);
  });

  test('lista em ordem alfabética sem diferenciar maiúsculas', () async {
    await repository.createDeck('banana');
    await repository.createDeck('Cereja');
    await repository.createDeck('Abacate');

    final names = okValue(await repository.getDecks()).map((d) => d.name);

    expect(names, ['Abacate', 'banana', 'Cereja']);
  });

  test('lista sem diferenciar maiúsculas nem acentos', () async {
    for (final name in [
      'Zebra',
      'Água',
      'abacate',
      'Época',
      'Ônibus',
      'época',
    ]) {
      await repository.createDeck(name);
    }

    final names = okValue(await repository.getDecks()).map((d) => d.name);

    expect(names, ['abacate', 'Água', 'Época', 'época', 'Ônibus', 'Zebra']);
  });

  test('conta os cards de cada deck', () async {
    final withCards = okValue(await repository.createDeck('Com cards'));
    await repository.createDeck('Vazio');
    await insertCard(withCards.id);
    await insertCard(withCards.id);

    final decks = okValue(await repository.getDecks());

    expect(decks.map((d) => (d.name, d.cardCount)), [
      ('Com cards', 2),
      ('Vazio', 0),
    ]);
  });

  test('getDeck devolve o deck com a contagem de cards', () async {
    final created = okValue(await repository.createDeck('Inglês'));
    await insertCard(created.id);

    final deck = okValue(await repository.getDeck(created.id));

    expect(deck.cardCount, 1);
  });

  test('getDeck devolve NotFoundException para um id inexistente', () async {
    final result = await repository.getDeck(999);

    expect(
      result,
      isA<Error<dynamic>>().having(
        (r) => r.error,
        'error',
        isA<NotFoundException>(),
      ),
    );
  });

  test('renomeia com o nome aparado', () async {
    final deck = okValue(await repository.createDeck('Inglês'));

    okValue(await repository.renameDeck(deck.id, '  Verbos  '));

    expect(okValue(await repository.getDeck(deck.id)).name, 'Verbos');
  });

  test('renomear um deck inexistente devolve erro', () async {
    expect(await repository.renameDeck(999, 'X'), isA<Error<void>>());
  });

  test('excluir o deck apaga também os cards dele', () async {
    final deck = okValue(await repository.createDeck('Inglês'));
    await insertCard(deck.id);

    okValue(await repository.deleteDeck(deck.id));

    expect(okValue(await repository.getDecks()), isEmpty);
    expect(await database.db.query('cards'), isEmpty);
  });
}
