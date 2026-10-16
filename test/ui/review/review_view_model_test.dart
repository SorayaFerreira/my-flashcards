import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/review/view_models/review_view_model.dart';

import '../../fakes/fake_card_repository.dart';

void main() {
  late FakeCardRepository cards;
  late ReviewViewModel viewModel;

  Flashcard card(int id, int reviewCount, {int deckId = 1}) => Flashcard(
    id: id,
    deckId: deckId,
    front: CardSide(text: 'frente $id'),
    back: CardSide(text: 'verso $id'),
    createdAt: DateTime(2026, 1, id),
    reviewCount: reviewCount,
  );

  setUp(() {
    cards = FakeCardRepository([
      card(1, 5),
      card(2, 0),
      card(3, 2),
      card(9, 0, deckId: 2),
    ]);
    viewModel = ReviewViewModel(
      deckId: 1,
      cardRepository: cards,
      random: Random(1),
    );
  });

  test('start monta a fila do deck, os menos revisados primeiro', () async {
    await viewModel.start();

    expect(viewModel.total, 3);
    expect(viewModel.position, 1);
    expect(viewModel.current?.id, 2);
    expect(viewModel.isFirst, isTrue);
    expect(viewModel.isFinished, isFalse);
  });

  test('next e previous andam pela fila dentro dos limites', () async {
    await viewModel.start();

    viewModel.previous();
    expect(viewModel.position, 1);

    viewModel.next();
    expect(viewModel.current?.id, 3);
    viewModel.next();
    expect(viewModel.current?.id, 1);
    expect(viewModel.isLast, isTrue);

    viewModel.previous();
    expect(viewModel.current?.id, 3);
  });

  test('next no último card termina a sessão', () async {
    await viewModel.start();
    viewModel
      ..next()
      ..next()
      ..next();

    expect(viewModel.isFinished, isTrue);
    expect(viewModel.current, isNull);
  });

  test('markBackSeen soma um no card atual e salva no banco', () async {
    await viewModel.start();

    expect(await viewModel.markBackSeen(), isTrue);

    expect(viewModel.current?.reviewCount, 1);
    expect(cards.cards.firstWhere((c) => c.id == 2).reviewCount, 1);
    expect(viewModel.reviewedCount, 1);
  });

  test(
    'o mesmo card conta só uma vez por sessão, mesmo voltando nele',
    () async {
      await viewModel.start();

      await viewModel.markBackSeen();
      await viewModel.markBackSeen();
      viewModel.next();
      viewModel.previous();
      await viewModel.markBackSeen();

      expect(cards.cards.firstWhere((c) => c.id == 2).reviewCount, 1);
      expect(viewModel.reviewedCount, 1);
    },
  );

  test('duas chamadas seguidas, sem esperar, contam uma vez só', () async {
    await viewModel.start();

    await Future.wait([viewModel.markBackSeen(), viewModel.markBackSeen()]);

    expect(cards.cards.firstWhere((c) => c.id == 2).reviewCount, 1);
  });

  test('falha ao salvar devolve false e deixa contar de novo depois', () async {
    await viewModel.start();
    cards.failWith = Exception('disco');

    expect(await viewModel.markBackSeen(), isFalse);
    expect(viewModel.reviewedCount, 0);

    cards.failWith = null;
    expect(await viewModel.markBackSeen(), isTrue);
    expect(viewModel.current?.reviewCount, 1);
  });

  test('restart recalcula a ordem com os novos contadores', () async {
    await viewModel.start();
    final firstSession = viewModel.session;
    await viewModel.markBackSeen();
    viewModel
      ..next()
      ..next()
      ..next();

    await viewModel.restart();

    expect(viewModel.session, greaterThan(firstSession));
    expect(viewModel.isFinished, isFalse);
    expect(viewModel.position, 1);
    expect(viewModel.reviewedCount, 0);
    expect(viewModel.current?.id, 2);
  });

  test('restart recalcula a ordem: o card revisado vai para depois', () async {
    final pair = FakeCardRepository([card(1, 0), card(2, 0)]);
    final vm = ReviewViewModel(
      deckId: 1,
      cardRepository: pair,
      random: Random(1),
    );
    await vm.start();
    final first = vm.current!.id;
    await vm.markBackSeen();
    while (!vm.isFinished) {
      vm.next();
    }

    await vm.restart();

    expect(vm.current!.id, isNot(first));
  });

  test('deck vazio termina na hora com zero cards', () async {
    final empty = ReviewViewModel(deckId: 42, cardRepository: cards);

    await empty.start();

    expect(empty.isFinished, isTrue);
    expect(empty.total, 0);
  });

  test('falha ao carregar guarda a mensagem', () async {
    cards.failWith = Exception('disco');

    await viewModel.start();

    expect(viewModel.loadError, ReviewViewModel.loadErrorMessage);
  });
}
