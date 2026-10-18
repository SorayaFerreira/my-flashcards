import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/ui/card_editor/view_models/card_editor_view_model.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_media_repository.dart';

void main() {
  late FakeCardRepository cards;
  late FakeMediaRepository media;

  final existing = Flashcard(
    id: 7,
    deckId: 1,
    front: const CardSide(text: 'to give up'),
    back: const CardSide(text: 'desistir'),
    createdAt: DateTime(2026),
    reviewCount: 4,
  );

  setUp(() {
    cards = FakeCardRepository([existing]);
    media = FakeMediaRepository();
  });

  CardEditorViewModel newCard() => CardEditorViewModel(
    deckId: 1,
    cardRepository: cards,
    mediaRepository: media,
  );

  CardEditorViewModel editCard({int cardId = 7}) => CardEditorViewModel(
    deckId: 1,
    cardId: cardId,
    cardRepository: cards,
    mediaRepository: media,
  );

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
      final viewModel = editCard(cardId: 99);

      await viewModel.load();

      expect(viewModel.loadError, CardEditorViewModel.loadErrorMessage);
      expect(viewModel.canSave, isFalse);
    });
  });

  group('imagens', () {
    test(
      'pickImage põe a imagem nova no lado, com o caminho de rascunho',
      () async {
        media.nextPick = 'img_1.jpg';
        final viewModel = newCard();

        expect(
          await viewModel.pickImage(Side.front, ImageOrigin.camera),
          isTrue,
        );

        expect(media.picks, [ImageOrigin.camera]);
        expect(viewModel.draft(Side.front).image?.name, 'img_1.jpg');
        expect(viewModel.imagePath(Side.front), '/drafts/img_1.jpg');
        expect(viewModel.hasChanges, isTrue);
      },
    );

    test('um lado só com imagem já conta como preenchido', () async {
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard()..setText(Side.back, 'desistir');

      await viewModel.pickImage(Side.front, ImageOrigin.gallery);

      expect(viewModel.canSave, isTrue);
    });

    test('cancelar a câmera não muda nada e não mostra erro', () async {
      final viewModel = newCard();

      expect(await viewModel.pickImage(Side.front, ImageOrigin.camera), isTrue);

      expect(viewModel.draft(Side.front).image, isNull);
      expect(viewModel.actionError, isNull);
      expect(viewModel.hasChanges, isFalse);
    });

    test('falha do seletor mostra a mensagem de imagem', () async {
      media.nextPick = Exception('câmera ocupada');
      final viewModel = newCard();

      expect(
        await viewModel.pickImage(Side.front, ImageOrigin.camera),
        isFalse,
      );
      expect(viewModel.actionError, CardEditorViewModel.imageErrorMessage);
    });

    test('trocar uma imagem nova apaga o rascunho anterior', () async {
      final viewModel = newCard();
      media.nextPick = 'img_1.jpg';
      await viewModel.pickImage(Side.front, ImageOrigin.camera);
      media.nextPick = 'img_2.jpg';

      await viewModel.pickImage(Side.front, ImageOrigin.camera);

      expect(media.discarded, ['img_1.jpg']);
      expect(viewModel.draft(Side.front).image?.name, 'img_2.jpg');
    });

    test(
      'remover uma imagem já salva não apaga o arquivo antes de salvar',
      () async {
        cards = FakeCardRepository([
          Flashcard(
            id: 7,
            deckId: 1,
            front: const CardSide(text: 'a', image: 'img_salva.jpg'),
            back: const CardSide(text: 'b'),
            createdAt: DateTime(2026),
          ),
        ]);
        final viewModel = editCard();
        await viewModel.load();
        expect(viewModel.imagePath(Side.front), '/media/img_salva.jpg');

        await viewModel.removeImage(Side.front);

        expect(media.discarded, isEmpty);
        expect(viewModel.hasChanges, isTrue);
        await viewModel.save();
        expect(cards.cards.single.front.image, isNull);
      },
    );

    test('save move os rascunhos para media antes de gravar', () async {
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard()..setText(Side.back, 'b');
      await viewModel.pickImage(Side.front, ImageOrigin.camera);

      expect(await viewModel.save(), isTrue);

      expect(media.committed, ['img_1.jpg']);
      expect(cards.cards.last.front.image, 'img_1.jpg');
      expect(viewModel.imagePath(Side.front), '/media/img_1.jpg');
    });

    test('se o banco falhar, os arquivos voltam a ser rascunho', () async {
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard()..setText(Side.back, 'b');
      await viewModel.pickImage(Side.front, ImageOrigin.camera);
      cards.failWith = Exception('disco');

      expect(await viewModel.save(), isFalse);

      expect(media.reverted, ['img_1.jpg']);
      expect(viewModel.actionError, CardEditorViewModel.saveErrorMessage);
      expect(viewModel.imagePath(Side.front), '/drafts/img_1.jpg');
    });

    test('se mover os arquivos falhar, nada é gravado', () async {
      media
        ..nextPick = 'img_1.jpg'
        ..commitError = Exception('disco cheio');
      final viewModel = newCard()..setText(Side.back, 'b');
      await viewModel.pickImage(Side.front, ImageOrigin.camera);
      final before = cards.cards.length;

      expect(await viewModel.save(), isFalse);

      expect(cards.cards.length, before);
      expect(viewModel.actionError, CardEditorViewModel.saveErrorMessage);
    });

    test('discard apaga só os arquivos novos', () async {
      media.nextPick = 'img_nova.jpg';
      cards = FakeCardRepository([
        Flashcard(
          id: 7,
          deckId: 1,
          front: const CardSide(image: 'img_salva.jpg'),
          back: const CardSide(text: 'b'),
          createdAt: DateTime(2026),
        ),
      ]);
      final viewModel = editCard();
      await viewModel.load();
      await viewModel.pickImage(Side.back, ImageOrigin.gallery);

      await viewModel.discard();

      expect(media.discarded, ['img_nova.jpg']);
    });
  });

  group('imagens e salvamento', () {
    // A new card with a picked front image and back text, ready to save.
    Future<CardEditorViewModel> readyToSave() async {
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard()..setText(Side.back, 'b');
      await viewModel.pickImage(Side.front, ImageOrigin.camera);
      return viewModel;
    }

    test('foto que chega durante o commit não é salva', () async {
      final viewModel = await readyToSave();
      media.pickGate = Completer();
      media.nextPick = 'img_tardia.jpg';
      final pick = viewModel.pickImage(Side.back, ImageOrigin.gallery);
      media.commitGate = Completer();
      final save = viewModel.save();
      await pumpEventQueue();

      media.pickGate!.complete();
      await pick;
      media.commitGate!.complete();

      expect(await save, isTrue);
      expect(cards.cards.last.back.image, isNull);
      expect(media.discarded, ['img_tardia.jpg']);
    });

    test('pickImage durante o salvamento não chama o seletor', () async {
      final viewModel = await readyToSave();
      media.commitGate = Completer();
      final save = viewModel.save();
      await pumpEventQueue();
      final before = media.picks.length;

      expect(await viewModel.pickImage(Side.back, ImageOrigin.camera), isTrue);

      expect(media.picks.length, before);
      media.commitGate!.complete();
      await save;
    });

    test('removeImage durante o salvamento não muda nada', () async {
      final viewModel = await readyToSave();
      media.commitGate = Completer();
      final save = viewModel.save();
      await pumpEventQueue();

      await viewModel.removeImage(Side.front);
      media.commitGate!.complete();

      expect(await save, isTrue);
      expect(cards.cards.last.front.image, 'img_1.jpg');
      expect(media.discarded, isEmpty);
    });

    test('durante a gravação a imagem já aponta para media', () async {
      final viewModel = await readyToSave();
      cards.createGate = Completer();
      final save = viewModel.save();
      await pumpEventQueue();

      expect(viewModel.imagePath(Side.front), '/media/img_1.jpg');

      cards.createGate!.complete();
      await save;
      expect(viewModel.imagePath(Side.front), '/media/img_1.jpg');
    });

    test('se o banco falhar, o caminho volta para o rascunho', () async {
      final viewModel = await readyToSave();
      cards.failWith = Exception('disco');

      await viewModel.save();

      expect(viewModel.imagePath(Side.front), '/drafts/img_1.jpg');
    });

    test('dois pickImage ao mesmo tempo chamam o seletor uma vez', () async {
      media.pickGate = Completer();
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard();

      final first = viewModel.pickImage(Side.front, ImageOrigin.camera);
      final second = viewModel.pickImage(Side.front, ImageOrigin.camera);
      media.pickGate!.complete();

      expect(await second, isTrue);
      expect(await first, isTrue);
      expect(media.picks.length, 1);
      expect(viewModel.actionError, isNull);
    });

    test(
      'um card salvo com imagem que não existe mostra o caminho de media',
      () async {
        cards = FakeCardRepository([
          Flashcard(
            id: 7,
            deckId: 1,
            front: const CardSide(text: 'a', image: 'img_salva.jpg'),
            back: const CardSide(text: 'b'),
            createdAt: DateTime(2026),
          ),
        ]);
        final viewModel = editCard();
        await viewModel.load();

        expect(viewModel.imagePath(Side.front), '/media/img_salva.jpg');
      },
    );
  });
}
