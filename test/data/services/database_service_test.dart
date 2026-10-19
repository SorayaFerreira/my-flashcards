import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/database_service.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    final deckId = await database.db.insert('decks', {
      'name': 'Inglês',
      'created_at': 0,
    });
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
    final deckId = await database.db.insert('decks', {
      'name': 'Inglês',
      'created_at': 0,
    });
    await database.db.insert('cards', {
      'deck_id': deckId,
      'front_text': 'a',
      'back_text': 'b',
      'created_at': 0,
    });

    final card = (await database.db.query('cards')).single;
    expect(card['review_count'], 0);
  });

  test('db lança StateError depois de fechar', () async {
    await database.close();

    expect(() => database.db, throwsStateError);
  });

  test('copyTo grava uma cópia que checkReadable aceita', () async {
    final dir = await Directory.systemTemp.createTemp('db_copy_test_');
    addTearDown(() => dir.delete(recursive: true));
    await database.db.insert('decks', {'name': "D'água", 'created_at': 0});
    final copy = p.join(dir.path, "cópia d'água.db");

    await database.copyTo(copy);

    await database.checkReadable(copy);
    expect(await File(copy).length(), greaterThan(0));
  });

  test('checkReadable recusa um arquivo que não é banco', () async {
    final dir = await Directory.systemTemp.createTemp('db_check_test_');
    addTearDown(() => dir.delete(recursive: true));
    final fake = File(p.join(dir.path, 'falso.db'));
    await fake.writeAsString('não sou um banco de dados');

    expect(database.checkReadable(fake.path), throwsA(isA<Exception>()));
  });

  group('checkReadable com user_version', () {
    Future<String> copyWithVersion(int version) async {
      final dir = await Directory.systemTemp.createTemp('db_version_test_');
      addTearDown(() => dir.delete(recursive: true));
      final copy = p.join(dir.path, 'v$version.db');
      await database.copyTo(copy);
      final other = await databaseFactoryFfi.openDatabase(copy);
      await other.execute('PRAGMA user_version = $version');
      await other.close();
      return copy;
    }

    test('recusa user_version 0', () async {
      final path = await copyWithVersion(0);

      expect(database.checkReadable(path), throwsFormatException);
    });

    test('recusa user_version maior que o schema atual', () async {
      final path = await copyWithVersion(99);

      expect(database.checkReadable(path), throwsFormatException);
    });

    test('recusa um banco sem a tabela settings', () async {
      final dir = await Directory.systemTemp.createTemp('db_nosettings_');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'x.db');
      final other = await databaseFactoryFfi.openDatabase(path);
      await other.execute('CREATE TABLE decks (id INTEGER)');
      await other.execute('CREATE TABLE cards (id INTEGER)');
      await other.execute('PRAGMA user_version = 1');
      await other.close();

      expect(database.checkReadable(path), throwsA(isA<Exception>()));
    });
  });
}
