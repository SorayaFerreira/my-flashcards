# Etapa 3: revisão. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** revisar um deck. O card gira ao ser arrastado para o lado. Os botões ‹ Anterior e Próximo › trocam de card. O contador no canto inferior direito sobe uma vez por card em cada sessão. Ao fim, aparece a tela "Revisão concluída!".

**Arquitetura:**
- **Ordem da revisão:** uma função pura, `orderForReview`, em `lib/domain/review_order.dart`.
- **Lógica:** o `ReviewViewModel` cuida da fila, da navegação, da regra do contador e do fim da sessão.
- **Animação:** o `FlipCard` é um widget sem regra de negócio. Ele avisa cada virada completa por callback, e a tela repassa ao ViewModel.
- **Peças de tela:**
  - `CardSideView` (em `ui/core`) desenha o conteúdo de um lado;
  - `ReviewCardFace` desenha a moldura com a etiqueta e o contador.

**Tecnologias:** Flutter 3.47 (`AnimationController`, `Transform` com `Matrix4`), sem pacotes novos.

**Spec:** [docs/design.md](../design.md), parte 2 ("4. Revisão") e parte 1 (`ReviewViewModel`). Requisitos RF-12 a RF-17.

**Branch:** `etapa-3-revisao`

## Restrições globais

- **Ordem:** os menos revisados vêm primeiro e os empates são embaralhados. A ordem é calculada no início da sessão e não muda durante ela.
- **Contador:** sobe 1 na primeira vez que o verso de um card aparece. **Cada card conta no máximo uma vez por sessão**, inclusive ao voltar com ‹ Anterior. A contagem é salva no banco na hora.
- **Virar:**
  - é feito por arrasto horizontal, para qualquer lado;
  - arrastar a largura inteira do card equivale a meia volta;
  - ao soltar depois de meia volta, ou com velocidade acima de 700 px/s no sentido do giro, a virada se completa; senão, o card volta;
  - a animação dura 250 ms.
- **Trocar de card** mostra sempre a frente, sem animação de deslizar.
- **Dica:** *"⟵ arraste para virar ⟶"* aparece só no primeiro card da sessão, até a primeira virada.
- **Botões:** no último card, "Próximo ›" vira "Concluir". "‹ Anterior" fica desativado no primeiro card.
- O ViewModel não conhece widgets. O `FlipCard` não conhece o ViewModel.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Virar e desvirar várias vezes, ou voltar com ‹ Anterior e virar de novo.** O contador do card sobe só uma vez na sessão. Testado nas tarefas 3 e 5.
2. **Arrasto curto e lento.** O card volta, sem virar e sem contar. Um peteleco rápido, mesmo curto, vira. Testado na tarefa 4.
3. **Falha ao salvar a contagem.** Aparece *"Não foi possível salvar a revisão."*, e o card pode ser contado de novo na próxima virada. Testado na tarefa 3.
4. **Deck com um único card.** O botão já mostra "Concluir" e o ‹ Anterior fica desativado. Testado na tarefa 5.
5. **"Revisar de novo".** Recalcula a ordem com os contadores novos, mostra a frente e volta a exibir a dica. Testado nas tarefas 3 e 5.

---

### Tarefa 1: ordem da revisão

**Arquivos:**
- Criar: `lib/domain/review_order.dart`
- Testar: `test/domain/review_order_test.dart`

**Interfaces:**
- Consome: `Flashcard` (etapa 2).
- Produz: `List<Flashcard> orderForReview(Iterable<Flashcard> cards, Random random)`.

- [ ] **Passo 1: criar o branch**

```bash
git switch main && git switch -c etapa-3-revisao
```

- [ ] **Passo 2: escrever o teste**

