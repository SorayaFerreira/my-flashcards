import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/card_editor/view_models/card_editor_view_model.dart';

import '../../fakes/fake_card_repository.dart';

void main() {
  late FakeCardRepository cards;

  final existing = Flashcard(
    id: 7,
    deckId: 1,
    front: const CardSide(text: 'to give up'),
    back: const CardSide(text: 'desistir'),
    createdAt: DateTime(2026),
    reviewCount: 4,
  );

  setUp(() => cards = FakeCardRepository([existing]));

  CardEditorViewModel newCard() =>
      CardEditorViewModel(deckId: 1, cardRepository: cards);

  CardEditorViewModel editCard() =>
      CardEditorViewModel(deckId: 1, cardId: 7, cardRepository: cards);

  group('card novo', () {
    test('começa vazio, sem alterações e sem poder salvar', () async {
      final viewModel = newCard();
      await viewModel.load();

      expect(viewModel.isNew, isTrue);
      expect(viewModel.draft(Side.front).isEmpty, isTrue);
      expect(viewModel.hasChanges, isFalse);
      expect(viewModel.canSave, isFalse);
    });

    test('só pode salvar com os dois lados preenchidos', () {
      final viewModel = newCard()..setText(Side.front, 'to give up');
      expect(viewModel.canSave, isFalse);

      viewModel.setText(Side.back, 'desistir');
      expect(viewModel.canSave, isTrue);
    });

    test('texto só com espaços não conta', () {
      final viewModel = newCard()
        ..setText(Side.front, 'to give up')
        ..setText(Side.back, '  \n ');

      expect(viewModel.canSave, isFalse);
    });

    test('save cria o card com o texto aparado', () async {
      final viewModel = newCard()
        ..setText(Side.front, ' to look forward to ')
        ..setText(Side.back, 'aguardar ansiosamente');

      expect(await viewModel.save(), isTrue);

      final created = cards.cards.last;
      expect(created.deckId, 1);
      expect(created.front.text, 'to look forward to');
      expect(viewModel.hasChanges, isFalse);
    });

    test('falha ao salvar mantém o rascunho e guarda a mensagem', () async {
      final viewModel = newCard()
        ..setText(Side.front, 'a')
        ..setText(Side.back, 'b');
      cards.failWith = Exception('disco');

      expect(await viewModel.save(), isFalse);

      expect(viewModel.actionError, CardEditorViewModel.saveErrorMessage);
      expect(viewModel.draft(Side.front).text, 'a');
      expect(viewModel.hasChanges, isTrue);
      expect(viewModel.isSaving, isFalse);
    });
  });

  group('editar card', () {
    test('load preenche os rascunhos com o card', () async {
      final viewModel = editCard();
      await viewModel.load();

      expect(viewModel.isNew, isFalse);
      expect(viewModel.draft(Side.front).text, 'to give up');
      expect(viewModel.draft(Side.back).text, 'desistir');
      expect(viewModel.hasChanges, isFalse);
      expect(viewModel.canSave, isTrue);
    });

    test('mudar e voltar o texto não conta como alteração', () async {
      final viewModel = editCard();
      await viewModel.load();

      viewModel.setText(Side.back, 'desistir!');
      expect(viewModel.hasChanges, isTrue);
      viewModel.setText(Side.back, 'desistir');
      expect(viewModel.hasChanges, isFalse);
    });

    test('save atualiza o card existente', () async {
      final viewModel = editCard();
      await viewModel.load();
      viewModel.setText(Side.back, 'largar, desistir');

      expect(await viewModel.save(), isTrue);

      expect(cards.cards.single.back.text, 'largar, desistir');
      expect(cards.cards.single.reviewCount, 4);
    });

    test('deleteCard apaga o card', () async {
      final viewModel = editCard();
      await viewModel.load();

      expect(await viewModel.deleteCard(), isTrue);
      expect(cards.cards, isEmpty);
    });

    test('card inexistente mostra erro de carregamento', () async {
      final viewModel = CardEditorViewModel(
        deckId: 1,
        cardId: 99,
        cardRepository: cards,
      );

      await viewModel.load();

      expect(viewModel.loadError, CardEditorViewModel.loadErrorMessage);
      expect(viewModel.canSave, isFalse);
    });
  });
}
