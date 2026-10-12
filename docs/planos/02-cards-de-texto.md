# Etapa 2: cards de texto. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** abrir um deck, ver os cards dele e criar, editar e excluir cards com texto na frente e no verso.

**Arquitetura:**
- **Modelos:** `CardSide` (um lado do card) e `Flashcard`.
- **Dados:** `CardRepository` grava os cards no SQLite.
- **Telas novas:**
  - tela do deck: `DeckDetailViewModel` e `DeckDetailScreen`;
  - editor: `CardEditorViewModel`, `SideDraft`, `CardEditorScreen` e `SideEditor`.
- **Navegação:** `lib/routes.dart` (`AppRoutes`) cria cada ViewModel uma vez por rota e liga as telas por callbacks.

**Tecnologias:** Flutter 3.47 e `sqflite` 2.4 (sem pacotes novos).

**Spec:** [docs/design.md](../design.md), parte 1 (banco e ViewModels) e parte 2 (telas "Deck" e "Editor de card")

**Branch:** `etapa-2-cards`

## Restrições globais

- As dependências só descem: View → ViewModel → Repository → Service. O ViewModel não recebe `BuildContext` e não navega.
- Os métodos de repositório que podem falhar devolvem `Result<T>`.
- Um lado do card nunca fica vazio. Texto só com espaços conta como vazio.
- O texto é gravado aparado nas pontas. Texto vazio é gravado como `NULL`.
- A lista de cards mostra os mais recentes primeiro.
- A exclusão de um card fica **dentro do editor**, e não na lista.
- Textos da tela em português, exatamente como aqui. Identificadores em inglês.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Lado só com espaços ou quebras de linha.** Conta como vazio: o SALVAR fica desativado e aparece a dica *"Adicione texto, imagem ou áudio"*. Testado nas tarefas 1, 5 e 6.
2. **Frente com várias linhas.** A lista do deck mostra só a primeira linha. Testado na tarefa 4.
3. **Voltar do editor.** Com alterações não salvas, o app pergunta *"Descartar alterações?"*. Sem alterações, ele sai direto. Testado na tarefa 6.
4. **Falha ao salvar.** O editor continua aberto, com o rascunho intacto, e mostra *"Não foi possível salvar. Tente de novo."*. Testado nas tarefas 5 e 6.
5. **Voltar do editor depois de salvar ou excluir.** A lista do deck e a contagem na lista de decks se atualizam. Testado nas tarefas 4 e 7.

---

### Tarefa 1: modelos `CardSide` e `Flashcard`

**Arquivos:**
- Criar: `lib/domain/models/card_side.dart`
- Criar: `lib/domain/models/flashcard.dart`
- Testar: `test/domain/models/card_side_test.dart`

**Interfaces:**
- Produz:
  - `enum Side { front, back }`;
  - `class CardSide`, com:
    - o construtor `const CardSide({String? text, String? image, String? audio})`;
    - a constante `static const empty`;
    - os getters `bool hasText`, `bool isEmpty` e `List<String> fileNames` (os nomes não nulos de imagem e áudio);
    - `==` e `hashCode`.
  - `class Flashcard`, com:
    - o construtor `const Flashcard({required int id, required int deckId, required CardSide front, required CardSide back, required DateTime createdAt, int reviewCount = 0})`;
    - o método `CardSide side(Side side)`;
    - o getter `List<String> fileNames`;
    - o método `Flashcard copyWith({int? reviewCount})`;
    - `==` e `hashCode`.

- [ ] **Passo 1: criar o branch**

```bash
git switch main && git switch -c etapa-2-cards
```

- [ ] **Passo 2: escrever o teste**

`test/domain/models/card_side_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';

void main() {
  group('CardSide', () {
    test('um lado sem nada está vazio', () {
      expect(CardSide.empty.isEmpty, isTrue);
    });

    test('texto só com espaços e quebras de linha conta como vazio', () {
      expect(const CardSide(text: '  \n ').isEmpty, isTrue);
      expect(const CardSide(text: '  \n ').hasText, isFalse);
    });

    test('texto, imagem ou áudio sozinhos já preenchem o lado', () {
      expect(const CardSide(text: 'oi').isEmpty, isFalse);
      expect(const CardSide(image: 'img_1.jpg').isEmpty, isFalse);
      expect(const CardSide(audio: 'aud_1.m4a').isEmpty, isFalse);
    });

    test('fileNames lista só os arquivos que existem', () {
      expect(const CardSide(text: 'oi').fileNames, isEmpty);
      expect(
        const CardSide(image: 'img_1.jpg', audio: 'aud_1.m4a').fileNames,
        ['img_1.jpg', 'aud_1.m4a'],
      );
    });
  });

  group('Flashcard', () {
    final card = Flashcard(
      id: 1,
      deckId: 2,
      front: const CardSide(text: 'to give up', image: 'img_1.jpg'),
      back: const CardSide(text: 'desistir', audio: 'aud_1.m4a'),
      createdAt: DateTime(2026, 10, 12),
    );

    test('side devolve a frente ou o verso', () {
      expect(card.side(Side.front).text, 'to give up');
      expect(card.side(Side.back).text, 'desistir');
    });

    test('fileNames junta os arquivos dos dois lados', () {
      expect(card.fileNames, ['img_1.jpg', 'aud_1.m4a']);
    });

    test('copyWith troca só o contador', () {
      final reviewed = card.copyWith(reviewCount: 5);

      expect(reviewed.reviewCount, 5);
      expect(reviewed.front, card.front);
      expect(reviewed.id, card.id);
    });
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/domain/models/card_side_test.dart
```