`test/domain/review_order_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/domain/review_order.dart';

void main() {
  Flashcard card(int id, int reviewCount) => Flashcard(
        id: id,
        deckId: 1,
        front: const CardSide(text: 'f'),
        back: const CardSide(text: 'v'),
        createdAt: DateTime(2026),
        reviewCount: reviewCount,
      );

  test('os menos revisados vêm primeiro', () {
    final ordered = orderForReview(
      [card(1, 3), card(2, 0), card(3, 1)],
      Random(1),
    );

    expect(ordered.map((c) => c.reviewCount), [0, 1, 3]);
  });

  test('cards empatados ficam juntos, antes dos mais revisados', () {
    final ordered = orderForReview(
      [card(1, 1), card(2, 0), card(3, 1), card(4, 0), card(5, 0)],
      Random(1),
    );

    expect(ordered.map((c) => c.reviewCount), [0, 0, 0, 1, 1]);
    expect(ordered.map((c) => c.id).toSet(), {1, 2, 3, 4, 5});
  });

  test('a ordem dos empatados depende do sorteio', () {
    final cards = [for (var id = 1; id <= 10; id++) card(id, 0)];

    final a = orderForReview(cards, Random(1)).map((c) => c.id).toList();
    final b = orderForReview(cards, Random(2)).map((c) => c.id).toList();

    expect(a, isNot(b));
    expect(a.toSet(), b.toSet());
  });

  test('não altera a lista recebida', () {
    final cards = [card(1, 2), card(2, 0)];

    orderForReview(cards, Random(1));

    expect(cards.map((c) => c.id), [1, 2]);
  });

  test('deck vazio dá fila vazia', () {
    expect(orderForReview(const [], Random(1)), isEmpty);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/domain/review_order_test.dart
```

