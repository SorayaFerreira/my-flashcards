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

  /// Writes a consistent copy of the open database to [destinationPath],
  /// including changes still in the write-ahead log.
  Future<void> copyTo(String destinationPath) {
    final quoted = destinationPath.replaceAll("'", "''");
    return db.execute("VACUUM INTO '$quoted'");
  }

  /// Throws unless the file at [path] is a database with this app's tables
  /// and a schema version this app understands.
  Future<void> checkReadable(String path) async {
    final other = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      await other.rawQuery('SELECT COUNT(*) FROM decks');
      await other.rawQuery('SELECT COUNT(*) FROM cards');
      await other.rawQuery('SELECT COUNT(*) FROM settings');
      final version = Sqflite.firstIntValue(
        await other.rawQuery('PRAGMA user_version'),
      );
      if (version == null || version < 1 || version > schemaVersion) {
        throw FormatException('Versão de schema não suportada: $version.');
      }
    } finally {
      await other.close();
    }
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
