import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/ui/deck_list/view_models/deck_list_view_model.dart';

import '../../fakes/fake_deck_repository.dart';

void main() {
  late FakeDeckRepository repository;
  late DeckListViewModel viewModel;

  setUp(() {
    repository = FakeDeckRepository([
      Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026), cardCount: 3),
    ]);
    viewModel = DeckListViewModel(deckRepository: repository);
  });

  test('load traz os decks e termina sem erro', () async {
    await viewModel.load();

    expect(viewModel.decks.map((d) => d.name), ['Verbos']);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.loadError, isNull);
  });

  test('load avisa os ouvintes ao começar e ao terminar', () async {
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.load();

    expect(notifications, 2);
  });

  test('load com falha guarda a mensagem de erro', () async {
    repository.failWith = Exception('disco cheio');

    await viewModel.load();

    expect(viewModel.loadError, DeckListViewModel.loadErrorMessage);
    expect(viewModel.isLoading, isFalse);
  });

  test('load depois de uma falha limpa o erro', () async {
    repository.failWith = Exception('disco cheio');
    await viewModel.load();
    repository.failWith = null;

    await viewModel.load();

    expect(viewModel.loadError, isNull);
    expect(viewModel.decks, hasLength(1));
  });

  test('createDeck cria e recarrega a lista', () async {
    final ok = await viewModel.createDeck('Adjetivos');

    expect(ok, isTrue);
    expect(viewModel.decks.map((d) => d.name), ['Adjetivos', 'Verbos']);
  });

  test('createDeck com falha devolve false e guarda a mensagem', () async {
    repository.failWith = Exception('disco cheio');

    final ok = await viewModel.createDeck('Adjetivos');

    expect(ok, isFalse);
    expect(viewModel.actionError, DeckListViewModel.createErrorMessage);
  });

  test('renameDeck renomeia e recarrega', () async {
    await viewModel.load();

    expect(await viewModel.renameDeck(1, 'Verbos irregulares'), isTrue);
    expect(viewModel.decks.single.name, 'Verbos irregulares');
  });

  test('deleteDeck exclui e recarrega', () async {
    await viewModel.load();

    expect(await viewModel.deleteDeck(1), isTrue);
    expect(viewModel.decks, isEmpty);
  });

  test('deleteDeck com falha guarda a mensagem', () async {
    repository.failWith = Exception('disco cheio');

    expect(await viewModel.deleteDeck(1), isFalse);
    expect(viewModel.actionError, DeckListViewModel.deleteErrorMessage);
  });
}
