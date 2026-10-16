import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/ui/deck_list/view_models/deck_list_view_model.dart';
import 'package:my_flashcards/ui/deck_list/widgets/deck_list_screen.dart';

import '../../fakes/fake_deck_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDeckRepository repository, {
    Future<void> Function(Deck deck)? onOpenDeck,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeckListScreen(
          viewModel: DeckListViewModel(deckRepository: repository),
          onOpenDeck: onOpenDeck ?? (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Deck deck(int id, String name, int cardCount) =>
      Deck(id: id, name: name, createdAt: DateTime(2026), cardCount: cardCount);

  testWidgets('mostra a mensagem de lista vazia', (tester) async {
    await pumpScreen(tester, FakeDeckRepository());

    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
  });

  testWidgets('mostra o nome e a quantidade de cards', (tester) async {
    await pumpScreen(
      tester,
      FakeDeckRepository([deck(1, 'A', 0), deck(2, 'B', 1), deck(3, 'C', 42)]),
    );

    expect(find.text('Nenhum card'), findsOneWidget);
    expect(find.text('1 card'), findsOneWidget);
    expect(find.text('42 cards'), findsOneWidget);
  });

  testWidgets('cria um deck pelo botão +', (tester) async {
    final repository = FakeDeckRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Novo deck'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Phrasal verbs  ');
    await tester.pump();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Phrasal verbs'), findsOneWidget);
    expect(repository.decks.single.name, 'Phrasal verbs');
  });

  testWidgets('Criar fica desativado com o nome em branco', (tester) async {
    await pumpScreen(tester, FakeDeckRepository());

    await tester.tap(find.byTooltip('Novo deck'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final criar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Criar'),
    );
    expect(criar.onPressed, isNull);
  });

  testWidgets('o campo de nome não aceita mais de 50 caracteres', (
    tester,
  ) async {
    await pumpScreen(tester, FakeDeckRepository());

    await tester.tap(find.byTooltip('Novo deck'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a' * 60);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 50);
  });

  testWidgets('renomeia pelo menu ⋮', (tester) async {
    final repository = FakeDeckRepository([deck(1, 'Verbos', 0)]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Opções do deck'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Verbos irregulares');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Verbos irregulares'), findsOneWidget);
  });

  testWidgets('exclui depois de confirmar, avisando quantos cards somem', (
    tester,
  ) async {
    final repository = FakeDeckRepository([deck(1, 'Verbos', 42)]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Opções do deck'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Excluir “Verbos”? Os 42 cards serão apagados. '
        'Isso não pode ser desfeito.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repository.decks, isEmpty);
    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelar a exclusão mantém o deck', (tester) async {
    final repository = FakeDeckRepository([deck(1, 'Verbos', 0)]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Opções do deck'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.decks, hasLength(1));
  });

  testWidgets('falha ao carregar mostra erro e permite tentar de novo', (
    tester,
  ) async {
    final repository = FakeDeckRepository([deck(1, 'Verbos', 0)])
      ..failWith = Exception('disco');
    await pumpScreen(tester, repository);

    expect(find.text('Não foi possível carregar os decks.'), findsOneWidget);

    repository.failWith = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Verbos'), findsOneWidget);
  });

  testWidgets('falha ao criar mostra uma SnackBar', (tester) async {
    final repository = FakeDeckRepository();
    await pumpScreen(tester, repository);
    repository.failWith = Exception('disco');

    await tester.tap(find.byTooltip('Novo deck'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Verbos');
    await tester.pump();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível criar o deck.'), findsOneWidget);
  });

  testWidgets('tocar num deck abre o deck e recarrega ao voltar', (
    tester,
  ) async {
    final repository = FakeDeckRepository([deck(1, 'Verbos', 0)]);
    final opened = <int>[];
    await pumpScreen(
      tester,
      repository,
      onOpenDeck: (deck) async {
        opened.add(deck.id);
        await repository.renameDeck(deck.id, 'Verbos (editado)');
      },
    );

    await tester.tap(find.text('Verbos'));
    await tester.pumpAndSettle();

    expect(opened, [1]);
    expect(find.text('Verbos (editado)'), findsOneWidget);
  });
}
