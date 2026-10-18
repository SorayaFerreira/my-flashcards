import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/ui/card_editor/view_models/card_editor_view_model.dart';
import 'package:my_flashcards/ui/card_editor/view_models/side_draft.dart';

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

  group('áudio', () {
    test('gravar e parar põe o áudio novo no lado, com a duração', () {
      fakeAsync((async) {
        final viewModel = newCard();
        viewModel.startRecording(Side.back);
        async.flushMicrotasks();
        expect(viewModel.recordingSide, Side.back);
        expect(viewModel.canSave, isFalse);

        async.elapse(const Duration(seconds: 7));
        expect(viewModel.recordingElapsed, const Duration(seconds: 7));

        viewModel.stopRecording();
        async.flushMicrotasks();

        expect(viewModel.isRecording, isFalse);
        expect(media.stopRecordingCalls, 1);
        expect(
          viewModel.draft(Side.back).audio,
          const DraftFile('aud_1.m4a', isNew: true),
        );
        expect(viewModel.audioPath(Side.back), '/drafts/aud_1.m4a');
        expect(viewModel.audioDuration(Side.back), const Duration(seconds: 7));
      });
    });

    test('para sozinho aos 60 segundos e mantém o áudio', () {
      fakeAsync((async) {
        final viewModel = newCard();
        viewModel.startRecording(Side.front);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 59));
        expect(viewModel.isRecording, isTrue);

        async.elapse(const Duration(seconds: 1));

        expect(viewModel.isRecording, isFalse);
        expect(viewModel.draft(Side.front).audio?.name, 'aud_1.m4a');
        expect(
          viewModel.audioDuration(Side.front),
          CardEditorViewModel.maxRecording,
        );
      });
    });

    test('microfone negado mostra a mensagem e não grava', () async {
      media.microphoneAllowed = false;
      final viewModel = newCard();

      expect(await viewModel.startRecording(Side.front), isFalse);

      expect(viewModel.isRecording, isFalse);
      expect(media.recordings, isEmpty);
      expect(
        viewModel.actionError,
        CardEditorViewModel.microphoneDeniedMessage,
      );
    });

    test('não grava dois lados ao mesmo tempo', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);

      expect(await viewModel.startRecording(Side.back), isFalse);
      expect(viewModel.recordingSide, Side.front);

      await viewModel.stopRecording();
    });

    test('regravar apaga a gravação nova anterior', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();

      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();

      expect(media.discarded, ['aud_1.m4a']);
      expect(viewModel.draft(Side.front).audio?.name, 'aud_2.m4a');
    });

    test('togglePlay toca e para, e o fim do áudio é percebido', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();

      await viewModel.togglePlay(Side.front);
      expect(media.played, ['/drafts/aud_1.m4a']);
      expect(viewModel.isPlaying(Side.front), isTrue);

      media.finishPlayback();
      expect(viewModel.isPlaying(Side.front), isFalse);

      await viewModel.togglePlay(Side.front);
      await viewModel.togglePlay(Side.front);
      expect(viewModel.isPlaying(Side.front), isFalse);
    });

    test('começar a gravar para o som', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();
      await viewModel.togglePlay(Side.front);

      await viewModel.startRecording(Side.back);

      expect(viewModel.isPlaying(Side.front), isFalse);
      await viewModel.stopRecording();
    });

    test('descartar durante a gravação para e apaga o rascunho', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);

      await viewModel.discard();

      expect(viewModel.isRecording, isFalse);
      expect(media.discarded, ['aud_1.m4a']);
    });

    test('um card já salvo mostra a duração do áudio', () async {
      cards = FakeCardRepository([
        Flashcard(
          id: 7,
          deckId: 1,
          front: const CardSide(text: 'apple', audio: 'aud_salvo.m4a'),
          back: const CardSide(text: 'maçã'),
          createdAt: DateTime(2026),
        ),
      ]);
      media.duration = const Duration(seconds: 3);
      final viewModel = editCard();

      await viewModel.load();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.audioPath(Side.front), '/media/aud_salvo.m4a');
      expect(viewModel.audioDuration(Side.front), const Duration(seconds: 3));
    });

    test('salvar move o áudio novo e grava no card', () async {
      final viewModel = newCard()..setText(Side.front, 'apple');
      await viewModel.startRecording(Side.back);
      await viewModel.stopRecording();

      expect(await viewModel.save(), isTrue);

      expect(media.committed, ['aud_1.m4a']);
      expect(cards.cards.last.back.audio, 'aud_1.m4a');
    });

    group('e salvamento', () {
      // A new card with a recorded back audio and front text.
      Future<CardEditorViewModel> readyToSave() async {
        final viewModel = newCard()..setText(Side.front, 'apple');
        await viewModel.startRecording(Side.back);
        await viewModel.stopRecording();
        return viewModel;
      }

      test('dois startRecording ao mesmo tempo criam uma gravação', () async {
        final viewModel = newCard();

        final first = viewModel.startRecording(Side.front);
        final second = viewModel.startRecording(Side.front);

        expect(await second, isFalse);
        expect(await first, isTrue);
        expect(media.recordings.length, 1);
        await viewModel.stopRecording();
      });

      test('removeAudio durante o salvamento não muda nada', () async {
        final viewModel = await readyToSave();
        media.commitGate = Completer();
        final save = viewModel.save();
        await pumpEventQueue();

        await viewModel.removeAudio(Side.back);
        media.commitGate!.complete();

        expect(await save, isTrue);
        expect(cards.cards.last.back.audio, 'aud_1.m4a');
        expect(media.discarded, isEmpty);
      });

      test(
        'startRecording e togglePlay durante o salvamento não agem',
        () async {
          final viewModel = await readyToSave();
          media.commitGate = Completer();
          final save = viewModel.save();
          await pumpEventQueue();

          expect(await viewModel.startRecording(Side.front), isFalse);
          await viewModel.togglePlay(Side.back);
          media.commitGate!.complete();
          await save;

          expect(media.recordings.length, 1);
          expect(media.played, isEmpty);
          expect(viewModel.actionError, isNull);
        },
      );

      test(
        'durante a gravação no banco o áudio já aponta para media',
        () async {
          final viewModel = await readyToSave();
          cards.createGate = Completer();
          final save = viewModel.save();
          await pumpEventQueue();

          expect(viewModel.audioPath(Side.back), '/media/aud_1.m4a');

          cards.createGate!.complete();
          await save;
          expect(viewModel.audioPath(Side.back), '/media/aud_1.m4a');
        },
      );
    });

    group('parada da gravação', () {
      test('enquanto a parada não termina, não salva nem grava', () async {
        final viewModel = newCard()..setText(Side.front, 'a');
        await viewModel.startRecording(Side.back);
        media.stopGate = Completer();
        final stop = viewModel.stopRecording();
        await pumpEventQueue();

        expect(viewModel.isRecording, isTrue);
        expect(viewModel.canSave, isFalse);
        expect(await viewModel.startRecording(Side.front), isFalse);

        media.stopGate!.complete();
        await stop;
        expect(viewModel.isRecording, isFalse);
        expect(viewModel.draft(Side.back).audio?.name, 'aud_1.m4a');
        expect(media.recordings.length, 1);
      });

      test('discard durante a parada espera e apaga o arquivo', () async {
        final viewModel = newCard();
        await viewModel.startRecording(Side.front);
        media.stopGate = Completer();
        final stop = viewModel.stopRecording();
        final discard = viewModel.discard();
        await pumpEventQueue();

        media.stopGate!.complete();
        await stop;
        await discard;

        expect(media.discarded, ['aud_1.m4a']);
        expect(viewModel.isRecording, isFalse);
      });

      test('parada que falha apaga o rascunho e avisa', () async {
        final viewModel = newCard();
        await viewModel.startRecording(Side.front);
        media.stopError = Exception('falhou');

        await viewModel.stopRecording();

        expect(media.discarded, ['aud_1.m4a']);
        expect(viewModel.draft(Side.front).audio, isNull);
        expect(viewModel.isRecording, isFalse);
        expect(viewModel.actionError, CardEditorViewModel.recordErrorMessage);
      });
    });

    test('erro ao pedir o microfone mostra a mensagem de gravação', () async {
      media.microphoneError = Exception('x');
      final viewModel = newCard();

      expect(await viewModel.startRecording(Side.front), isFalse);

      expect(viewModel.actionError, CardEditorViewModel.recordErrorMessage);
    });

    test('erro ao tocar mostra a mensagem de reprodução', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();
      media.playError = Exception('x');

      expect(await viewModel.togglePlay(Side.front), isFalse);

      expect(viewModel.actionError, CardEditorViewModel.playErrorMessage);
    });

    test('depois do dispose o fim do áudio não dá erro', () async {
      final viewModel = newCard();
      await viewModel.startRecording(Side.front);
      await viewModel.stopRecording();
      await viewModel.togglePlay(Side.front);

      expect(media.hasPlayingListeners, isTrue);
      viewModel.dispose();

      expect(media.hasPlayingListeners, isFalse);
      expect(media.finishPlayback, returnsNormally);
    });
  });
}
