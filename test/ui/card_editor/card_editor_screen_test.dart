import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/ui/card_editor/view_models/card_editor_view_model.dart';
import 'package:my_flashcards/ui/card_editor/widgets/card_editor_screen.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_media_repository.dart';
import '../../helpers/temp_media.dart';

class _GatedCardRepository extends FakeCardRepository {
  _GatedCardRepository(super.cards);

  final gate = Completer<void>();

  @override
  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) async {
    await gate.future;
    return super.updateCard(id: id, front: front, back: back);
  }
}

void main() {
  late FakeCardRepository cards;
  late FakeMediaRepository media;

  setUp(() {
    media = FakeMediaRepository();
    cards = FakeCardRepository([
      Flashcard(
        id: 7,
        deckId: 1,
        front: const CardSide(text: 'to give up'),
        back: const CardSide(text: 'desistir'),
        createdAt: DateTime(2026),
      ),
    ]);
  });

  /// Opens the editor from a host page and returns the values it pops with.
  Future<List<bool?>> openEditor(
    WidgetTester tester, {
    int? cardId,
    FakeCardRepository? repository,
  }) async {
    final results = <bool?>[];
    final viewModel = CardEditorViewModel(
      deckId: 1,
      cardId: cardId,
      cardRepository: repository ?? cards,
      mediaRepository: media,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => results.add(
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CardEditorScreen(viewModel: viewModel),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'SALVAR'));

  Finder textField(int index) => find.byType(TextField).at(index);

  testWidgets('card novo: SALVAR só ativa com os dois lados preenchidos', (
    tester,
  ) async {
    final results = await openEditor(tester);

    expect(find.text('Novo card'), findsOneWidget);
    expect(find.byTooltip('Excluir card'), findsNothing);
    expect(find.text('Adicione texto, imagem ou áudio'), findsNWidgets(2));
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(textField(0), 'to look forward to');
    await tester.pump();
    expect(find.text('Adicione texto, imagem ou áudio'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(textField(1), 'aguardar ansiosamente');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(cards.cards.last.front.text, 'to look forward to');
  });

  testWidgets('editar: carrega os textos e salva a alteração', (tester) async {
    final results = await openEditor(tester, cardId: 7);

    expect(find.text('Editar card'), findsOneWidget);
    expect(find.text('to give up'), findsOneWidget);
    expect(find.text('desistir'), findsOneWidget);

    await tester.enterText(textField(1), 'largar');
    await tester.pump();
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(cards.cards.single.back.text, 'largar');
  });

  testWidgets('voltar sem alterações sai direto', (tester) async {
    final results = await openEditor(tester, cardId: 7);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Descartar alterações?'), findsNothing);
    expect(results, [null]);
  });

  testWidgets('voltar com alterações pergunta antes de descartar', (
    tester,
  ) async {
    final results = await openEditor(tester, cardId: 7);
    await tester.enterText(textField(0), 'outra coisa');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Editar card'), findsOneWidget);
    expect(results, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(cards.cards.single.front.text, 'to give up');
  });

  testWidgets('excluir pede confirmação e apaga o card', (tester) async {
    final results = await openEditor(tester, cardId: 7);

    await tester.tap(find.byTooltip('Excluir card'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir este card?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(cards.cards, isEmpty);
  });

  testWidgets('falha ao salvar mostra a mensagem e continua no editor', (
    tester,
  ) async {
    await openEditor(tester, cardId: 7);
    await tester.enterText(textField(1), 'largar');
    await tester.pump();
    cards.failWith = Exception('disco');

    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Editar card'), findsOneWidget);
    expect(find.text('largar'), findsOneWidget);
  });

  testWidgets(
    'enquanto salva, a lixeira fica desativada e o voltar não faz nada',
    (tester) async {
      final gated = _GatedCardRepository(cards.cards);
      final results = await openEditor(tester, cardId: 7, repository: gated);
      await tester.enterText(textField(1), 'largar');
      await tester.pump();

      await tester.tap(find.text('SALVAR'));
      await tester.pump();

      final trash = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(trash.onPressed, isNull);

      await tester.pageBack();
      await tester.pump();
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('Editar card'), findsOneWidget);

      gated.gate.complete();
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(gated.cards.single.back.text, 'largar');
    },
  );

  testWidgets('texto só com espaços não conta como preenchido', (tester) async {
    await openEditor(tester);

    await tester.enterText(textField(0), 'to give up');
    await tester.pump();
    await tester.enterText(textField(1), '  \n ');
    await tester.pump();

    expect(find.text('Adicione texto, imagem ou áudio'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('card novo abre com o cursor na frente', (tester) async {
    await openEditor(tester);
    expect(tester.widget<TextField>(textField(0)).autofocus, isTrue);
    expect(tester.widget<TextField>(textField(1)).autofocus, isFalse);
  });

  testWidgets('card existente não abre com autofocus', (tester) async {
    await openEditor(tester, cardId: 7);
    expect(tester.widget<TextField>(textField(0)).autofocus, isFalse);
    expect(tester.widget<TextField>(textField(1)).autofocus, isFalse);
  });

  testWidgets('Câmera põe a imagem no lado e troca os botões pelo ✕', (
    tester,
  ) async {
    media.nextPick = 'img_1.jpg';
    await openEditor(tester);

    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();

    expect(media.picks, [ImageOrigin.camera]);
    expect(find.byTooltip('Remover imagem'), findsOneWidget);
    expect(find.text('Câmera'), findsOneWidget);
  });

  testWidgets('frente só com imagem e verso com texto já podem ser salvos', (
    tester,
  ) async {
    media.nextPick = 'img_1.jpg';
    final results = await openEditor(tester);

    await tester.tap(find.text('Galeria').first);
    await tester.pumpAndSettle();
    await tester.enterText(textField(1), 'desistir');
    await tester.pump();
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(cards.cards.last.front.image, 'img_1.jpg');
  });

  testWidgets('descartar apaga a imagem nova', (tester) async {
    media.nextPick = 'img_1.jpg';
    final results = await openEditor(tester);
    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(media.discarded, ['img_1.jpg']);
  });

  testWidgets('✕ remove a imagem e os botões voltam', (tester) async {
    media.nextPick = 'img_1.jpg';
    await openEditor(tester);
    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remover imagem'));
    await tester.pumpAndSettle();

    expect(find.text('Câmera'), findsNWidgets(2));
    expect(media.discarded, ['img_1.jpg']);
  });

  testWidgets('enquanto salva, Câmera, Galeria e ✕ ficam desativados', (
    tester,
  ) async {
    media.nextPick = 'img_1.jpg';
    await openEditor(tester);
    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();
    await tester.enterText(textField(1), 'desistir');
    await tester.pump();
    media.commitGate = Completer();

    await tester.tap(find.text('SALVAR'));
    await tester.pump();

    final camera = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Câmera'),
    );
    expect(camera.onPressed, isNull);
    final remove = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    expect(remove.onPressed, isNull);

    media.commitGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('imagem salva que sumiu mostra "Imagem não encontrada"', (
    tester,
  ) async {
    cards = FakeCardRepository([
      Flashcard(
        id: 7,
        deckId: 1,
        front: const CardSide(text: 'a', image: 'img_salva.jpg'),
        back: const CardSide(text: 'b'),
        createdAt: DateTime(2026),
      ),
    ]);

    await openEditor(tester, cardId: 7);

    expect(find.text('Imagem não encontrada'), findsOneWidget);
  });

  testWidgets('Gravar e Parar põem o áudio no lado', (tester) async {
    await openEditor(tester);

    await tester.tap(find.text('Gravar').first);
    await tester.pump();
    expect(find.text('Parar'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();

    expect(find.text('Regravar'), findsOneWidget);
    expect(find.text('0:03'), findsOneWidget);
  });

  testWidgets('microfone negado mostra a mensagem', (tester) async {
    media.microphoneAllowed = false;
    await openEditor(tester);

    await tester.tap(find.text('Gravar').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sem acesso ao microfone. Ative em Configurações › Apps › '
        'My Flashcards › Permissões.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a gravação para quando o app sai da tela', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Gravar').first);
    await tester.pump();

    // Real lifecycle order: resumed > inactive > hidden > inactive > resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsNothing);
    expect(find.text('Regravar'), findsOneWidget);
  });

  testWidgets('enquanto salva, Gravar fica desativado', (tester) async {
    media.nextPick = 'img_1.jpg';
    await openEditor(tester);
    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();
    await tester.enterText(textField(1), 'desistir');
    await tester.pump();
    media.commitGate = Completer();

    await tester.tap(find.text('SALVAR'));
    await tester.pump();

    final buttons = tester.widgetList<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Gravar'),
    );
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNull);
    }

    media.commitGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('parada que falha mostra a mensagem', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Gravar').first);
    await tester.pump();
    media.stopError = Exception('falhou');

    await tester.tap(find.text('Parar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível gravar o áudio.'), findsOneWidget);
  });

  testWidgets('durante uma gravação o ▶ do outro lado fica desativado', (
    tester,
  ) async {
    media.root = createFakeMediaRoot(['media/aud_salvo.m4a']);
    cards = FakeCardRepository([
      Flashcard(
        id: 7,
        deckId: 1,
        front: const CardSide(text: 'a'),
        back: const CardSide(text: 'b', audio: 'aud_salvo.m4a'),
        createdAt: DateTime(2026),
      ),
    ]);
    await openEditor(tester, cardId: 7);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Ouvir'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Gravar').first);
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Ouvir'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('voltar gravando pergunta, e Descartar apaga a gravação', (
    tester,
  ) async {
    final results = await openEditor(tester);
    await tester.tap(find.text('Gravar').first);
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(media.discarded, ['aud_1.m4a']);
    expect(media.stopRecordingCalls, 1);
  });

  testWidgets('sair da tela enquanto o microfone abre não deixa gravando', (
    tester,
  ) async {
    media.microphoneGate = Completer();
    await openEditor(tester);
    await tester.tap(find.text('Gravar').first);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    media.microphoneGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsNothing);
    expect(find.text('Regravar'), findsOneWidget);
    expect(media.stopRecordingCalls, 1);
  });
}
