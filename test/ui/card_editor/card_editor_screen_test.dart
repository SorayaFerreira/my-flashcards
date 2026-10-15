import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/card_editor/view_models/card_editor_view_model.dart';
import 'package:my_flashcards/ui/card_editor/widgets/card_editor_screen.dart';

import '../../fakes/fake_card_repository.dart';

void main() {
  late FakeCardRepository cards;

  setUp(() {
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
  Future<List<bool?>> openEditor(WidgetTester tester, {int? cardId}) async {
    final results = <bool?>[];
    final viewModel = CardEditorViewModel(
      deckId: 1,
      cardId: cardId,
      cardRepository: cards,
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
}