Esperado: FALHA de compilação (os modelos não existem).

- [ ] **Passo 4: implementar**

`lib/domain/models/card_side.dart`:
```dart
enum Side { front, back }

class CardSide {
  const CardSide({this.text, this.image, this.audio});

  static const empty = CardSide();

  final String? text;

  /// File name inside the media folder, never a full path.
  final String? image;

  /// File name inside the media folder, never a full path.
  final String? audio;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get isEmpty => !hasText && image == null && audio == null;

  List<String> get fileNames => [?image, ?audio];

  @override
  bool operator ==(Object other) =>
      other is CardSide &&
      other.text == text &&
      other.image == image &&
      other.audio == audio;

  @override
  int get hashCode => Object.hash(text, image, audio);

  @override
  String toString() => 'CardSide(text: $text, image: $image, audio: $audio)';
}
```

`lib/domain/models/flashcard.dart`:
```dart
import 'card_side.dart';

class Flashcard {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.reviewCount = 0,
  });

  final int id;
  final int deckId;
  final CardSide front;
  final CardSide back;
  final int reviewCount;
  final DateTime createdAt;

  CardSide side(Side side) => switch (side) {
        Side.front => front,
        Side.back => back,
      };

  List<String> get fileNames => [...front.fileNames, ...back.fileNames];

  Flashcard copyWith({int? reviewCount}) => Flashcard(
        id: id,
        deckId: deckId,
        front: front,
        back: back,
        createdAt: createdAt,
        reviewCount: reviewCount ?? this.reviewCount,
      );

  @override
  bool operator ==(Object other) =>
      other is Flashcard &&
      other.id == id &&
      other.deckId == deckId &&
      other.front == front &&
      other.back == back &&
      other.reviewCount == reviewCount &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, deckId, front, back, reviewCount, createdAt);

  @override
  String toString() => 'Flashcard($id, deck $deckId, $reviewCount revisões)';
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/domain/models/card_side_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/domain/models/card_side.dart lib/domain/models/flashcard.dart test/domain/models/card_side_test.dart
git commit -m "feat: adiciona os modelos CardSide e Flashcard"
```

---

### Tarefa 2: `CardRepository`

**Arquivos:**
- Criar: `lib/data/repositories/card_repository.dart`
- Testar: `test/data/repositories/card_repository_test.dart`

**Interfaces:**
- Consome: `DatabaseService`, `guard`, `NotFoundException`, `CardSide` e `Flashcard`.
- Produz: `class CardRepository`, com o construtor `CardRepository({required DatabaseService database, DateTime Function()? now})` e os métodos:
  - `Future<Result<List<Flashcard>>> getCards(int deckId)`: os mais recentes primeiro;
  - `Future<Result<Flashcard>> getCard(int id)`: devolve `Error(NotFoundException)` se o card não existir;
  - `Future<Result<Flashcard>> createCard({required int deckId, required CardSide front, required CardSide back})`;
  - `Future<Result<void>> updateCard({required int id, required CardSide front, required CardSide back})`;
  - `Future<Result<void>> deleteCard(int id)`.

- [ ] **Passo 1: escrever o teste**

`test/data/repositories/card_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/card_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late CardRepository repository;
  late int deckId;
  late int otherDeckId;

  setUp(() async {
    database = await openTestDatabase();
    var clock = DateTime(2026, 10, 12, 9);
    repository = CardRepository(
      database: database,
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
    deckId = await database.db.insert('decks', {'name': 'A', 'created_at': 0});
    otherDeckId =
        await database.db.insert('decks', {'name': 'B', 'created_at': 0});
  });
  tearDown(() => database.close());

  test('cria um card com o texto aparado e o contador em zero', () async {
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: '  to give up  '),
      back: const CardSide(text: 'desistir\n'),
    ));

    expect(card.front.text, 'to give up');
    expect(card.back.text, 'desistir');
    expect(card.reviewCount, 0);
    expect(okValue(await repository.getCard(card.id)), card);
  });

  test('texto só com espaços é gravado como nulo', () async {
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: '   ', image: 'img_1.jpg'),
      back: const CardSide(text: 'b'),
    ));

    expect(card.front.text, isNull);
    expect(card.front.image, 'img_1.jpg');
  });

  test('getCards traz só os cards do deck, os mais recentes primeiro',
      () async {
    final first = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'primeiro'),
      back: const CardSide(text: 'x'),
    ));
    await repository.createCard(
      deckId: otherDeckId,
      front: const CardSide(text: 'de outro deck'),
      back: const CardSide(text: 'x'),
    );
    final second = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'segundo'),
      back: const CardSide(text: 'x'),
    ));

    final cards = okValue(await repository.getCards(deckId));

    expect(cards.map((c) => c.id), [second.id, first.id]);
  });

  test('getCard de um id inexistente devolve NotFoundException', () async {
    final result = await repository.getCard(999);

    expect(
      result,
      isA<Error<dynamic>>()
          .having((r) => r.error, 'error', isA<NotFoundException>()),
    );
  });

  test('updateCard troca a frente e o verso e mantém o contador', () async {
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'a'),
      back: const CardSide(text: 'b'),
    ));
    await database.db.update('cards', {'review_count': 3});

    okValue(await repository.updateCard(
      id: card.id,
      front: const CardSide(text: 'novo a'),
      back: const CardSide(text: 'novo b'),
    ));

    final updated = okValue(await repository.getCard(card.id));
    expect(updated.front.text, 'novo a');
    expect(updated.back.text, 'novo b');
    expect(updated.reviewCount, 3);
  });

  test('updateCard de um id inexistente devolve erro', () async {
    final result = await repository.updateCard(
      id: 999,
      front: const CardSide(text: 'a'),
      back: const CardSide(text: 'b'),
    );

    expect(result, isA<Error<void>>());
  });

  test('deleteCard apaga o card', () async {
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'a'),
      back: const CardSide(text: 'b'),
    ));

    okValue(await repository.deleteCard(card.id));

    expect(okValue(await repository.getCards(deckId)), isEmpty);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/card_repository_test.dart
```

