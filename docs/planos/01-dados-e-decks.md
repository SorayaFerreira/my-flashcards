# Etapa 1: dados e decks. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** criar a base de dados do app (SQLite com o schema v1) e a tela inicial de decks, onde se cria, renomeia e exclui decks.

**Arquitetura:** primeira fatia do MVVM, com estas peças:
- `DatabaseService` (Service) abre o SQLite;
- `DeckRepository` (Repository) devolve `Result<T>`;
- `DeckListViewModel` (`ChangeNotifier`) guarda o estado da tela;
- `DeckListScreen` (View) desenha a tela.

`AppDependencies` cria tudo uma vez, em `main.dart`.

**Tecnologias:** Flutter 3.47, `sqflite` 2.4, `path` 1.9 e `sqflite_common_ffi` 2.4 (só nos testes).

**Spec:** [docs/design.md](../design.md), parte 1 (arquitetura e dados) e parte 2 (tela "Lista de decks" e "Visual")

**Branch:** `etapa-1-decks`

## Restrições globais

- As dependências só descem: View → ViewModel → Repository → Service. O ViewModel nunca recebe `BuildContext` e nunca navega.
- Os métodos de repositório que podem falhar devolvem `Result<T>`. Exceções nunca chegam à tela.
- Identificadores em inglês. Textos da tela em português, exatamente como estão aqui.
- O nome do deck passa por `trim`, não pode ficar vazio e tem no máximo 50 caracteres. Nomes repetidos são permitidos.
- Os decks aparecem em ordem alfabética, sem diferenciar maiúsculas de minúsculas.
- O banco liga `PRAGMA foreign_keys = ON` toda vez que abre.
- Tema: Material 3, com primária `#C52DC3` no claro e `#F05BD3` no escuro, seguindo o sistema.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Nome só com espaços, ou com mais de 50 caracteres.** O botão Criar ou Salvar fica desativado, e o campo não aceita mais de 50 caracteres. Testado na tarefa 6.
2. **Maiúsculas e minúsculas na ordem.** "Abacate", "banana" e "Cereja" aparecem nessa ordem, e não com as maiúsculas primeiro. Testado na tarefa 4.
3. **Excluir um deck que tem cards.** Os cards também somem do banco, o que só funciona com as chaves estrangeiras ligadas. Testado nas tarefas 3 e 4.
4. **Falha ao ler o banco.** A tela mostra *"Não foi possível carregar os decks."* e um botão "Tentar de novo", em vez de travar ou ficar em branco. Testado nas tarefas 5 e 6.
5. **Espaços nas pontas do nome.** "  Inglês  " é salvo como "Inglês", tanto ao criar quanto ao renomear. Testado na tarefa 4.

---

### Tarefa 1: `Result<T>` e `guard`

**Arquivos:**
- Criar: `lib/utils/result.dart`
- Testar: `test/utils/result_test.dart`
- Criar: `test/helpers/result.dart` (ajuda os testes a abrir um `Ok`)

**Interfaces:**
- Produz:
  - `sealed class Result<T>`, com `Result.ok(T value)` e `Result.error(Exception error)`;
  - as subclasses `Ok<T>` (`.value`) e `Error<T>` (`.error`);
  - `Future<Result<T>> guard<T>(Future<T> Function() action)`;
  - `class NotFoundException implements Exception`, com `const NotFoundException(String message)`;
  - nos testes: `T okValue<T>(Result<T> result)`.

- [ ] **Passo 1: criar o branch e adicionar os pacotes**

```bash
git switch main && git switch -c etapa-1-decks
flutter pub add sqflite path
flutter pub add dev:sqflite_common_ffi
```

- [ ] **Passo 2: escrever o teste**

`test/utils/result_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/utils/result.dart';

void main() {
  test('guard devolve Ok com o valor da ação', () async {
    final result = await guard(() async => 42);

    expect(result, isA<Ok<int>>().having((r) => r.value, 'value', 42));
  });

  test('guard devolve Error quando a ação lança uma Exception', () async {
    final result = await guard<int>(
      () async => throw const FormatException('arquivo ruim'),
    );

    expect(
      result,
      isA<Error<int>>().having((r) => r.error, 'error', isA<FormatException>()),
    );
  });

  test('guard deixa passar erros de programação', () {
    expect(guard<int>(() async => throw StateError('bug')), throwsStateError);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/utils/result_test.dart
```

