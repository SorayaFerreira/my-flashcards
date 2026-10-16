import 'package:my_flashcards/data/repositories/card_repository.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/utils/result.dart';

/// In-memory [CardRepository]. Set [failWith] to make every call fail.
class FakeCardRepository implements CardRepository {
  FakeCardRepository([List<Flashcard> cards = const []]) : _cards = [...cards];

  final List<Flashcard> _cards;
  Exception? failWith;
  var _nextId = 1000;

  List<Flashcard> get cards => List.unmodifiable(_cards);

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    try {
      return Result.ok(compute());
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  int _indexOf(int id) {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index < 0) throw NotFoundException('O card $id não existe.');
    return index;
  }

  @override
  Future<Result<List<Flashcard>>> getCards(int deckId) => _answer(
    () =>
        _cards.where((c) => c.deckId == deckId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<Result<Flashcard>> getCard(int id) async {
    if (failWith != null) return Result.error(failWith!);
    final index = _cards.indexWhere((c) => c.id == id);
    if (index < 0) return Result.error(NotFoundException('card $id'));
    return Result.ok(_cards[index]);
  }

  @override
  Future<Result<Flashcard>> createCard({
    required int deckId,
    required CardSide front,
    required CardSide back,
  }) => _answer(() {
    final card = Flashcard(
      id: _nextId++,
      deckId: deckId,
      front: front,
      back: back,
      createdAt: DateTime(2026, 10, 12).add(Duration(minutes: _nextId)),
    );
    _cards.add(card);
    return card;
  });

  @override
  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) => _answer(() {
    final index = _indexOf(id);
    final old = _cards[index];
    _cards[index] = Flashcard(
      id: id,
      deckId: old.deckId,
      front: front,
      back: back,
      createdAt: old.createdAt,
      reviewCount: old.reviewCount,
    );
  });

  @override
  Future<Result<void>> deleteCard(int id) =>
      _answer(() => _cards.removeWhere((c) => c.id == id));

  @override
  Future<Result<int>> incrementReviewCount(int id) => _answer(() {
    final index = _indexOf(id);
    final updated = _cards[index].copyWith(
      reviewCount: _cards[index].reviewCount + 1,
    );
    _cards[index] = updated;
    return updated.reviewCount;
  });
}