Esperado: FALHA de compilação (`card_repository.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/data/repositories/card_repository.dart`:
```dart
import '../../domain/models/card_side.dart';
import '../../domain/models/flashcard.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';

class CardRepository {
  CardRepository({
    required DatabaseService database,
    DateTime Function()? now,
  })  : _database = database,
        _now = now ?? DateTime.now;

  final DatabaseService _database;
  final DateTime Function() _now;

  Future<Result<List<Flashcard>>> getCards(int deckId) => guard(() async {
        final rows = await _database.db.query(
          'cards',
          where: 'deck_id = ?',
          whereArgs: [deckId],
          orderBy: 'created_at DESC, id DESC',
        );
        return rows.map(_cardFromRow).toList();
      });

  Future<Result<Flashcard>> getCard(int id) =>
      guard(() async => _cardFromRow(await _findRow(id)));

  Future<Result<Flashcard>> createCard({
    required int deckId,
    required CardSide front,
    required CardSide back,
  }) =>
      guard(() async {
        final id = await _database.db.insert('cards', {
          'deck_id': deckId,
          ..._sideToRow('front', front),
          ..._sideToRow('back', back),
          'created_at': _now().millisecondsSinceEpoch,
        });
        return _cardFromRow(await _findRow(id));
      });

  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) =>
      guard(() async {
        final updated = await _database.db.update(
          'cards',
          {..._sideToRow('front', front), ..._sideToRow('back', back)},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (updated == 0) throw NotFoundException('O card $id não existe.');
      });

  Future<Result<void>> deleteCard(int id) => guard(() async {
        await _database.db.delete('cards', where: 'id = ?', whereArgs: [id]);
      });

  Future<Map<String, Object?>> _findRow(int id) async {
    final rows =
        await _database.db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw NotFoundException('O card $id não existe.');
    return rows.single;
  }
}

Map<String, Object?> _sideToRow(String prefix, CardSide side) => {
      '${prefix}_text': side.hasText ? side.text!.trim() : null,
      '${prefix}_image': side.image,
      '${prefix}_audio': side.audio,
    };

CardSide _sideFromRow(String prefix, Map<String, Object?> row) => CardSide(
      text: row['${prefix}_text'] as String?,
      image: row['${prefix}_image'] as String?,
      audio: row['${prefix}_audio'] as String?,
    );

Flashcard _cardFromRow(Map<String, Object?> row) => Flashcard(
      id: row['id']! as int,
      deckId: row['deck_id']! as int,
      front: _sideFromRow('front', row),
      back: _sideFromRow('back', row),
      reviewCount: row['review_count']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    );
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/data/repositories/card_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/data/repositories/card_repository.dart test/data/repositories/card_repository_test.dart
git commit -m "feat: cria o CardRepository"
```

---

### Tarefa 3: `DeckDetailViewModel`

**Arquivos:**
- Criar: `lib/ui/deck_detail/view_models/deck_detail_view_model.dart`
- Criar: `test/fakes/fake_card_repository.dart`
- Testar: `test/ui/deck_detail/deck_detail_view_model_test.dart`

**Interfaces:**
- Consome: `DeckRepository.getDeck` e `CardRepository.getCards`.
- Produz:
  - `class DeckDetailViewModel extends ChangeNotifier`, com:
    - o construtor `DeckDetailViewModel({required int deckId, required DeckRepository deckRepository, required CardRepository cardRepository})`;
    - os getters `int deckId`, `Deck? deck`, `List<Flashcard> cards`, `bool isLoading` e `String? loadError`;
    - o método `Future<void> load()`;
    - a constante `static const loadErrorMessage`.
  - Nos testes: `FakeCardRepository([List<Flashcard> cards])`, com `Exception? failWith` e `List<Flashcard> cards`.

- [ ] **Passo 1: escrever o repositório falso**

`test/fakes/fake_card_repository.dart`:
```dart
import 'package:my_flashcards/data/repositories/card_repository.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/utils/result.dart';

/// In-memory [CardRepository]. Set [failWith] to make every call fail.
class FakeCardRepository implements CardRepository {
  FakeCardRepository([List<Flashcard> cards = const []]) : _cards = [...cards];

  final List<Flashcard> _cards;
  Exception? failWith;
  var _nextId = 1000;

  List<Flashcard> get cards => List.unmodifiable(_cards);

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    return Result.ok(compute());
  }

  int _indexOf(int id) {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index < 0) throw NotFoundException('O card $id não existe.');
    return index;
  }

  @override
  Future<Result<List<Flashcard>>> getCards(int deckId) => _answer(
        () => _cards.where((c) => c.deckId == deckId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<Result<Flashcard>> getCard(int id) async {
    if (failWith != null) return Result.error(failWith!);
    final index = _cards.indexWhere((c) => c.id == id);
    if (index < 0) return Result.error(NotFoundException('card $id'));
    return Result.ok(_cards[index]);
  }

  @override
  Future<Result<Flashcard>> createCard({
    required int deckId,
    required CardSide front,
    required CardSide back,
  }) =>
      _answer(() {
        final card = Flashcard(
          id: _nextId++,
          deckId: deckId,
          front: front,
          back: back,
          createdAt: DateTime(2026, 10, 12).add(Duration(minutes: _nextId)),
        );
        _cards.add(card);
        return card;
      });

  @override
  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) =>
      _answer(() {
        final index = _indexOf(id);
        final old = _cards[index];
        _cards[index] = Flashcard(
          id: id,
          deckId: old.deckId,
          front: front,
          back: back,
          createdAt: old.createdAt,
          reviewCount: old.reviewCount,
        );
      });

  @override
  Future<Result<void>> deleteCard(int id) =>
      _answer(() => _cards.removeAt(_indexOf(id)));
}
```

- [ ] **Passo 2: escrever o teste**

`test/ui/deck_detail/deck_detail_view_model_test.dart`:
```dart
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
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/ui/deck_detail/deck_detail_view_model_test.dart
```

Esperado: FALHA de compilação (`deck_detail_view_model.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/ui/deck_detail/view_models/deck_detail_view_model.dart`:
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../domain/models/deck.dart';
import '../../../domain/models/flashcard.dart';
import '../../../utils/result.dart';

class DeckDetailViewModel extends ChangeNotifier {
  DeckDetailViewModel({
    required this.deckId,
    required DeckRepository deckRepository,
    required CardRepository cardRepository,
  })  : _deckRepository = deckRepository,
        _cardRepository = cardRepository;

  static const loadErrorMessage = 'Não foi possível carregar o deck.';

  final int deckId;
  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;

  Deck? _deck;
  List<Flashcard> _cards = const [];
  bool _isLoading = false;
  String? _loadError;

  Deck? get deck => _deck;
  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    final deckResult = await _deckRepository.getDeck(deckId);
    final cardsResult = await _cardRepository.getCards(deckId);
    switch ((deckResult, cardsResult)) {
      case (Ok(value: final deck), Ok(value: final cards)):
        _deck = deck;
        _cards = cards;
      default:
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/deck_detail/deck_detail_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/deck_detail/view_models test/fakes/fake_card_repository.dart test/ui/deck_detail/deck_detail_view_model_test.dart
git commit -m "feat: cria o DeckDetailViewModel"
```

---

### Tarefa 4: tela do deck

**Arquivos:**
- Criar: `lib/ui/deck_detail/widgets/deck_detail_screen.dart`
- Testar: `test/ui/deck_detail/deck_detail_screen_test.dart`

**Interfaces:**
- Consome: `DeckDetailViewModel` (tarefa 3).
- Produz:
  - `class DeckDetailScreen extends StatefulWidget`, com o construtor `const DeckDetailScreen({super.key, required DeckDetailViewModel viewModel, required Future<void> Function(int? cardId) onOpenEditor})`.
    - `onOpenEditor(null)` abre o editor para um card novo.
    - Quando `onOpenEditor` termina, a tela chama `viewModel.load()`.
    - A tela chama `viewModel.dispose()` no `dispose`.
  - A função `String cardPreview(CardSide side)`.

- [ ] **Passo 1: escrever o teste**

`test/ui/deck_detail/deck_detail_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';
import 'package:my_flashcards/ui/deck_detail/view_models/deck_detail_view_model.dart';
import 'package:my_flashcards/ui/deck_detail/widgets/deck_detail_screen.dart';

import '../../fakes/fake_card_repository.dart';
import '../../fakes/fake_deck_repository.dart';

void main() {
  final deck = Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026));

  Flashcard card(int id, CardSide front, {int reviewCount = 0}) => Flashcard(
        id: id,
        deckId: 1,
        front: front,
        back: const CardSide(text: 'verso'),
        createdAt: DateTime(2026, 1, id),
        reviewCount: reviewCount,
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCardRepository cards, {
    Future<void> Function(int? cardId)? onOpenEditor,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: DeckDetailScreen(
        viewModel: DeckDetailViewModel(
          deckId: 1,
          deckRepository: FakeDeckRepository([deck]),
          cardRepository: cards,
        ),
        onOpenEditor: onOpenEditor ?? (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o nome do deck e a mensagem de lista vazia',
      (tester) async {
    await pumpScreen(tester, FakeCardRepository());

    expect(find.text('Verbos'), findsOneWidget);
    expect(find.text('Nenhum card ainda. Toque em + para criar.'),
        findsOneWidget);
  });

  testWidgets('lista os cards mais recentes primeiro, com o contador',
      (tester) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(text: 'antigo'), reviewCount: 7),
        card(2, const CardSide(text: 'novo'), reviewCount: 12),
      ]),
    );

    final antigo = tester.getTopLeft(find.text('antigo'));
    final novo = tester.getTopLeft(find.text('novo'));
    expect(novo.dy, lessThan(antigo.dy));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('mostra só a primeira linha da frente', (tester) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(text: 'primeira linha\nsegunda linha')),
      ]),
    );

    expect(find.text('primeira linha'), findsOneWidget);
    expect(find.textContaining('segunda linha'), findsNothing);
  });

  testWidgets('frente sem texto mostra (só imagem) ou (só áudio)',
      (tester) async {
    await pumpScreen(
      tester,
      FakeCardRepository([
        card(1, const CardSide(image: 'img_1.jpg')),
        card(2, const CardSide(audio: 'aud_1.m4a')),
      ]),
    );

    expect(find.text('(só imagem)'), findsOneWidget);
    expect(find.text('(só áudio)'), findsOneWidget);
  });

  testWidgets('tocar num card abre o editor dele', (tester) async {
    final opened = <int?>[];
    await pumpScreen(
      tester,
      FakeCardRepository([card(5, const CardSide(text: 'to give up'))]),
      onOpenEditor: (id) async => opened.add(id),
    );

    await tester.tap(find.text('to give up'));
    await tester.pumpAndSettle();

    expect(opened, [5]);
  });

  testWidgets('o + abre o editor de um card novo e recarrega ao voltar',
      (tester) async {
    final cards = FakeCardRepository();
    await pumpScreen(
      tester,
      cards,
      onOpenEditor: (id) async {
        expect(id, isNull);
        await cards.createCard(
          deckId: 1,
          front: const CardSide(text: 'criado no editor'),
          back: const CardSide(text: 'x'),
        );
      },
    );

    await tester.tap(find.byTooltip('Novo card'));
    await tester.pumpAndSettle();

    expect(find.text('criado no editor'), findsOneWidget);
  });

  testWidgets('falha ao carregar mostra erro e permite tentar de novo',
      (tester) async {
    final cards = FakeCardRepository()..failWith = Exception('disco');
    await pumpScreen(tester, cards);

    expect(find.text('Não foi possível carregar o deck.'), findsOneWidget);

    cards.failWith = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum card ainda. Toque em + para criar.'),
        findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/deck_detail/deck_detail_screen_test.dart
```

Esperado: FALHA de compilação (`deck_detail_screen.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/ui/deck_detail/widgets/deck_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../../../domain/models/flashcard.dart';
import '../view_models/deck_detail_view_model.dart';

String cardPreview(CardSide side) {
  if (side.hasText) return side.text!.trim().split('\n').first;
  if (side.image != null) return '(só imagem)';
  return '(só áudio)';
}

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({
    super.key,
    required this.viewModel,
    required this.onOpenEditor,
  });

  final DeckDetailViewModel viewModel;

  /// Opens the card editor for a card, or for a new card when given null.
  final Future<void> Function(int? cardId) onOpenEditor;

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  DeckDetailViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openEditor(int? cardId) async {
    await widget.onOpenEditor(cardId);
    if (mounted) await _viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_viewModel.deck?.name ?? '')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(null),
          tooltip: 'Novo card',
          child: const Icon(Icons.add),
        ),
        body: _buildBody(),
      ),
    );
  }

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
    if (_viewModel.cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhum card ainda. Toque em + para criar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _viewModel.cards.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _CardTile(
        card: _viewModel.cards[index],
        onTap: _openEditor,
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});

  final Flashcard card;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        cardPreview(card.front),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.front.image != null)
            const Icon(Icons.image_outlined, size: 18, semanticLabel: 'Imagem'),
          if (card.front.audio != null)
            const Icon(Icons.volume_up_outlined, size: 18, semanticLabel: 'Áudio'),
          const SizedBox(width: 12),
          Text('${card.reviewCount}'),
        ],
      ),
      onTap: () => onTap(card.id),
    );
  }
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/ui/deck_detail/deck_detail_screen_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/ui/deck_detail/widgets test/ui/deck_detail/deck_detail_screen_test.dart
git commit -m "feat: cria a tela do deck com a lista de cards"
```

---

### Tarefa 5: `SideDraft` e `CardEditorViewModel` (texto)

**Arquivos:**
- Criar: `lib/ui/card_editor/view_models/side_draft.dart`
- Criar: `lib/ui/card_editor/view_models/card_editor_view_model.dart`
- Testar: `test/ui/card_editor/card_editor_view_model_test.dart`

**Interfaces:**
- Consome: `CardRepository.getCard`, `createCard`, `updateCard` e `deleteCard`; `CardSide` e `Side`.
- Produz:
  - `class SideDraft`, com:
    - o construtor `const SideDraft({String text = ''})`;
    - o factory `SideDraft.fromCardSide(CardSide side)`;
    - o campo `String text` e o getter `bool isEmpty`;
    - os métodos `SideDraft withText(String text)` e `CardSide toCardSide()`;
    - `==` e `hashCode`.
    - **As etapas 4 e 5 acrescentam imagem e áudio.**
  - `class CardEditorViewModel extends ChangeNotifier`, com:
    - o construtor `CardEditorViewModel({required int deckId, int? cardId, required CardRepository cardRepository})`;
    - os getters `bool isNew`, `bool isLoading`, `bool isSaving`, `String? loadError`, `String? actionError`, `bool hasChanges` e `bool canSave`;
    - os métodos `SideDraft draft(Side side)`, `Future<void> load()`, `void setText(Side side, String text)`, `Future<bool> save()` e `Future<bool> deleteCard()`;
    - as constantes `loadErrorMessage`, `saveErrorMessage` e `deleteErrorMessage`.

- [ ] **Passo 1: escrever o teste**

`test/ui/card_editor/card_editor_view_model_test.dart`:
```dart
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
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/card_editor/card_editor_view_model_test.dart
```

Esperado: FALHA de compilação (os arquivos do editor não existem).

- [ ] **Passo 3: implementar o `SideDraft`**

`lib/ui/card_editor/view_models/side_draft.dart`:
```dart
import '../../../domain/models/card_side.dart';

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = ''});

  factory SideDraft.fromCardSide(CardSide side) =>
      SideDraft(text: side.text ?? '');

  final String text;

  bool get isEmpty => text.trim().isEmpty;

  SideDraft withText(String text) => SideDraft(text: text);

  CardSide toCardSide() => CardSide(text: isEmpty ? null : text.trim());

  @override
  bool operator ==(Object other) => other is SideDraft && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