Esperado: FALHA de compilação (`review_order.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/domain/review_order.dart`:
```dart
import 'dart:collection';
import 'dart:math';

import 'models/flashcard.dart';

/// The least reviewed cards come first; cards with the same count are
/// shuffled among themselves.
List<Flashcard> orderForReview(Iterable<Flashcard> cards, Random random) {
  final byCount = SplayTreeMap<int, List<Flashcard>>();
  for (final card in cards) {
    byCount.putIfAbsent(card.reviewCount, () => []).add(card);
  }
  return [
    for (final group in byCount.values) ...(group..shuffle(random)),
  ];
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/domain/review_order_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/domain/review_order.dart test/domain/review_order_test.dart
git commit -m "feat: ordena a revisão pelos menos revisados, embaralhando empates"
```

---

### Tarefa 2: somar uma revisão no banco

**Arquivos:**
- Modificar: `lib/data/repositories/card_repository.dart`
- Modificar: `test/fakes/fake_card_repository.dart`
- Testar: `test/data/repositories/card_repository_test.dart` (acrescentar testes)

**Interfaces:**
- Produz: `Future<Result<int>> incrementReviewCount(int id)` em `CardRepository` e no `FakeCardRepository`. Devolve o novo contador, ou `Error(NotFoundException)` se o card não existir.

- [ ] **Passo 1: escrever os testes**

Acrescente ao fim do `main()` de `test/data/repositories/card_repository_test.dart`:

```dart
  test('incrementReviewCount soma um e devolve o novo valor', () async {
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'a'),
      back: const CardSide(text: 'b'),
    ));

    expect(okValue(await repository.incrementReviewCount(card.id)), 1);
    expect(okValue(await repository.incrementReviewCount(card.id)), 2);
    expect(okValue(await repository.getCard(card.id)).reviewCount, 2);
  });

  test('incrementReviewCount de um card inexistente devolve erro', () async {
    expect(await repository.incrementReviewCount(999), isA<Error<int>>());
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/card_repository_test.dart
```

Esperado: FALHA de compilação (`incrementReviewCount` não existe).

- [ ] **Passo 3: implementar no repositório**

Em `lib/data/repositories/card_repository.dart`, acrescente este método à classe `CardRepository`, logo depois de `deleteCard`:

```dart
  /// Adds one review to the card and returns its new count.
  Future<Result<int>> incrementReviewCount(int id) => guard(() async {
        final updated = await _database.db.rawUpdate(
          'UPDATE cards SET review_count = review_count + 1 WHERE id = ?',
          [id],
        );
        if (updated == 0) throw NotFoundException('O card $id não existe.');
        final rows = await _database.db.query(
          'cards',
          columns: ['review_count'],
          where: 'id = ?',
          whereArgs: [id],
        );
        return rows.single['review_count']! as int;
      });
```

- [ ] **Passo 4: implementar no repositório falso**

Em `test/fakes/fake_card_repository.dart`, acrescente à classe `FakeCardRepository`:

```dart
  @override
  Future<Result<int>> incrementReviewCount(int id) => _answer(() {
        final index = _indexOf(id);
        final updated = _cards[index].copyWith(
          reviewCount: _cards[index].reviewCount + 1,
        );
        _cards[index] = updated;
        return updated.reviewCount;
      });
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/data/repositories/card_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/data/repositories/card_repository.dart test/fakes/fake_card_repository.dart test/data/repositories/card_repository_test.dart
git commit -m "feat: soma revisões no CardRepository"
```

---

### Tarefa 3: `ReviewViewModel`

**Arquivos:**
- Criar: `lib/ui/review/view_models/review_view_model.dart`
- Testar: `test/ui/review/review_view_model_test.dart`

**Interfaces:**
- Consome: `CardRepository.getCards`, `CardRepository.incrementReviewCount` e `orderForReview`.
- Produz: `class ReviewViewModel extends ChangeNotifier`, com:
  - o construtor `ReviewViewModel({required int deckId, required CardRepository cardRepository, Random? random})`;
  - os getters:
    - `bool isLoading`, `String? loadError` e `bool isFinished`;
    - `int session`, que aumenta a cada `start()`;
    - `int total`, `int position` (começa em 1) e `Flashcard? current` (`null` quando terminou ou não há cards);
    - `bool isFirst`, `bool isLast` e `int reviewedCount`;
  - os métodos `Future<void> start()`, `Future<void> restart()`, `void next()` (no último card, termina a sessão), `void previous()` e `Future<bool> markBackSeen()` (devolve `false` se a contagem não pôde ser salva);
  - as constantes `loadErrorMessage` e `countErrorMessage`.

- [ ] **Passo 1: escrever o teste**

`test/ui/review/review_view_model_test.dart`:
```dart
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

  test('o mesmo card conta só uma vez por sessão, mesmo voltando nele',
      () async {
    await viewModel.start();

    await viewModel.markBackSeen();
    await viewModel.markBackSeen();
    viewModel.next();
    viewModel.previous();
    await viewModel.markBackSeen();

    expect(cards.cards.firstWhere((c) => c.id == 2).reviewCount, 1);
    expect(viewModel.reviewedCount, 1);
  });

  test('duas chamadas seguidas, sem esperar, contam uma vez só', () async {
    await viewModel.start();

    await Future.wait([viewModel.markBackSeen(), viewModel.markBackSeen()]);

    expect(cards.cards.firstWhere((c) => c.id == 2).reviewCount, 1);
  });

  test('falha ao salvar devolve false e deixa contar de novo depois',
      () async {
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
```

> No `restart`, o card 2 passou a ter 1 revisão; os outros têm 2 e 5. Por isso ele continua sendo o primeiro.

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/review/review_view_model_test.dart
```

Esperado: FALHA de compilação (`review_view_model.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/ui/review/view_models/review_view_model.dart`:
```dart
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../domain/models/flashcard.dart';
import '../../../domain/review_order.dart';
import '../../../utils/result.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel({
    required this.deckId,
    required CardRepository cardRepository,
    Random? random,
  })  : _cardRepository = cardRepository,
        _random = random ?? Random();

  static const loadErrorMessage = 'Não foi possível carregar os cards.';
  static const countErrorMessage = 'Não foi possível salvar a revisão.';

  final int deckId;
  final CardRepository _cardRepository;
  final Random _random;

  List<Flashcard> _queue = const [];
  int _index = 0;
  int _session = 0;
  final Set<int> _backSeen = {};
  bool _isLoading = false;
  bool _isFinished = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isFinished => _isFinished;

  /// Grows every time a session starts, so the view can reset what it keeps
  /// per session.
  int get session => _session;

  int get total => _queue.length;
  int get position => _index + 1;
  bool get isFirst => _index == 0;
  bool get isLast => _index == _queue.length - 1;

  /// How many cards had their back seen in this session.
  int get reviewedCount => _backSeen.length;

  Flashcard? get current =>
      _isFinished || _queue.isEmpty ? null : _queue[_index];

  Future<void> start() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    switch (await _cardRepository.getCards(deckId)) {
      case Ok(value: final cards):
        _queue = orderForReview(cards, _random);
        _index = 0;
        _backSeen.clear();
        _isFinished = _queue.isEmpty;
        _session++;
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> restart() => start();

  void next() {
    if (current == null) return;
    if (isLast) {
      _isFinished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void previous() {
    if (current == null || isFirst) return;
    _index--;
    notifyListeners();
  }

  /// Counts one review for the current card the first time its back is seen
  /// in this session. Returns false when the count could not be saved.
  Future<bool> markBackSeen() async {
    final card = current;
    if (card == null || !_backSeen.add(card.id)) return true;
    notifyListeners();

    switch (await _cardRepository.incrementReviewCount(card.id)) {
      case Ok(value: final count):
        _queue = [
          for (final queued in _queue)
            queued.id == card.id ? queued.copyWith(reviewCount: count) : queued,
        ];
        notifyListeners();
        return true;
      case Error():
        _backSeen.remove(card.id);
        notifyListeners();
        return false;
    }
  }
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/ui/review/review_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/ui/review/view_models test/ui/review/review_view_model_test.dart
git commit -m "feat: cria o ReviewViewModel com a regra do contador"
```

---

### Tarefa 4: `FlipCard`, o card que vira ao arrastar

> **Ajustes feitos na execução (2026-10-16):** no Flutter 3.47.5, um arrasto já aceito que o sistema cancela chega em `onHorizontalDragEnd`, e não em `onHorizontalDragCancel`. Por isso o `FlipCard` ganhou um `Listener(onPointerCancel: ...)` que marca o arrasto como cancelado; o `_onDragEnd` então faz o card voltar, e a marca é zerada no `_onDragStart`. Não há `onHorizontalDragCancel`: um toque que vira um arrasto rejeitado (por exemplo, quando o conteúdo do card rola) não pode desfazer uma virada em andamento. Cada um desses comportamentos tem teste, assim como o peteleco no sentido contrário e o verso não espelhado.

**Arquivos:**
- Criar: `lib/ui/review/widgets/flip_card.dart`
- Testar: `test/ui/review/flip_card_test.dart`

**Interfaces:**
- Produz: `class FlipCard extends StatefulWidget`, com:
  - o construtor `const FlipCard({super.key, required Widget front, required Widget back, ValueChanged<bool>? onFlip})`;
  - `onFlip(true)` é chamado depois de cada virada completa para o verso, e `onFlip(false)` depois de cada virada de volta para a frente;
  - as constantes `flipDuration = Duration(milliseconds: 250)` e `flingVelocity = 700.0`;
  - para começar de novo pela frente, quem usa o widget troca a `key`.

- [ ] **Passo 1: escrever o teste**

`test/ui/review/flip_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';

void main() {
  late List<bool> flips;

  setUp(() => flips = []);

  // The card is 300 px wide, so half a turn takes a 150 px drag (plus the
  // touch slop the gesture spends before it starts).
  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: FlipCard(
                front: const Text('frente'),
                back: const Text('verso'),
                onFlip: flips.add,
              ),
            ),
          ),
        ),
      );

  Future<void> slowDrag(WidgetTester tester, double dx) async {
    await tester.timedDrag(
      find.byType(FlipCard),
      Offset(dx, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('começa mostrando a frente', (tester) async {
    await pumpCard(tester);

    expect(find.text('frente'), findsOneWidget);
    expect(find.text('verso'), findsNothing);
  });

  testWidgets('arrastar além da metade vira para o verso', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 220);

    expect(find.text('verso'), findsOneWidget);
    expect(find.text('frente'), findsNothing);
    expect(flips, [true]);
  });

  testWidgets('arrastar para a esquerda também vira', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, -220);

    expect(find.text('verso'), findsOneWidget);
    expect(flips, [true]);
  });

  testWidgets('arrasto curto e lento volta para a frente', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 80);

    expect(find.text('frente'), findsOneWidget);
    expect(flips, isEmpty);
  });

  testWidgets('um peteleco rápido vira mesmo sendo curto', (tester) async {
    await pumpCard(tester);

    await tester.fling(find.byType(FlipCard), const Offset(60, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('verso'), findsOneWidget);
    expect(flips, [true]);
  });

  testWidgets('arrastar de novo desvira', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 220);
    await slowDrag(tester, 220);

    expect(find.text('frente'), findsOneWidget);
    expect(flips, [true, false]);
  });

  testWidgets('trocar a key recomeça pela frente', (tester) async {
    await pumpCard(tester);
    await slowDrag(tester, 220);

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: FlipCard(
            key: const ValueKey('outro card'),
            front: const Text('frente'),
            back: const Text('verso'),
          ),
        ),
      ),
    ));

    expect(find.text('frente'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/review/flip_card_test.dart
```

Esperado: FALHA de compilação (`flip_card.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/ui/review/widgets/flip_card.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that turns around its vertical axis, following a horizontal drag.
///
/// Releasing past half a turn, or flinging, completes the flip; anything less
/// springs back. Dragging again flips it back to the front.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.onFlip,
  });

  static const flipDuration = Duration(milliseconds: 250);
  static const flingVelocity = 700.0;

  final Widget front;
  final Widget back;

  /// Called after each completed flip, with true when the back is now showing.
  final ValueChanged<bool>? onFlip;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _angle =
      AnimationController.unbounded(vsync: this);
  bool _showingBack = false;
  double _width = 1;

  double get _restingAngle => _showingBack ? math.pi : 0;

  @override
  void dispose() {
    _angle.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) => _angle.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    final angle = _angle.value + details.delta.dx / _width * math.pi;
    _angle.value =
        angle.clamp(_restingAngle - math.pi, _restingAngle + math.pi);
  }

  void _onDragEnd(DragEndDetails details) {
    final turned = _angle.value - _restingAngle;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final flung = velocity.abs() > FlipCard.flingVelocity &&
        velocity.sign == turned.sign;

    if (turned != 0 && (turned.abs() > math.pi / 2 || flung)) {
      _angle
          .animateTo(
            _restingAngle + turned.sign * math.pi,
            duration: FlipCard.flipDuration,
            curve: Curves.easeOut,
          )
          .orCancel
          .then((_) => _completeFlip(), onError: (Object _) {});
    } else {
      _angle.animateTo(
        _restingAngle,
        duration: FlipCard.flipDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _completeFlip() {
    setState(() => _showingBack = !_showingBack);
    _angle.value = _restingAngle;
    widget.onFlip?.call(_showingBack);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _width = width.isFinite && width > 0 ? width : 1;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _angle,
            builder: (context, _) {
              final angle = _angle.value;
              final backVisible = math.cos(angle) < 0;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: backVisible
                    // Turn the back once more so its content isn't mirrored.
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: widget.back,
                      )
                    : widget.front,
              );
            },
          ),
        );
      },
    );
  }
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/ui/review/flip_card_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/ui/review/widgets/flip_card.dart test/ui/review/flip_card_test.dart
git commit -m "feat: cria o FlipCard, que vira ao arrastar"
```

---

### Tarefa 5: tela de revisão

**Arquivos:**
- Criar: `lib/ui/core/widgets/card_side_view.dart`
- Criar: `lib/ui/review/widgets/review_card_face.dart`
- Criar: `lib/ui/review/widgets/review_screen.dart`
- Testar: `test/ui/review/review_screen_test.dart`

**Interfaces:**
- Consome: `ReviewViewModel` (tarefa 3) e `FlipCard` (tarefa 4).
- Produz:
  - `class CardSideView extends StatelessWidget`, com o construtor `const CardSideView({super.key, String? text})`. **As etapas 4 e 5 acrescentam imagem e áudio.**
  - `class ReviewCardFace extends StatelessWidget`, com o construtor `const ReviewCardFace({super.key, required String label, required int reviewCount, required Widget child})`. O contador fica no canto inferior direito, com a `Key('review-count')`.
  - `class ReviewScreen extends StatefulWidget`, com o construtor `const ReviewScreen({super.key, required String deckName, required ReviewViewModel viewModel})`.

- [ ] **Passo 1: escrever o teste**

`test/ui/review/review_screen_test.dart`:
```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/review/view_models/review_view_model.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';
import 'package:my_flashcards/ui/review/widgets/review_screen.dart';