Esperado: FALHA de compilação (`result.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/utils/result.dart`:
```dart
import 'package:flutter/foundation.dart';

/// The outcome of an operation that can fail: [Ok] with a value, or [Error]
/// with the exception that caused the failure.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>._;

  const factory Result.error(Exception error) = Error<T>._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);

  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}

/// Runs [action] and wraps its outcome in a [Result].
///
/// Only exceptions become an [Error] result. Programming errors such as a
/// failed cast still propagate, so they get noticed during development.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } on Exception catch (error, stackTrace) {
    debugPrint('$error\n$stackTrace');
    return Result.error(error);
  }
}

class NotFoundException implements Exception {
  const NotFoundException(this.message);

  final String message;

  @override
  String toString() => 'NotFoundException: $message';
}
```

`test/helpers/result.dart`:
```dart
import 'package:my_flashcards/utils/result.dart';

/// Returns the value inside an [Ok], failing the test for an [Error].
T okValue<T>(Result<T> result) => switch (result) {
      Ok(:final value) => value,
      Error(:final error) => throw StateError('Esperava Ok, veio $error'),
    };
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/utils/result_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add pubspec.yaml pubspec.lock lib/utils/result.dart test/utils/result_test.dart test/helpers/result.dart
git commit -m "feat: adiciona Result e guard para operações que podem falhar"
```

---

### Tarefa 2: modelo `Deck` e validação do nome

**Arquivos:**
- Criar: `lib/domain/models/deck.dart`
- Testar: `test/domain/models/deck_test.dart`

**Interfaces:**
- Produz: `class Deck`, com:
  - o construtor `const Deck({required int id, required String name, required DateTime createdAt, int cardCount = 0})`;
  - a constante `static const maxNameLength = 50`;
  - o método `static String? validateName(String rawName)`, que devolve `null` quando o nome é válido;
  - `==` e `hashCode` comparando os quatro campos.

- [ ] **Passo 1: escrever o teste**

`test/domain/models/deck_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/deck.dart';

void main() {
  group('Deck.validateName', () {
    test('aceita um nome comum', () {
      expect(Deck.validateName('Inglês'), isNull);
    });

    test('aceita espaços nas pontas, porque o nome é aparado', () {
      expect(Deck.validateName('  Inglês  '), isNull);
    });

    test('recusa nome vazio ou só com espaços', () {
      expect(Deck.validateName(''), 'Dê um nome ao deck.');
      expect(Deck.validateName('   '), 'Dê um nome ao deck.');
    });

    test('aceita 50 caracteres e recusa 51', () {
      expect(Deck.validateName('a' * 50), isNull);
      expect(Deck.validateName('a' * 51), 'Use no máximo 50 caracteres.');
    });
  });

  test('dois decks com os mesmos dados são iguais', () {
    final createdAt = DateTime(2026, 10, 12);
    expect(
      Deck(id: 1, name: 'A', createdAt: createdAt, cardCount: 2),
      Deck(id: 1, name: 'A', createdAt: createdAt, cardCount: 2),
    );
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/domain/models/deck_test.dart
```

Esperado: FALHA de compilação (`deck.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/domain/models/deck.dart`:
```dart
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  static const maxNameLength = 50;

  final int id;
  final String name;
  final DateTime createdAt;
  final int cardCount;

  /// The message to show when [rawName] can't be used as a deck name, or null
  /// when it can. The name is checked after trimming.
  static String? validateName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return 'Dê um nome ao deck.';
    if (name.length > maxNameLength) {
      return 'Use no máximo $maxNameLength caracteres.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Deck &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.cardCount == cardCount;

  @override
  int get hashCode => Object.hash(id, name, createdAt, cardCount);

  @override
  String toString() => 'Deck($id, $name, $cardCount cards)';
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/domain/models/deck_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/domain/models/deck.dart test/domain/models/deck_test.dart
git commit -m "feat: adiciona o modelo Deck com validação do nome"
```

---

### Tarefa 3: `DatabaseService` com o schema v1

**Arquivos:**
- Criar: `lib/data/services/database_service.dart`
- Criar: `test/helpers/test_database.dart`
- Testar: `test/data/services/database_service_test.dart`

**Interfaces:**
- Produz:
  - `class DatabaseService`, com:
    - o construtor `DatabaseService({required DatabaseFactory factory, required String path})`;
    - as constantes `static const schemaVersion = 1` e `static const fileName = 'flashcards.db'`;
    - o campo `final String path`;
    - o getter `Database get db`, que lança `StateError` se o banco estiver fechado;
    - os métodos `Future<void> open()` e `Future<void> close()`.
  - Nos testes: `Future<DatabaseService> openTestDatabase()`, que abre um banco em memória, vazio e já com o schema.

- [ ] **Passo 1: escrever o helper dos testes**

`test/helpers/test_database.dart`:
```dart
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, empty in-memory database with the app schema.
Future<DatabaseService> openTestDatabase() async {
  sqfliteFfiInit();
  final database = DatabaseService(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  await database.open();
  return database;
}
```

- [ ] **Passo 2: escrever o teste**

`test/data/services/database_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() => database.close());

  test('cria as tabelas decks, cards e settings', () async {
    final rows = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(
      rows.map((row) => row['name']),
      containsAll(['decks', 'cards', 'settings']),
    );
  });

  test('grava a versão do schema', () async {
    final rows = await database.db.rawQuery('PRAGMA user_version');

    expect(rows.single.values.single, DatabaseService.schemaVersion);
  });

  test('apagar um deck apaga os cards dele', () async {
    final deckId = await database.db.insert(
      'decks',
      {'name': 'Inglês', 'created_at': 0},
    );
    await database.db.insert('cards', {
      'deck_id': deckId,
      'front_text': 'to give up',
      'back_text': 'desistir',
      'created_at': 0,
    });

    await database.db.delete('decks', where: 'id = ?', whereArgs: [deckId]);

    expect(await database.db.query('cards'), isEmpty);
  });

  test('o contador de revisões começa em zero', () async {
    final deckId = await database.db.insert(
      'decks',
      {'name': 'Inglês', 'created_at': 0},
    );
    await database.db.insert(
      'cards',
      {'deck_id': deckId, 'front_text': 'a', 'back_text': 'b', 'created_at': 0},
    );

    final card = (await database.db.query('cards')).single;
    expect(card['review_count'], 0);
  });

  test('db lança StateError depois de fechar', () async {
    await database.close();

    expect(() => database.db, throwsStateError);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/data/services/database_service_test.dart
```

Esperado: FALHA de compilação (`database_service.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/data/services/database_service.dart`:
```dart
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService({required DatabaseFactory factory, required this.path})
      : _factory = factory;

  static const schemaVersion = 1;
  static const fileName = 'flashcards.db';

  final DatabaseFactory _factory;
  final String path;
  Database? _db;

  Database get db {
    final db = _db;
    if (db == null) {
      throw StateError('O banco de dados não está aberto.');
    }
    return db;
  }

  Future<void> open() async {
    if (_db != null) return;
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: false,
        // SQLite ignores ON DELETE CASCADE unless this is on for every connection.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}

Future<void> _createSchema(Database db, int version) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE decks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        created_at  INTEGER NOT NULL
      )''')
    ..execute('''
      CREATE TABLE cards (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id       INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front_text    TEXT,
        front_image   TEXT,
        front_audio   TEXT,
        back_text     TEXT,
        back_image    TEXT,
        back_audio    TEXT,
        review_count  INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL
      )''')
    ..execute('CREATE INDEX idx_cards_deck ON cards(deck_id)')
    ..execute('''
      CREATE TABLE settings (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      )''');
  await batch.commit(noResult: true);
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/data/services/database_service_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/data/services/database_service.dart test/helpers/test_database.dart test/data/services/database_service_test.dart
git commit -m "feat: cria o DatabaseService com o schema v1"
```

---

### Tarefa 4: `DeckRepository`

**Arquivos:**
- Criar: `lib/data/repositories/deck_repository.dart`
- Testar: `test/data/repositories/deck_repository_test.dart`

**Interfaces:**
- Consome: `DatabaseService.db`, `Result`, `guard`, `NotFoundException` e `Deck`.
- Produz: `class DeckRepository`, com o construtor `DeckRepository({required DatabaseService database, DateTime Function()? now})` e os métodos:
  - `Future<Result<List<Deck>>> getDecks()`: em ordem alfabética, ignorando maiúsculas, com `cardCount`;
  - `Future<Result<Deck>> getDeck(int id)`: devolve `Error(NotFoundException)` se o deck não existir;
  - `Future<Result<Deck>> createDeck(String name)`: grava o nome aparado;
  - `Future<Result<void>> renameDeck(int id, String name)`: grava o nome aparado e devolve `Error(NotFoundException)` se o deck não existir;
  - `Future<Result<void>> deleteDeck(int id)`.

- [ ] **Passo 1: escrever o teste**

`test/data/repositories/deck_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/deck_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late DeckRepository repository;
  final now = DateTime(2026, 10, 12, 9, 30);

  setUp(() async {
    database = await openTestDatabase();
    repository = DeckRepository(database: database, now: () => now);
  });
  tearDown(() => database.close());

  Future<void> insertCard(int deckId) => database.db.insert('cards', {
        'deck_id': deckId,
        'front_text': 'frente',
        'back_text': 'verso',
        'created_at': 0,
      });

  test('cria um deck com o nome aparado e a data de criação', () async {
    final deck = okValue(await repository.createDeck('  Inglês  '));

    expect(deck.name, 'Inglês');
    expect(deck.createdAt, now);
    expect(okValue(await repository.getDecks()), [deck]);
  });

  test('lista em ordem alfabética sem diferenciar maiúsculas', () async {
    await repository.createDeck('banana');
    await repository.createDeck('Cereja');
    await repository.createDeck('Abacate');

    final names = okValue(await repository.getDecks()).map((d) => d.name);

    expect(names, ['Abacate', 'banana', 'Cereja']);
  });

  test('conta os cards de cada deck', () async {
    final withCards = okValue(await repository.createDeck('Com cards'));
    await repository.createDeck('Vazio');
    await insertCard(withCards.id);
    await insertCard(withCards.id);

    final decks = okValue(await repository.getDecks());

    expect(decks.map((d) => (d.name, d.cardCount)), [
      ('Com cards', 2),
      ('Vazio', 0),
    ]);
  });

  test('getDeck devolve o deck com a contagem de cards', () async {
    final created = okValue(await repository.createDeck('Inglês'));
    await insertCard(created.id);

    final deck = okValue(await repository.getDeck(created.id));

    expect(deck.cardCount, 1);
  });

  test('getDeck devolve NotFoundException para um id inexistente', () async {
    final result = await repository.getDeck(999);

    expect(
      result,
      isA<Error<dynamic>>()
          .having((r) => r.error, 'error', isA<NotFoundException>()),
    );
  });

  test('renomeia com o nome aparado', () async {
    final deck = okValue(await repository.createDeck('Inglês'));

    okValue(await repository.renameDeck(deck.id, '  Verbos  '));

    expect(okValue(await repository.getDeck(deck.id)).name, 'Verbos');
  });

  test('renomear um deck inexistente devolve erro', () async {
    expect(await repository.renameDeck(999, 'X'), isA<Error<void>>());
  });

  test('excluir o deck apaga também os cards dele', () async {
    final deck = okValue(await repository.createDeck('Inglês'));
    await insertCard(deck.id);

    okValue(await repository.deleteDeck(deck.id));

    expect(okValue(await repository.getDecks()), isEmpty);
    expect(await database.db.query('cards'), isEmpty);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/deck_repository_test.dart
```

Esperado: FALHA de compilação (`deck_repository.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/data/repositories/deck_repository.dart`:
```dart
import '../../domain/models/deck.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';

class DeckRepository {
  DeckRepository({
    required DatabaseService database,
    DateTime Function()? now,
  })  : _database = database,
        _now = now ?? DateTime.now;

  final DatabaseService _database;
  final DateTime Function() _now;

  static const _selectDecks = '''
    SELECT d.id, d.name, d.created_at, COUNT(c.id) AS card_count
    FROM decks d
    LEFT JOIN cards c ON c.deck_id = d.id''';

  Future<Result<List<Deck>>> getDecks() => guard(() async {
        final rows = await _database.db.rawQuery(
          '$_selectDecks GROUP BY d.id ORDER BY d.name COLLATE NOCASE, d.id',
        );
        return rows.map(_deckFromRow).toList();
      });

  Future<Result<Deck>> getDeck(int id) => guard(() async {
        final rows = await _database.db.rawQuery(
          '$_selectDecks WHERE d.id = ? GROUP BY d.id',
          [id],
        );
        if (rows.isEmpty) throw NotFoundException('O deck $id não existe.');
        return _deckFromRow(rows.single);
      });

  Future<Result<Deck>> createDeck(String name) => guard(() async {
        final trimmed = name.trim();
        final createdAt = _now();
        final id = await _database.db.insert('decks', {
          'name': trimmed,
          'created_at': createdAt.millisecondsSinceEpoch,
        });
        return Deck(id: id, name: trimmed, createdAt: createdAt);
      });

  Future<Result<void>> renameDeck(int id, String name) => guard(() async {
        final updated = await _database.db.update(
          'decks',
          {'name': name.trim()},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (updated == 0) throw NotFoundException('O deck $id não existe.');
      });

  Future<Result<void>> deleteDeck(int id) => guard(() async {
        await _database.db.delete('decks', where: 'id = ?', whereArgs: [id]);
      });
}

Deck _deckFromRow(Map<String, Object?> row) => Deck(
      id: row['id']! as int,
      name: row['name']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      cardCount: row['card_count']! as int,
    );
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/data/repositories/deck_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/data/repositories/deck_repository.dart test/data/repositories/deck_repository_test.dart
git commit -m "feat: cria o DeckRepository"
```

---

### Tarefa 5: `DeckListViewModel`

**Arquivos:**
- Criar: `lib/ui/deck_list/view_models/deck_list_view_model.dart`
- Criar: `test/fakes/fake_deck_repository.dart`
- Testar: `test/ui/deck_list/deck_list_view_model_test.dart`

**Interfaces:**
- Consome: `DeckRepository` (todos os métodos da tarefa 4).
- Produz:
  - `class DeckListViewModel extends ChangeNotifier`, com:
    - o construtor `DeckListViewModel({required DeckRepository deckRepository})`;
    - os getters `List<Deck> decks`, `bool isLoading`, `String? loadError` e `String? actionError`;
    - os métodos `Future<void> load()`, `Future<bool> createDeck(String name)`, `Future<bool> renameDeck(int id, String name)` e `Future<bool> deleteDeck(int id)`, que devolvem `false` em caso de falha e guardam a mensagem em `actionError`;
    - as constantes de mensagem `loadErrorMessage`, `createErrorMessage`, `renameErrorMessage` e `deleteErrorMessage`.
  - Nos testes: `FakeDeckRepository([List<Deck> decks])`, com `Exception? failWith` e `List<Deck> decks`.

- [ ] **Passo 1: escrever o repositório falso**

`test/fakes/fake_deck_repository.dart`:
```dart
import 'package:my_flashcards/data/repositories/deck_repository.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/utils/result.dart';

/// In-memory [DeckRepository]. Set [failWith] to make every call fail.
class FakeDeckRepository implements DeckRepository {
  FakeDeckRepository([List<Deck> decks = const []]) : _decks = [...decks];

  final List<Deck> _decks;
  Exception? failWith;
  var _nextId = 1000;

  List<Deck> get decks => List.unmodifiable(_decks);

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    return Result.ok(compute());
  }

  @override
  Future<Result<List<Deck>>> getDecks() => _answer(
        () => [..._decks]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      );

  @override
  Future<Result<Deck>> getDeck(int id) async {
    if (failWith != null) return Result.error(failWith!);
    for (final deck in _decks) {
      if (deck.id == id) return Result.ok(deck);
    }
    return Result.error(NotFoundException('O deck $id não existe.'));
  }

  @override
  Future<Result<Deck>> createDeck(String name) => _answer(() {
        final deck = Deck(
          id: _nextId++,
          name: name.trim(),
          createdAt: DateTime(2026, 10, 12),
        );
        _decks.add(deck);
        return deck;
      });

  @override
  Future<Result<void>> renameDeck(int id, String name) => _answer(() {
        final index = _decks.indexWhere((d) => d.id == id);
        final old = _decks[index];
        _decks[index] = Deck(
          id: id,
          name: name.trim(),
          createdAt: old.createdAt,
          cardCount: old.cardCount,
        );
      });

  @override
  Future<Result<void>> deleteDeck(int id) =>
      _answer(() => _decks.removeWhere((d) => d.id == id));
}
```

- [ ] **Passo 2: escrever o teste**

`test/ui/deck_list/deck_list_view_model_test.dart`:
```dart
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
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/ui/deck_list/deck_list_view_model_test.dart
```

Esperado: FALHA de compilação (`deck_list_view_model.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/ui/deck_list/view_models/deck_list_view_model.dart`:
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/deck_repository.dart';
import '../../../domain/models/deck.dart';
import '../../../utils/result.dart';

class DeckListViewModel extends ChangeNotifier {
  DeckListViewModel({required DeckRepository deckRepository})
      : _deckRepository = deckRepository;

  static const loadErrorMessage = 'Não foi possível carregar os decks.';
  static const createErrorMessage = 'Não foi possível criar o deck.';
  static const renameErrorMessage = 'Não foi possível renomear o deck.';
  static const deleteErrorMessage = 'Não foi possível excluir o deck.';

  final DeckRepository _deckRepository;

  List<Deck> _decks = const [];
  bool _isLoading = false;
  String? _loadError;
  String? _actionError;

  List<Deck> get decks => _decks;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// The message for the last action (create, rename or delete) that failed.
  String? get actionError => _actionError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    switch (await _deckRepository.getDecks()) {
      case Ok(:final value):
        _decks = value;
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createDeck(String name) =>
      _run(() => _deckRepository.createDeck(name), createErrorMessage);

  Future<bool> renameDeck(int id, String name) =>
      _run(() => _deckRepository.renameDeck(id, name), renameErrorMessage);

  Future<bool> deleteDeck(int id) =>
      _run(() => _deckRepository.deleteDeck(id), deleteErrorMessage);

  Future<bool> _run(
    Future<Result<Object?>> Function() action,
    String errorMessage,
  ) async {
    _actionError = null;
    final result = await action();
    if (result is Error) {
      _actionError = errorMessage;
      notifyListeners();
      return false;
    }
    await load();
    return true;
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/deck_list/deck_list_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/deck_list/view_models test/fakes/fake_deck_repository.dart test/ui/deck_list/deck_list_view_model_test.dart
git commit -m "feat: cria o DeckListViewModel"
```

---

### Tarefa 6: tela de decks e diálogo de nome

**Arquivos:**
- Criar: `lib/ui/deck_list/widgets/deck_name_dialog.dart`
- Criar: `lib/ui/deck_list/widgets/deck_list_screen.dart`
- Testar: `test/ui/deck_list/deck_list_screen_test.dart`

**Interfaces:**
- Consome: `DeckListViewModel` (tarefa 5) e `Deck.validateName` / `Deck.maxNameLength` (tarefa 2).
- Produz:
  - `Future<String?> showDeckNameDialog(BuildContext context, {required String title, required String confirmLabel, String initialName = ''})`, que devolve o nome aparado, ou `null` se a usuária cancelar;
  - `class DeckListScreen extends StatefulWidget`, com `const DeckListScreen({super.key, required DeckListViewModel viewModel})`. A tela chama `viewModel.load()` no `initState` e `viewModel.dispose()` no `dispose`;
  - as funções de texto `String cardCountLabel(int count)` e `String deleteDeckMessage(Deck deck)`.

- [ ] **Passo 1: escrever o teste**

`test/ui/deck_list/deck_list_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/deck.dart';
import 'package:my_flashcards/ui/deck_list/view_models/deck_list_view_model.dart';
import 'package:my_flashcards/ui/deck_list/widgets/deck_list_screen.dart';

import '../../fakes/fake_deck_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDeckRepository repository,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: DeckListScreen(
        viewModel: DeckListViewModel(deckRepository: repository),
      ),
    ));
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

  testWidgets('o campo de nome não aceita mais de 50 caracteres',
      (tester) async {
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

  testWidgets('exclui depois de confirmar, avisando quantos cards somem',
      (tester) async {
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

  testWidgets('falha ao carregar mostra erro e permite tentar de novo',
      (tester) async {
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
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível criar o deck.'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/deck_list/deck_list_screen_test.dart
```

Esperado: FALHA de compilação (`deck_list_screen.dart` não existe).

- [ ] **Passo 3: implementar o diálogo**

`lib/ui/deck_list/widgets/deck_name_dialog.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/deck.dart';

/// Asks for a deck name. Completes with the trimmed name, or null when the
/// dialog is cancelled.
Future<String?> showDeckNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => DeckNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );
}

class DeckNameDialog extends StatefulWidget {
  const DeckNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<DeckNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  bool get _isValid => Deck.validateName(_controller.text) == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isValid) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: Deck.maxNameLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
```

- [ ] **Passo 4: implementar a tela**

`lib/ui/deck_list/widgets/deck_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/deck.dart';
import '../view_models/deck_list_view_model.dart';
import 'deck_name_dialog.dart';

String cardCountLabel(int count) => switch (count) {
      0 => 'Nenhum card',
      1 => '1 card',
      _ => '$count cards',
    };

String deleteDeckMessage(Deck deck) {
  final cards = switch (deck.cardCount) {
    0 => '',
    1 => ' O único card dele será apagado.',
    final count => ' Os $count cards serão apagados.',
  };
  return 'Excluir “${deck.name}”?$cards Isso não pode ser desfeito.';
}

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key, required this.viewModel});

  final DeckListViewModel viewModel;

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

enum _DeckAction { rename, delete }

class _DeckListScreenState extends State<DeckListScreen> {
  DeckListViewModel get _viewModel => widget.viewModel;

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

  Future<void> _createDeck() async {
    final name = await showDeckNameDialog(
      context,
      title: 'Novo deck',
      confirmLabel: 'Criar',
    );
    if (name == null) return;
    if (!await _viewModel.createDeck(name)) _showActionError();
  }

  Future<void> _renameDeck(Deck deck) async {
    final name = await showDeckNameDialog(
      context,
      title: 'Renomear deck',
      confirmLabel: 'Salvar',
      initialName: deck.name,
    );
    if (name == null || name == deck.name) return;
    if (!await _viewModel.renameDeck(deck.id, name)) _showActionError();
  }

  Future<void> _deleteDeck(Deck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir deck'),
        content: Text(deleteDeckMessage(deck)),
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
    if (!await _viewModel.deleteDeck(deck.id)) _showActionError();
  }

  void _showActionError() {
    final message = _viewModel.actionError;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Flashcards')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDeck,
        tooltip: 'Novo deck',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return _LoadErrorView(message: loadError, onRetry: _viewModel.load);
    }
    if (_viewModel.isLoading && _viewModel.decks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.decks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhum deck ainda. Toque em + para criar o primeiro.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _viewModel.decks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final deck = _viewModel.decks[index];
        return ListTile(
          title: Text(deck.name),
          subtitle: Text(cardCountLabel(deck.cardCount)),
          trailing: PopupMenuButton<_DeckAction>(
            tooltip: 'Opções do deck',
            onSelected: (action) => switch (action) {
              _DeckAction.rename => _renameDeck(deck),
              _DeckAction.delete => _deleteDeck(deck),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _DeckAction.rename, child: Text('Renomear')),
              PopupMenuItem(value: _DeckAction.delete, child: Text('Excluir')),
            ],
          ),
        );
      },
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/deck_list/deck_list_screen_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/deck_list/widgets test/ui/deck_list/deck_list_screen_test.dart
git commit -m "feat: cria a tela de decks com criar, renomear e excluir"
```

---

### Tarefa 7: tema, `AppDependencies` e ligação no `main`

**Arquivos:**
- Criar: `lib/ui/core/theme.dart`
- Criar: `lib/app_dependencies.dart`
- Substituir: `lib/app.dart`, `lib/main.dart`
- Testar: `test/ui/core/theme_test.dart`. Substituir: `test/app_test.dart`

**Interfaces:**
- Consome: `DatabaseService`, `DeckRepository`, `DeckListViewModel` e `DeckListScreen`.
- Produz:
  - `AppColors.magenta` e `AppColors.pink`;
  - `ThemeData buildLightTheme()` e `ThemeData buildDarkTheme()`;
  - `class AppDependencies`, com:
    - o construtor `AppDependencies({required DeckRepository decks})`;
    - o método `static Future<AppDependencies> create()`;
    - **as etapas seguintes acrescentam campos aqui.**
  - `class App extends StatefulWidget`, com `const App({super.key, required AppDependencies dependencies})`.

- [ ] **Passo 1: escrever os testes**

`test/ui/core/theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/core/theme.dart';

void main() {
  test('o tema claro usa o magenta do logo como cor principal', () {
    final scheme = buildLightTheme().colorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, AppColors.magenta);
  });

  test('o tema escuro usa o rosa do logo com texto preto', () {
    final scheme = buildDarkTheme().colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, AppColors.pink);
    expect(scheme.onPrimary, Colors.black);
  });
}
```

`test/app_test.dart` (substitui o da etapa 0):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';
import 'package:my_flashcards/app_dependencies.dart';

import 'fakes/fake_deck_repository.dart';

void main() {
  testWidgets('abre na lista de decks, seguindo o tema do sistema',
      (tester) async {
    await tester.pumpWidget(
      App(dependencies: AppDependencies(decks: FakeDeckRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Flashcards'), findsOneWidget);
    expect(
      find.text('Nenhum deck ainda. Toque em + para criar o primeiro.'),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/core/theme_test.dart test/app_test.dart
```

Esperado: FALHA de compilação (`theme.dart` e `app_dependencies.dart` não existem).

- [ ] **Passo 3: implementar o tema**

`lib/ui/core/theme.dart`:
```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const magenta = Color(0xFFC52DC3);
  static const pink = Color(0xFFF05BD3);
}

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.magenta)
          .copyWith(primary: AppColors.magenta, onPrimary: Colors.white),
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.magenta,
        brightness: Brightness.dark,
      ).copyWith(primary: AppColors.pink, onPrimary: Colors.black),
    );
```

- [ ] **Passo 4: implementar `AppDependencies`, `App` e `main`**

`lib/app_dependencies.dart`:
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/deck_repository.dart';
import 'data/services/database_service.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({required this.decks});

  final DeckRepository decks;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    return AppDependencies(decks: DeckRepository(database: database));
  }
}
```

`lib/app.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app_dependencies.dart';
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
      home: DeckListScreen(viewModel: _deckListViewModel),
    );
  }
}
```

`lib/main.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(App(dependencies: dependencies));
}
```

- [ ] **Passo 5: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/core/theme.dart lib/app_dependencies.dart lib/app.dart lib/main.dart test/ui/core/theme_test.dart test/app_test.dart
git commit -m "feat: liga a tela de decks ao banco real, com os temas claro e escuro"
```

---

### Tarefa 8: conferir no celular e fechar a etapa

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

- [ ] Com o app recém-instalado, aparece *"Nenhum deck ainda. Toque em + para criar o primeiro."*
- [ ] O **+** cria um deck, e o deck aparece com *"Nenhum card"*
- [ ] Com três decks criados ("banana", "Abacate" e "cereja"), eles aparecem em ordem alfabética
- [ ] **⋮ › Renomear** troca o nome
- [ ] **⋮ › Excluir** pede confirmação e apaga
- [ ] Fechar o app (removendo-o dos recentes) e abrir de novo mantém os decks
- [ ] Com o celular no modo escuro, o app fica escuro e os destaques ficam rosa

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-1-decks -m "Etapa 1: dados e decks" && git branch -d etapa-1-decks
```