```

- [ ] **Passo 4: implementar o `CardEditorViewModel`**

`lib/ui/card_editor/view_models/card_editor_view_model.dart`:
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../utils/result.dart';
import 'side_draft.dart';

class CardEditorViewModel extends ChangeNotifier {
  CardEditorViewModel({
    required this.deckId,
    this.cardId,
    required CardRepository cardRepository,
  }) : _cardRepository = cardRepository;

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';

  final int deckId;
  final int? cardId;
  final CardRepository _cardRepository;

  SideDraft _front = const SideDraft();
  SideDraft _back = const SideDraft();
  SideDraft _initialFront = const SideDraft();
  SideDraft _initialBack = const SideDraft();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;
  String? _actionError;

  bool get isNew => cardId == null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  bool get hasChanges => _front != _initialFront || _back != _initialBack;

  bool get canSave =>
      !_isLoading &&
      !_isSaving &&
      _loadError == null &&
      !_front.isEmpty &&
      !_back.isEmpty;

  SideDraft draft(Side side) => switch (side) {
        Side.front => _front,
        Side.back => _back,
      };

  Future<void> load() async {
    final id = cardId;
    if (id == null) return;
    _isLoading = true;
    notifyListeners();

    switch (await _cardRepository.getCard(id)) {
      case Ok(value: final card):
        _front = _initialFront = SideDraft.fromCardSide(card.front);
        _back = _initialBack = SideDraft.fromCardSide(card.back);
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setText(Side side, String text) =>
      _setDraft(side, draft(side).withText(text));

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();

    final front = _front.toCardSide();
    final back = _back.toCardSide();
    final id = cardId;
    final result = id == null
        ? await _cardRepository.createCard(
            deckId: deckId, front: front, back: back)
        : await _cardRepository.updateCard(id: id, front: front, back: back);

    _isSaving = false;
    if (result is Error) {
      _actionError = saveErrorMessage;
      notifyListeners();
      return false;
    }
    _initialFront = _front;
    _initialBack = _back;
    notifyListeners();
    return true;
  }

  Future<bool> deleteCard() async {
    final id = cardId;
    if (id == null) return false;
    if (await _cardRepository.deleteCard(id) is Error) {
      _actionError = deleteErrorMessage;
      notifyListeners();
      return false;
    }
    return true;
  }

  void _setDraft(Side side, SideDraft value) {
    switch (side) {
      case Side.front:
        _front = value;
      case Side.back:
        _back = value;
    }
    notifyListeners();
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/card_editor/card_editor_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/card_editor/view_models test/ui/card_editor/card_editor_view_model_test.dart
git commit -m "feat: cria o CardEditorViewModel para cards de texto"
```

