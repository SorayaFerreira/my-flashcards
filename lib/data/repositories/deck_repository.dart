import '../../domain/models/deck.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';

class DeckRepository {
  DeckRepository({required this._database, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DatabaseService _database;
  final DateTime Function() _now;

  static const _selectDecks = '''
    SELECT d.id, d.name, d.created_at, COUNT(c.id) AS card_count
    FROM decks d
    LEFT JOIN cards c ON c.deck_id = d.id''';

  Future<Result<List<Deck>>> getDecks() => guard(() async {
    final rows = await _database.db.rawQuery('$_selectDecks GROUP BY d.id');
    return rows.map(_deckFromRow).toList()..sort(Deck.compareByName);
  });

  Future<Result<Deck>> getDeck(int id) => guard(() async {
    final rows = await _database.db.rawQuery(
      '$_selectDecks WHERE d.id = ? GROUP BY d.id',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('O deck $id não existe.');
    return _deckFromRow(rows.single);
  });

  Future<Result<Deck>> createDeck(String name) => guard(() async {
    final trimmed = name.trim();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      _now().millisecondsSinceEpoch,
    );
    final id = await _database.db.insert('decks', {
      'name': trimmed,
      'created_at': createdAt.millisecondsSinceEpoch,
    });
    return Deck(id: id, name: trimmed, createdAt: createdAt);
  });

  Future<Result<void>> renameDeck(int id, String name) => guard(() async {
    final updated = await _database.db.update(
      'decks',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw NotFoundException('O deck $id não existe.');
  });

  Future<Result<void>> deleteDeck(int id) => guard(() async {
    await _database.db.delete('decks', where: 'id = ?', whereArgs: [id]);
  });
}

Deck _deckFromRow(Map<String, Object?> row) => Deck(
  id: row['id']! as int,
  name: row['name']! as String,
  createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
  cardCount: row['card_count']! as int,
);
