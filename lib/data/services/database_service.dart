import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService({required this._factory, required this.path});

  static const schemaVersion = 1;
  static const fileName = 'flashcards.db';

  final DatabaseFactory _factory;
  final String path;
  Database? _db;

  Database get db {
    final db = _db;
    if (db == null) {
      throw StateError('O banco de dados não está aberto.');
    }
    return db;
  }

  Future<void> open() async {
    if (_db != null) return;
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: path != inMemoryDatabasePath,
        // SQLite ignores ON DELETE CASCADE unless this is on for every connection.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}

Future<void> _createSchema(Database db, int version) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE decks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        created_at  INTEGER NOT NULL
      )''')
    ..execute('''
      CREATE TABLE cards (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id       INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front_text    TEXT,
        front_image   TEXT,
        front_audio   TEXT,
        back_text     TEXT,
        back_image    TEXT,
        back_audio    TEXT,
        review_count  INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL
      )''')
    ..execute('CREATE INDEX idx_cards_deck ON cards(deck_id)')
    ..execute('''
      CREATE TABLE settings (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      )''');
  await batch.commit(noResult: true);
}