---

### Tarefa 6: tela do editor de card

**Arquivos:**
- Criar: `lib/ui/card_editor/widgets/side_editor.dart`
- Criar: `lib/ui/card_editor/widgets/card_editor_screen.dart`
- Testar: `test/ui/card_editor/card_editor_screen_test.dart`

**Interfaces:**
- Consome: `CardEditorViewModel` (tarefa 5).
- Produz:
  - `class SideEditor extends StatelessWidget`, com o construtor `const SideEditor({super.key, required String label, required TextEditingController controller, required bool isEmpty, required ValueChanged<String> onTextChanged})`. **As etapas 4 e 5 acrescentam parâmetros.**
  - `class CardEditorScreen extends StatefulWidget`, com o construtor `const CardEditorScreen({super.key, required CardEditorViewModel viewModel})`. A tela:
    - devolve `true` com `Navigator.pop` quando salva ou exclui;
    - devolve `false` quando a usuária descarta as alterações;
    - devolve `null` quando a usuária volta sem ter alterado nada.

- [ ] **Passo 1: escrever o teste**

`test/ui/card_editor/card_editor_screen_test.dart`:
```dart
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
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => CardEditorScreen(viewModel: viewModel),
                )),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'SALVAR'));

  Finder textField(int index) => find.byType(TextField).at(index);

  testWidgets('card novo: SALVAR só ativa com os dois lados preenchidos',
      (tester) async {
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

  testWidgets('voltar com alterações pergunta antes de descartar',
      (tester) async {
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

  testWidgets('falha ao salvar mostra a mensagem e continua no editor',
      (tester) async {
    await openEditor(tester, cardId: 7);
    await tester.enterText(textField(1), 'largar');
    cards.failWith = Exception('disco');

    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível salvar. Tente de novo.'), findsOneWidget);
    expect(find.text('Editar card'), findsOneWidget);
    expect(find.text('largar'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/card_editor/card_editor_screen_test.dart
```