import '../../fakes/fake_card_repository.dart';

void main() {
  const hint = '⟵ arraste para virar ⟶';
  late FakeCardRepository cards;

  Flashcard card(int id, int reviewCount) => Flashcard(
        id: id,
        deckId: 1,
        front: CardSide(text: 'frente $id'),
        back: CardSide(text: 'verso $id'),
        createdAt: DateTime(2026, 1, id),
        reviewCount: reviewCount,
      );

  Future<void> pumpScreen(WidgetTester tester, List<Flashcard> deck) async {
    cards = FakeCardRepository(deck);
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        deckName: 'Verbos',
        viewModel: ReviewViewModel(
          deckId: 1,
          cardRepository: cards,
          random: Random(1),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> flip(WidgetTester tester) async {
    await tester.fling(find.byType(FlipCard), const Offset(200, 0), 1500);
    await tester.pumpAndSettle();
  }

  String counter(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('review-count'))).data!;

  ButtonStyleButton button(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ));

  testWidgets('mostra o deck, a posição, a frente, o contador e a dica',
      (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3), card(3, 7)]);

    expect(find.text('Verbos'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text('frente 1'), findsOneWidget);
    expect(counter(tester), '0');
    expect(find.text(hint), findsOneWidget);
    expect(button(tester, '‹ Anterior').onPressed, isNull);
  });

  testWidgets('virar mostra o verso e soma uma revisão', (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);

    await flip(tester);

    expect(find.text('Verso'), findsOneWidget);
    expect(find.text('verso 1'), findsOneWidget);
    expect(counter(tester), '1');
    expect(find.text(hint), findsNothing);
  });

  testWidgets('desvirar e virar de novo não conta outra vez', (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);

    await flip(tester);
    await flip(tester);
    await flip(tester);

    expect(counter(tester), '1');
    expect(cards.cards.first.reviewCount, 1);
  });

  testWidgets('Próximo e Anterior trocam de card, sempre pela frente',
      (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);
    await flip(tester);

    await tester.tap(find.text('Próximo ›'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('frente 2'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);

    await tester.tap(find.text('‹ Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('frente 1'), findsOneWidget);

    await flip(tester);
    expect(counter(tester), '1');
  });

  testWidgets('deck com um card já mostra Concluir', (tester) async {
    await pumpScreen(tester, [card(1, 0)]);

    expect(find.text('Concluir'), findsOneWidget);
    expect(button(tester, '‹ Anterior').onPressed, isNull);
  });

  testWidgets('Concluir mostra o resumo, e Revisar de novo recomeça',
      (tester) async {
    await pumpScreen(tester, [card(1, 0), card(2, 3)]);
    await flip(tester);
    await tester.tap(find.text('Próximo ›'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Revisão concluída!'), findsOneWidget);
    expect(find.text('Você revisou 1 de 2 cards.'), findsOneWidget);

    await tester.tap(find.text('Revisar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('falha ao salvar a revisão mostra uma mensagem', (tester) async {
    await pumpScreen(tester, [card(1, 0)]);
    cards.failWith = Exception('disco');

    await flip(tester);

    expect(find.text('Não foi possível salvar a revisão.'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/review/review_screen_test.dart
```

Esperado: FALHA de compilação (`review_screen.dart` não existe).

- [ ] **Passo 3: implementar o `CardSideView`**

`lib/ui/core/widgets/card_side_view.dart`:
```dart
import 'package:flutter/material.dart';

/// The content of one side of a card, centred, scrolling when it is long.
class CardSideView extends StatelessWidget {
  const CardSideView({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text != null)
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Passo 4: implementar o `ReviewCardFace`**

`lib/ui/review/widgets/review_card_face.dart`:
```dart
import 'package:flutter/material.dart';

/// The frame of a card in the review: label on top, review count in the
/// bottom-right corner like a page number.
class ReviewCardFace extends StatelessWidget {
  const ReviewCardFace({
    super.key,
    required this.label,
    required this.reviewCount,
    required this.child,
  });

  final String label;
  final int reviewCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(label, style: muted),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: child,
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '$reviewCount',
                  key: const Key('review-count'),
                  style: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Passo 5: implementar a tela**

`lib/ui/review/widgets/review_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/flashcard.dart';
import '../../core/widgets/card_side_view.dart';
import '../view_models/review_view_model.dart';
import 'flip_card.dart';
import 'review_card_face.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.deckName,
    required this.viewModel,
  });

  final String deckName;
  final ReviewViewModel viewModel;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _hasFlipped = false;

  ReviewViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _onFlip(bool showingBack) async {
    if (!_hasFlipped) setState(() => _hasFlipped = true);
    if (!showingBack) return;
    if (!await _viewModel.markBackSeen() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ReviewViewModel.countErrorMessage)),
      );
    }
  }

  void _restart() {
    setState(() => _hasFlipped = false);
    _viewModel.restart();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final card = _viewModel.current;
        return Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(widget.deckName),
            actions: [
              if (card != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text('${_viewModel.position} / ${_viewModel.total}'),
                  ),
                ),
            ],
          ),
          body: SafeArea(child: _buildBody(card)),
        );
      },
    );
  }

  Widget _buildBody(Flashcard? card) {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadError),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _viewModel.start,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (_viewModel.isFinished) {
      return _FinishedView(
        reviewed: _viewModel.reviewedCount,
        total: _viewModel.total,
        onRestart: _restart,
        onBack: () => Navigator.of(context).pop(),
      );
    }
    if (card == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final showHint = _viewModel.position == 1 && !_hasFlipped;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: FlipCard(
              key: ValueKey((_viewModel.session, card.id)),
              front: ReviewCardFace(
                label: 'Frente',
                reviewCount: card.reviewCount,
                child: CardSideView(text: card.front.text),
              ),
              back: ReviewCardFace(
                label: 'Verso',
                reviewCount: card.reviewCount,
                child: CardSideView(text: card.back.text),
              ),
              onFlip: _onFlip,
            ),
          ),
          SizedBox(
            height: 40,
            child: showHint
                ? Center(
                    child: Text(
                      '⟵ arraste para virar ⟶',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
          ),
          Row(
            children: [
              TextButton(
                onPressed: _viewModel.isFirst ? null : _viewModel.previous,
                child: const Text('‹ Anterior'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _viewModel.next,
                child: Text(_viewModel.isLast ? 'Concluir' : 'Próximo ›'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    required this.reviewed,
    required this.total,
    required this.onRestart,
    required this.onBack,
  });

  final int reviewed;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cards = total == 1 ? 'card' : 'cards';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revisão concluída!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Você revisou $reviewed de $total $cards.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRestart,
              child: const Text('Revisar de novo'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Voltar ao deck')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Passo 6: rodar e ver passar**

```bash
flutter test test/ui/review/review_screen_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 7: commit**

```bash
git add lib/ui/core/widgets/card_side_view.dart lib/ui/review/widgets/review_card_face.dart lib/ui/review/widgets/review_screen.dart test/ui/review/review_screen_test.dart
git commit -m "feat: cria a tela de revisão com contador, botões e fim de sessão"
```

---

### Tarefa 6: botão "Revisar (N)" e rota da revisão

**Arquivos:**
- Modificar: `lib/ui/deck_detail/widgets/deck_detail_screen.dart`
- Modificar: `lib/routes.dart`
- Testar: modificar `test/ui/deck_detail/deck_detail_screen_test.dart` e `test/app_test.dart`

**Interfaces:**
- Consome: `ReviewScreen` e `ReviewViewModel` (tarefas 3 e 5).
- Produz:
  - em `DeckDetailScreen`, o parâmetro novo `required Future<void> Function() onStartReview`. Quando ele termina, a tela recarrega;
  - em `AppRoutes`, o método `Route<void> review({required int deckId, required String deckName})`.

- [ ] **Passo 1: ajustar e acrescentar os testes da tela do deck**

Em `test/ui/deck_detail/deck_detail_screen_test.dart`, troque a função `pumpScreen` por:

```dart
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCardRepository cards, {
    Future<void> Function(int? cardId)? onOpenEditor,
    Future<void> Function()? onStartReview,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: DeckDetailScreen(
        viewModel: DeckDetailViewModel(
          deckId: 1,
          deckRepository: FakeDeckRepository([deck]),
          cardRepository: cards,
        ),
        onOpenEditor: onOpenEditor ?? (_) async {},
        onStartReview: onStartReview ?? () async {},
      ),
    ));
    await tester.pumpAndSettle();
  }
```

E acrescente ao fim do `main()`:

```dart
  testWidgets('Revisar (N) fica desativado sem cards', (tester) async {
    await pumpScreen(tester, FakeCardRepository());

    final button = tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('Revisar (0)'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ));
    expect(button.onPressed, isNull);
  });

  testWidgets('Revisar (N) abre a revisão e recarrega os contadores',
      (tester) async {
    final cards =
        FakeCardRepository([card(1, const CardSide(text: 'to give up'))]);
    await pumpScreen(
      tester,
      cards,
      onStartReview: () async => cards.incrementReviewCount(1),
    );

    await tester.tap(find.text('Revisar (1)'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });
```

Em `test/app_test.dart`:

1. Troque o helper `dependencies` por este, que aceita cards:
```dart
  AppDependencies dependencies({
    List<Deck> decks = const [],
    List<Flashcard> cards = const [],
  }) =>
      AppDependencies(
        decks: FakeDeckRepository(decks),
        cards: FakeCardRepository(cards),
      );
```

2. Acrescente os imports:
```dart
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';
```

3. Acrescente este teste ao fim do `main()`:
```dart
  testWidgets('deck › revisar › virar › concluir › voltar mostra o contador',
      (tester) async {
    await tester.pumpWidget(App(
      dependencies: dependencies(
        decks: [Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026))],
        cards: [
          Flashcard(
            id: 5,
            deckId: 1,
            front: const CardSide(text: 'to give up'),
            back: const CardSide(text: 'desistir'),
            createdAt: DateTime(2026),
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar (1)'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(FlipCard), const Offset(200, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('desistir'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar ao deck'));
    await tester.pumpAndSettle();

    expect(find.text('to give up'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/deck_detail/deck_detail_screen_test.dart test/app_test.dart
```

Esperado: FALHA de compilação (`onStartReview` não existe).

- [ ] **Passo 3: acrescentar o botão à tela do deck**

Em `lib/ui/deck_detail/widgets/deck_detail_screen.dart`:

1. Troque o construtor e os campos da classe `DeckDetailScreen` por:
```dart
  const DeckDetailScreen({
    super.key,
    required this.viewModel,
    required this.onOpenEditor,
    required this.onStartReview,
  });

  final DeckDetailViewModel viewModel;

  /// Opens the card editor for a card, or for a new card when given null.
  final Future<void> Function(int? cardId) onOpenEditor;

  /// Opens the review. The list reloads afterwards to show the new counts.
  final Future<void> Function() onStartReview;
```

2. Em `_DeckDetailScreenState`, acrescente:
```dart
  Future<void> _startReview() async {
    await widget.onStartReview();
    if (mounted) await _viewModel.load();
  }
```

3. Troque o método `_buildBody` inteiro por:
```dart
  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadError),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _viewModel.load,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (_viewModel.isLoading && _viewModel.deck == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final cards = _viewModel.cards;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: cards.isEmpty ? null : _startReview,
              icon: const Icon(Icons.style_outlined),
              label: Text('Revisar (${cards.length})'),
            ),
          ),
        ),
        Expanded(
          child: cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum card ainda. Toque em + para criar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _CardTile(card: cards[index], onTap: _openEditor),
                ),
        ),
      ],
    );
  }
```

- [ ] **Passo 4: acrescentar a rota da revisão**

Em `lib/routes.dart`:

1. Acrescente os imports:
```dart
import 'ui/review/view_models/review_view_model.dart';
import 'ui/review/widgets/review_screen.dart';
```

2. Troque o método `deckDetail` por:
```dart
  Route<void> deckDetail(int deckId) {
    final viewModel = DeckDetailViewModel(
      deckId: deckId,
      deckRepository: _dependencies.decks,
      cardRepository: _dependencies.cards,
    );
    return MaterialPageRoute(
      builder: (context) => DeckDetailScreen(
        viewModel: viewModel,
        onOpenEditor: (cardId) => Navigator.of(context)
            .push(cardEditor(deckId: deckId, cardId: cardId)),
        onStartReview: () => Navigator.of(context).push(
          review(deckId: deckId, deckName: viewModel.deck?.name ?? ''),
        ),
      ),
    );
  }
```

3. Acrescente o método:
```dart
  Route<void> review({required int deckId, required String deckName}) {
    final viewModel = ReviewViewModel(
      deckId: deckId,
      cardRepository: _dependencies.cards,
    );
    return MaterialPageRoute(
      builder: (_) => ReviewScreen(deckName: deckName, viewModel: viewModel),
    );
  }
```

- [ ] **Passo 5: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/deck_detail/widgets/deck_detail_screen.dart lib/routes.dart test/ui/deck_detail/deck_detail_screen_test.dart test/app_test.dart
git commit -m "feat: abre a revisão pelo botão Revisar do deck"
```

---

### Tarefa 7: conferir no celular e fechar a etapa

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

Para testar, crie um deck com 3 cards de texto.

- [ ] **Revisar (3)** abre a revisão com o nome do deck, *"1 / 3"*, a etiqueta *"Frente"* e o contador **0** no canto inferior direito
- [ ] A dica *"⟵ arraste para virar ⟶"* aparece no primeiro card
- [ ] Arrastar devagar faz o card girar acompanhando o dedo. Soltar antes da metade faz ele voltar, e soltar depois da metade completa a virada
- [ ] Um peteleco rápido vira o card
- [ ] Ao mostrar o verso, o contador vira **1**. Desvirar e virar de novo não muda o número
- [ ] O texto do verso não aparece espelhado
- [ ] **Próximo ›** mostra o próximo card pela frente. No último, o botão diz **Concluir**
- [ ] Voltar com **‹ Anterior** e virar de novo não soma
- [ ] **Concluir** mostra *"Revisão concluída! Você revisou X de 3 cards."*
- [ ] **Revisar de novo** recomeça, com os menos revisados primeiro
- [ ] **Voltar ao deck** mostra os contadores atualizados na lista
- [ ] O **✕** e o voltar do Android saem da revisão sem perguntar
- [ ] Começar a girar o card e, sem soltar, puxar a cortina de notificações (ou começar o gesto de voltar na borda e desistir): o card volta ao lado em que estava, e depois ainda vira normalmente
- [ ] A animação fica fluida, sem travadas visíveis

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-3-revisao -m "Etapa 3: revisão" && git branch -d etapa-3-revisao
```

A partir daqui, o app já serve para estudar com cards de texto.
