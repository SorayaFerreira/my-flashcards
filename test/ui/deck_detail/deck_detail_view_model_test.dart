import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/deck_detail/view_models/deck_detail_view_model.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_deck_repository.dart';

void main() {
  late FakeDeckRepository decks;
  late FakeCardRepository cards;
  late DeckDetailViewModel viewModel;

  setUp(() {
    decks = FakeDeckRepository([
      Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026), cardCount: 1),
    ]);
    cards = FakeCardRepository([
      Flashcard(
        id: 10,
        deckId: 1,
        front: const CardSide(text: 'to give up'),
        back: const CardSide(text: 'desistir'),
        createdAt: DateTime(2026),
      ),
    ]);
    viewModel = DeckDetailViewModel(
      deckId: 1,
      deckRepository: decks,
      cardRepository: cards,
    );
  });

  test('load traz o deck e os cards', () async {
    await viewModel.load();

    expect(viewModel.deck?.name, 'Verbos');
    expect(viewModel.cards.single.id, 10);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.loadError, isNull);
  });

  test('falha nos cards mostra a mensagem de erro', () async {
    cards.failWith = Exception('disco');

    await viewModel.load();

    expect(viewModel.loadError, DeckDetailViewModel.loadErrorMessage);
  });

  test('deck inexistente mostra a mensagem de erro', () async {
    final missing = DeckDetailViewModel(
      deckId: 99,
      deckRepository: decks,
      cardRepository: cards,
    );

    await missing.load();

    expect(missing.loadError, DeckDetailViewModel.loadErrorMessage);
  });
}