Esperado: FALHA de compilação (`card_editor_screen.dart` não existe).

- [ ] **Passo 3: implementar o `SideEditor`**

`lib/ui/card_editor/widgets/side_editor.dart`:
```dart
import 'package:flutter/material.dart';

class SideEditor extends StatelessWidget {
  const SideEditor({
    super.key,
    required this.label,
    required this.controller,
    required this.isEmpty,
    required this.onTextChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onTextChanged,
          minLines: 1,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Texto',
            border: OutlineInputBorder(),
          ),
        ),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Adicione texto, imagem ou áudio',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Passo 4: implementar a tela**

`lib/ui/card_editor/widgets/card_editor_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../view_models/card_editor_view_model.dart';
import 'side_editor.dart';

class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.viewModel});

  final CardEditorViewModel viewModel;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _frontText = TextEditingController();
  final _backText = TextEditingController();

  CardEditorViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _viewModel.load();
    if (!mounted) return;
    _frontText.text = _viewModel.draft(Side.front).text;
    _backText.text = _viewModel.draft(Side.back).text;
  }

  @override
  void dispose() {
    _frontText.dispose();
    _backText.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showActionError() {
    final message = _viewModel.actionError;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (await _viewModel.save()) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _showActionError();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir este card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (await _viewModel.deleteCard()) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _showActionError();
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => PopScope<bool>(
        canPop: !_viewModel.hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_viewModel.isNew ? 'Novo card' : 'Editar card'),
            actions: [
              if (!_viewModel.isNew)
                IconButton(
                  onPressed: _delete,
                  tooltip: 'Excluir card',
                  icon: const Icon(Icons.delete_outline),
                ),
              TextButton(
                onPressed: _viewModel.canSave ? _save : null,
                child: const Text('SALVAR'),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) return Center(child: Text(loadError));
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sideEditor(Side.front, 'FRENTE', _frontText),
        const Divider(height: 32),
        _sideEditor(Side.back, 'VERSO', _backText),
      ],
    );
  }

  Widget _sideEditor(
    Side side,
    String label,
    TextEditingController controller,
  ) {
    return SideEditor(
      label: label,
      controller: controller,
      isEmpty: _viewModel.draft(side).isEmpty,
      onTextChanged: (text) => _viewModel.setText(side, text),
    );
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/card_editor/card_editor_screen_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/card_editor/widgets test/ui/card_editor/card_editor_screen_test.dart
git commit -m "feat: cria a tela do editor de card com texto"
```

---

### Tarefa 7: rotas e navegação entre as telas

**Arquivos:**
- Criar: `lib/routes.dart`
- Modificar: `lib/app_dependencies.dart`, `lib/app.dart` e `lib/ui/deck_list/widgets/deck_list_screen.dart`
- Testar: modificar `test/ui/deck_list/deck_list_screen_test.dart` e `test/app_test.dart`

**Interfaces:**
- Consome: as telas e os ViewModels das tarefas 3 a 6.
- Produz:
  - `class AppRoutes`, com o construtor `const AppRoutes(AppDependencies dependencies)` e os métodos `Route<void> deckDetail(int deckId)` e `Route<bool> cardEditor({required int deckId, int? cardId})`;
  - em `AppDependencies`, o campo novo `final CardRepository cards`, com construtor `AppDependencies({required this.decks, required this.cards})`;
  - em `DeckListScreen`, o parâmetro novo `required Future<void> Function(Deck deck) onOpenDeck`. Quando ele termina, a tela recarrega a lista.

- [ ] **Passo 1: ajustar os testes da lista de decks e escrever o teste novo**

Em `test/ui/deck_list/deck_list_screen_test.dart`, troque a função `pumpScreen` por esta, que aceita o callback:

```dart
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDeckRepository repository, {
    Future<void> Function(Deck deck)? onOpenDeck,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: DeckListScreen(
        viewModel: DeckListViewModel(deckRepository: repository),
        onOpenDeck: onOpenDeck ?? (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }
```

E acrescente este teste no fim do `main()`:

```dart
  testWidgets('tocar num deck abre o deck e recarrega ao voltar',
      (tester) async {
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
```

`test/app_test.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';
import 'package:my_flashcards/app_dependencies.dart';
import 'package:my_flashcards/domain/models/deck.dart';

import 'fakes/fake_card_repository.dart';
import 'fakes/fake_deck_repository.dart';

void main() {
  AppDependencies dependencies({List<Deck> decks = const []}) =>
      AppDependencies(
        decks: FakeDeckRepository(decks),
        cards: FakeCardRepository(),
      );

  testWidgets('abre na lista de decks, seguindo o tema do sistema',
      (tester) async {
    await tester.pumpWidget(App(dependencies: dependencies()));
    await tester.pumpAndSettle();

    expect(find.text('My Flashcards'), findsOneWidget);
    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('deck › novo card › salvar volta para o deck com o card',
      (tester) async {
    await tester.pumpWidget(App(
      dependencies: dependencies(
        decks: [Deck(id: 1, name: 'Verbos', createdAt: DateTime(2026))],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'to give up');
    await tester.enterText(find.byType(TextField).at(1), 'desistir');
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(find.text('Verbos'), findsOneWidget);
    expect(find.text('to give up'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/deck_list/deck_list_screen_test.dart test/app_test.dart
```

Esperado: FALHA de compilação (`onOpenDeck` e `cards` não existem).

- [ ] **Passo 3: acrescentar `onOpenDeck` à `DeckListScreen`**

Em `lib/ui/deck_list/widgets/deck_list_screen.dart`:

1. Troque o construtor e os campos da classe `DeckListScreen` por:
```dart
  const DeckListScreen({
    super.key,
    required this.viewModel,
    required this.onOpenDeck,
  });

  final DeckListViewModel viewModel;

  /// Opens a deck. The list reloads when it completes, because the user may
  /// have added or removed cards meanwhile.
  final Future<void> Function(Deck deck) onOpenDeck;
```

2. Em `_DeckListScreenState`, acrescente este método:
```dart
  Future<void> _openDeck(Deck deck) async {
    await widget.onOpenDeck(deck);
    if (mounted) await _viewModel.load();
  }
```

3. No `ListTile` do `itemBuilder`, acrescente:
```dart
          onTap: () => _openDeck(deck),
```

- [ ] **Passo 4: acrescentar o `CardRepository` às dependências**

`lib/app_dependencies.dart` (substitui o arquivo inteiro):
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/services/database_service.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({required this.decks, required this.cards});

  final DeckRepository decks;
  final CardRepository cards;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    return AppDependencies(
      decks: DeckRepository(database: database),
      cards: CardRepository(database: database),
    );
  }
}
```

- [ ] **Passo 5: criar as rotas**

`lib/routes.dart`:
```dart
import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'ui/card_editor/view_models/card_editor_view_model.dart';
import 'ui/card_editor/widgets/card_editor_screen.dart';
import 'ui/deck_detail/view_models/deck_detail_view_model.dart';
import 'ui/deck_detail/widgets/deck_detail_screen.dart';

/// Builds every route of the app. Each ViewModel is created here, once per
/// route, and handed to its screen, which disposes it.
class AppRoutes {
  const AppRoutes(this._dependencies);

  final AppDependencies _dependencies;

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
      ),
    );
  }

  Route<bool> cardEditor({required int deckId, int? cardId}) {
    final viewModel = CardEditorViewModel(
      deckId: deckId,
      cardId: cardId,
      cardRepository: _dependencies.cards,
    );
    return MaterialPageRoute(
      builder: (_) => CardEditorScreen(viewModel: viewModel),
    );
  }
}
```

- [ ] **Passo 6: usar as rotas no `App`**

`lib/app.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'routes.dart';
import 'ui/core/theme.dart';
import 'ui/deck_list/view_models/deck_list_view_model.dart';
import 'ui/deck_list/widgets/deck_list_screen.dart';

class App extends StatefulWidget {
  const App({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final _routes = AppRoutes(widget.dependencies);
  late final _deckListViewModel =
      DeckListViewModel(deckRepository: widget.dependencies.decks);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Flashcards',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) => DeckListScreen(
          viewModel: _deckListViewModel,
          onOpenDeck: (deck) =>
              Navigator.of(context).push(_routes.deckDetail(deck.id)),
        ),
      ),
    );
  }
}
```

- [ ] **Passo 7: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 8: commit**

```bash
git add lib/routes.dart lib/app.dart lib/app_dependencies.dart lib/ui/deck_list/widgets/deck_list_screen.dart test/ui/deck_list/deck_list_screen_test.dart test/app_test.dart
git commit -m "feat: liga lista de decks, deck e editor pela navegação"
```

---

### Tarefa 8: conferir no celular e fechar a etapa

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

- [ ] Tocar num deck abre a tela dele, com *"Nenhum card ainda. Toque em + para criar."*
- [ ] O **+** abre "Novo card". O SALVAR fica cinza até os dois lados terem texto
- [ ] Salvar volta ao deck, e o card aparece no topo da lista com o contador **0**
- [ ] Um card com a frente em várias linhas mostra só a primeira na lista
- [ ] Tocar no card abre "Editar card" com os textos. Mudar e salvar atualiza a lista
- [ ] Mudar um texto e apertar o voltar do Android pergunta *"Descartar alterações?"*
- [ ] O 🗑 no editor pede confirmação e apaga o card
- [ ] Ao voltar para a lista de decks, a contagem de cards está certa

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-2-cards -m "Etapa 2: cards de texto" && git branch -d etapa-2-cards
```
