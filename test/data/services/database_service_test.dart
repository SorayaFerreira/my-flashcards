import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() => database.close());

  test('cria as tabelas decks, cards e settings', () async {
    final rows = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(
      rows.map((row) => row['name']),
      containsAll(['decks', 'cards', 'settings']),
    );
  });

  test('grava a versão do schema', () async {
    final rows = await database.db.rawQuery('PRAGMA user_version');

    expect(rows.single.values.single, DatabaseService.schemaVersion);
  });

  test('apagar um deck apaga os cards dele', () async {
    final deckId = await database.db.insert(
      'decks',
      {'name': 'Inglês', 'created_at': 0},
    );
    await database.db.insert('cards', {
      'deck_id': deckId,
      'front_text': 'to give up',
      'back_text': 'desistir',
      'created_at': 0,
    });

    await database.db.delete('decks', where: 'id = ?', whereArgs: [deckId]);

    expect(await database.db.query('cards'), isEmpty);
  });

  test('o contador de revisões começa em zero', () async {
    final deckId = await database.db.insert(
      'decks',
      {'name': 'Inglês', 'created_at': 0},
    );
    await database.db.insert(
      'cards',
      {'deck_id': deckId, 'front_text': 'a', 'back_text': 'b', 'created_at': 0},
    );

    final card = (await database.db.query('cards')).single;
    expect(card['review_count'], 0);
  });

  test('db lança StateError depois de fechar', () async {
    await database.close();

    expect(() => database.db, throwsStateError);
  });
}
