import 'package:my_flashcards/data/repositories/deck_repository.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/utils/result.dart';

/// In-memory [DeckRepository]. Set [failWith] to make every call fail.
class FakeDeckRepository implements DeckRepository {
  FakeDeckRepository([List<Deck> decks = const []]) : _decks = [...decks];

  final List<Deck> _decks;
  Exception? failWith;
  var _nextId = 1000;

  List<Deck> get decks => List.unmodifiable(_decks);

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    return Result.ok(compute());
  }

  @override
  Future<Result<List<Deck>>> getDecks() =>
      _answer(() => [..._decks]..sort(Deck.compareByName));

  @override
  Future<Result<Deck>> getDeck(int id) async {
    if (failWith != null) return Result.error(failWith!);
    for (final deck in _decks) {
      if (deck.id == id) return Result.ok(deck);
    }
    return Result.error(NotFoundException('O deck $id não existe.'));
  }

  @override
  Future<Result<Deck>> createDeck(String name) => _answer(() {
    final deck = Deck(
      id: _nextId++,
      name: name.trim(),
      createdAt: DateTime(2026, 10, 12),
    );
    _decks.add(deck);
    return deck;
  });

  @override
  Future<Result<void>> renameDeck(int id, String name) async {
    if (failWith != null) return Result.error(failWith!);
    final index = _decks.indexWhere((d) => d.id == id);
    if (index == -1) {
      return Result.error(NotFoundException('O deck $id não existe.'));
    }
    final old = _decks[index];
    _decks[index] = Deck(
      id: id,
      name: name.trim(),
      createdAt: old.createdAt,
      cardCount: old.cardCount,
    );
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> deleteDeck(int id) =>
      _answer(() => _decks.removeWhere((d) => d.id == id));
}
