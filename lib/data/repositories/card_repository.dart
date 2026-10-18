import 'package:flutter/foundation.dart';

import '../../domain/models/card_side.dart';
import '../../domain/models/flashcard.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';
import '../services/media_file_service.dart';

class CardRepository {
  CardRepository({
    required this._database,
    required this._mediaFiles,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final DateTime Function() _now;

  Future<Result<List<Flashcard>>> getCards(int deckId) => guard(() async {
    final rows = await _database.db.query(
      'cards',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_cardFromRow).toList();
  });

  Future<Result<Flashcard>> getCard(int id) =>
      guard(() async => _cardFromRow(await _findRow(id)));

  Future<Result<Flashcard>> createCard({
    required int deckId,
    required CardSide front,
    required CardSide back,
  }) => guard(() async {
    final id = await _database.db.insert('cards', {
      'deck_id': deckId,
      ..._sideToRow('front', front),
      ..._sideToRow('back', back),
      'created_at': _now().millisecondsSinceEpoch,
    });
    return _cardFromRow(await _findRow(id));
  });

  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) => guard(() async {
    final old = _cardFromRow(await _findRow(id));
    await _database.db.update(
      'cards',
      {..._sideToRow('front', front), ..._sideToRow('back', back)},
      where: 'id = ?',
      whereArgs: [id],
    );
    final kept = {...front.fileNames, ...back.fileNames};
    await _deleteFiles(old.fileNames.where((name) => !kept.contains(name)));
  });

  Future<Result<void>> deleteCard(int id) => guard(() async {
    final rows = await _database.db.query(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    await _database.db.delete('cards', where: 'id = ?', whereArgs: [id]);
    await _deleteFiles(_cardFromRow(rows.single).fileNames);
  });

  /// Adds one review to the card and returns its new count.
  Future<Result<int>> incrementReviewCount(int id) => guard(
    () => _database.db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        'UPDATE cards SET review_count = review_count + 1 WHERE id = ?',
        [id],
      );
      if (updated == 0) throw NotFoundException('O card $id não existe.');
      final rows = await txn.query(
        'cards',
        columns: ['review_count'],
        where: 'id = ?',
        whereArgs: [id],
      );
      return rows.single['review_count']! as int;
    }),
  );

  /// A file that can't be deleted only wastes space, so it never fails the
  /// operation that made it unused.
  Future<void> _deleteFiles(Iterable<String> names) async {
    try {
      await _mediaFiles.deleteMedia(names);
    } on Exception catch (error) {
      debugPrint('$error');
    }
  }

  Future<Map<String, Object?>> _findRow(int id) async {
    final rows = await _database.db.query(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw NotFoundException('O card $id não existe.');
    return rows.single;
  }
}

Map<String, Object?> _sideToRow(String prefix, CardSide side) => {
  '${prefix}_text': side.hasText ? side.text!.trim() : null,
  '${prefix}_image': side.image,
  '${prefix}_audio': side.audio,
};

CardSide _sideFromRow(String prefix, Map<String, Object?> row) => CardSide(
  text: row['${prefix}_text'] as String?,
  image: row['${prefix}_image'] as String?,
  audio: row['${prefix}_audio'] as String?,
);

Flashcard _cardFromRow(Map<String, Object?> row) => Flashcard(
  id: row['id']! as int,
  deckId: row['deck_id']! as int,
  front: _sideFromRow('front', row),
  back: _sideFromRow('back', row),
  reviewCount: row['review_count']! as int,
  createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
);
