# Etapa 7: backup. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** exportar tudo (banco, mídias e configurações) num `.zip` entregue pelo menu de compartilhar, e importar um `.zip` que substitui todos os dados, sem risco de perder nada se algo der errado no meio.

**Arquitetura:**
- **Services:**
  - `ZipService` compacta, lista e extrai, sempre num isolate separado;
  - `BackupFileService` embrulha o `file_picker` e o `share_plus`;
  - `DatabaseService` ganha `copyTo` (`VACUUM INTO`) e `checkReadable`.
- **`BackupRepository`:**
  - monta o backup;
  - valida o arquivo a importar: manifesto, nomes das entradas e banco;
  - troca os dados guardando uma cópia de rollback.
- **`SettingsViewModel`:** coordena o fluxo "importar" e depois chama o `ReminderRepository`.
- **`SettingsScreen`:** ganha a seção BACKUP, com diálogo de progresso e de confirmação.

**Tecnologias:** `archive` 4.5, `share_plus` 13.3 e `file_picker` 13.1.

**Spec:** [docs/design.md](../design.md), parte 3 ("Backup: exportar" e "Backup: importar") e parte 4 (tabela de erros). Requisitos RF-20 e RF-21.

**Branch:** `etapa-7-backup`

## Restrições globais

- **O `.zip`:**
  - se chama `my-flashcards-backup-AAAA-MM-DD.zip`;
  - contém exatamente `manifest.json`, `flashcards.db` e `media/<arquivos>`;
  - o manifesto tem `app: "my_flashcards"`, `formatVersion: 1`, `schemaVersion`, `exportedAt`, `decks` e `cards`.
- **Cópia do banco:** é feita com `VACUUM INTO`, que funciona com o banco aberto e em modo WAL.
- **Isolate:** compactar e extrair acontece fora da thread da interface (`Isolate.run`).
- **Importar recusa:**
  - um arquivo que não é zip;
  - entradas com `..`, caminho absoluto, `\` ou nomes fora da lista acima;
  - outro `app`, outro `formatVersion` ou `schemaVersion` maior que o atual;
  - um `flashcards.db` que não abre.

  A mensagem é sempre *"Este arquivo não é um backup do My Flashcards."*
- **Importar troca os dados com rollback:**
  1. fecha o banco;
  2. move os dados atuais para `rollback/`;
  3. coloca os importados no lugar;
  4. reabre o banco.

  Se algo falhar, os dados de rollback voltam ao lugar e aparece *"Não foi possível importar. Seus dados não foram alterados."*
- **Confirmação:** *"Substituir todos os dados?"*, seguido de *"O backup de DD/MM/AAAA tem N decks e M cards. Seus decks atuais serão apagados."*, com os botões Cancelar e Substituir.
- **Depois de importar:** o lembrete recomeça (`ReminderRepository.resetAfterImport`) e o app volta para a lista de decks.
- **Ao abrir o app:** os `.zip` antigos e as pastas `export/` e `import/` são apagados. **A pasta `rollback/` nunca é apagada automaticamente.**
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Escolher um arquivo qualquer** (um zip de fotos, um PDF renomeado). Aparece a mensagem de backup inválido e os dados ficam intactos. Testado na tarefa 3.
2. **Zip malicioso com `../`.** É recusado inteiro, e nada é escrito fora da pasta de importação. Testado na tarefa 3.
3. **Falha no meio da troca de dados.** Os dados originais voltam, inclusive as mídias, e o banco continua usável. Testado na tarefa 3.
4. **Backup de uma versão mais nova do app** (`schemaVersion` maior). É recusado. Testado na tarefa 3.
5. **Cancelar na confirmação.** Nada muda, e a pasta extraída é apagada. Testado nas tarefas 3 e 5.

---

### Tarefa 1: `BackupManifest`, `ZipService` e as funções novas do `DatabaseService`

**Arquivos:**
- Criar: `lib/domain/models/backup_manifest.dart`
- Criar: `lib/data/services/zip_service.dart`
- Modificar: `lib/data/services/database_service.dart`
- Testar:
  - criar `test/domain/models/backup_manifest_test.dart` e `test/data/services/zip_service_test.dart`;
  - modificar `test/data/services/database_service_test.dart`.

**Interfaces:**
- Produz:
  - `class BackupManifest`, com:
    - o construtor `const BackupManifest({required String app, required int formatVersion, required int schemaVersion, required DateTime exportedAt, required int decks, required int cards})`;
    - as constantes `appId = 'my_flashcards'` e `currentFormatVersion = 1`;
    - o método `Map<String, Object?> toJson()`;
    - o factory `BackupManifest.fromJson(Object? json)`, que lança `FormatException` se o JSON não for um manifesto.
  - `class ZipService`, com os métodos:
    - `Future<void> createZip(String zipPath, Map<String, String> entries)`, em que cada nome de entrada aponta para o arquivo de origem;
    - `Future<List<String>> listEntries(String zipPath)`;
    - `Future<void> extract(String zipPath, String outputDir)`.
  - Em `DatabaseService`:
    - `Future<void> copyTo(String destinationPath)`;
    - `Future<void> checkReadable(String path)`, que lança se o arquivo não for um banco do app.

- [ ] **Passo 1: criar o branch e adicionar os pacotes**

```bash
git switch main && git switch -c etapa-7-backup
flutter pub add archive share_plus file_picker
```

- [ ] **Passo 2: escrever os testes**

`test/domain/models/backup_manifest_test.dart`:
```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';

void main() {
  final manifest = BackupManifest(
    app: BackupManifest.appId,
    formatVersion: BackupManifest.currentFormatVersion,
    schemaVersion: 1,
    exportedAt: DateTime(2026, 10, 12, 20, 15),
    decks: 3,
    cards: 87,
  );

  test('vai para JSON e volta igual', () {
    final json = jsonDecode(jsonEncode(manifest.toJson()));

    final back = BackupManifest.fromJson(json);

    expect(back.app, 'my_flashcards');
    expect(back.exportedAt, manifest.exportedAt);
    expect(back.decks, 3);
    expect(back.cards, 87);
  });

  test('JSON sem os campos certos lança FormatException', () {
    expect(() => BackupManifest.fromJson({'app': 'my_flashcards'}),
        throwsFormatException);
    expect(() => BackupManifest.fromJson([1, 2]), throwsFormatException);
    expect(
      () => BackupManifest.fromJson({
        ...manifest.toJson(),
        'decks': 'três',
      }),
      throwsFormatException,
    );
  });
}
```

`test/data/services/zip_service_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/zip_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  final zip = ZipService();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zip_service_test_');
    addTearDown(() => root.delete(recursive: true));
  });

  Future<String> write(String name, String content) async {
    final file = File(p.join(root.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  test('cria, lista e extrai mantendo os nomes das entradas', () async {
    final zipPath = p.join(root.path, 'teste.zip');
    await zip.createZip(zipPath, {
      'manifest.json': await write('a.json', '{}'),
      'media/img_1.jpg': await write('b.jpg', 'foto'),
    });

    expect(await zip.listEntries(zipPath),
        containsAll(['manifest.json', 'media/img_1.jpg']));

    final out = p.join(root.path, 'saida');
    await zip.extract(zipPath, out);
    expect(await File(p.join(out, 'media', 'img_1.jpg')).readAsString(), 'foto');
  });

  test('listEntries de um arquivo que não é zip lança', () async {
    final notZip = await write('falso.zip', 'isto não é um zip');

    expect(zip.listEntries(notZip), throwsA(isA<Exception>()));
  });
}
```

Em `test/data/services/database_service_test.dart`:

1. Acrescente os imports:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
```

2. Acrescente ao fim do `main()`:
```dart
  test('copyTo grava uma cópia que checkReadable aceita', () async {
    final dir = await Directory.systemTemp.createTemp('db_copy_test_');
    addTearDown(() => dir.delete(recursive: true));
    await database.db.insert('decks', {'name': "D'água", 'created_at': 0});
    final copy = p.join(dir.path, "cópia d'água.db");

    await database.copyTo(copy);

    await database.checkReadable(copy);
    expect(await File(copy).length(), greaterThan(0));
  });

  test('checkReadable recusa um arquivo que não é banco', () async {
    final dir = await Directory.systemTemp.createTemp('db_check_test_');
    addTearDown(() => dir.delete(recursive: true));
    final fake = File(p.join(dir.path, 'falso.db'));
    await fake.writeAsString('não sou um banco de dados');

    expect(database.checkReadable(fake.path), throwsA(isA<Exception>()));
  });
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/domain/models/backup_manifest_test.dart test/data/services
```

Esperado: FALHA de compilação (`BackupManifest`, `ZipService` e `copyTo` não existem).

- [ ] **Passo 4: implementar o manifesto**

`lib/domain/models/backup_manifest.dart`:
```dart
/// The `manifest.json` inside a backup, describing what it holds.
class BackupManifest {
  const BackupManifest({
    required this.app,
    required this.formatVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.decks,
    required this.cards,
  });

  static const appId = 'my_flashcards';
  static const currentFormatVersion = 1;

  /// Throws a [FormatException] when [json] is not a manifest.
  factory BackupManifest.fromJson(Object? json) {
    if (json
        case {
          'app': final String app,
          'formatVersion': final int formatVersion,
          'schemaVersion': final int schemaVersion,
          'exportedAt': final String exportedAt,
          'decks': final int decks,
          'cards': final int cards,
        }) {
      return BackupManifest(
        app: app,
        formatVersion: formatVersion,
        schemaVersion: schemaVersion,
        exportedAt: DateTime.parse(exportedAt),
        decks: decks,
        cards: cards,
      );
    }
    throw const FormatException('Manifesto de backup inválido.');
  }

  final String app;
  final int formatVersion;
  final int schemaVersion;
  final DateTime exportedAt;
  final int decks;
  final int cards;

  Map<String, Object?> toJson() => {
        'app': app,
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'decks': decks,
        'cards': cards,
      };
}
```

- [ ] **Passo 5: implementar o `ZipService`**

`lib/data/services/zip_service.dart`:
```dart
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// Zip work runs in a separate isolate so big backups don't freeze the UI.
class ZipService {
  /// Creates [zipPath] with one entry per key of [entries], each holding the
  /// content of the file at its value.
  Future<void> createZip(String zipPath, Map<String, String> entries) =>
      Isolate.run(() => _createZip(zipPath, entries));

  Future<List<String>> listEntries(String zipPath) =>
      Isolate.run(() => _listEntries(zipPath));

  Future<void> extract(String zipPath, String outputDir) =>
      Isolate.run(() => _extract(zipPath, outputDir));
}

void _createZip(String zipPath, Map<String, String> entries) {
  final encoder = ZipFileEncoder()..create(zipPath);
  try {
    for (final MapEntry(key: name, value: source) in entries.entries) {
      encoder.addFileSync(File(source), name);
    }
  } finally {
    encoder.closeSync();
  }
}

List<String> _listEntries(String zipPath) {
  final input = InputFileStream(zipPath);
  try {
    return [for (final file in ZipDecoder().decodeStream(input).files) file.name];
  } finally {
    input.closeSync();
  }
}

void _extract(String zipPath, String outputDir) {
  final input = InputFileStream(zipPath);
  try {
    extractArchiveToDiskSync(ZipDecoder().decodeStream(input), outputDir);
  } finally {
    input.closeSync();
  }
}
```

- [ ] **Passo 6: implementar `copyTo` e `checkReadable`**

Em `lib/data/services/database_service.dart`, acrescente estes métodos à classe `DatabaseService`, depois de `close()`:
```dart
  /// Writes a consistent copy of the open database to [destinationPath],
  /// including changes still in the write-ahead log.
  Future<void> copyTo(String destinationPath) {
    final quoted = destinationPath.replaceAll("'", "''");
    return db.execute("VACUUM INTO '$quoted'");
  }

  /// Throws unless the file at [path] is a database with this app's tables.
  Future<void> checkReadable(String path) async {
    final other = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      await other.rawQuery('SELECT COUNT(*) FROM decks');
      await other.rawQuery('SELECT COUNT(*) FROM cards');
    } finally {
      await other.close();
    }
  }
```

- [ ] **Passo 7: rodar e ver passar**

```bash
flutter test test/domain/models/backup_manifest_test.dart test/data/services
```

Esperado: `All tests passed!`

- [ ] **Passo 8: commit**

```bash
git add pubspec.yaml pubspec.lock lib/domain/models/backup_manifest.dart lib/data/services/zip_service.dart lib/data/services/database_service.dart test/domain/models/backup_manifest_test.dart test/data/services
git commit -m "feat: manifesto, zip e cópia do banco para o backup"
```

---

### Tarefa 2: `BackupFileService` (escolher e compartilhar arquivo)

**Arquivos:**
- Criar: `lib/data/services/backup_file_service.dart`
- Criar: `test/fakes/fake_backup_file_service.dart`

**Interfaces:**
- Produz:
  - `class BackupFileService`, com os métodos:
    - `Future<bool> pickZip(String destinationPath)`, que copia o `.zip` escolhido para `destinationPath` e devolve `false` se a usuária cancelar;
    - `Future<void> share(String path)`.
  - Nos testes: `FakeBackupFileService`, com `String? nextPick` (o caminho de um arquivo real a "escolher", ou `null` para cancelar) e a lista `shared`.

  Este service só embrulha os plugins. Ele é conferido no celular (tarefa 6).

- [ ] **Passo 1: implementar o service**

`lib/data/services/backup_file_service.dart`:
```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class BackupFileService {
  /// Lets the user choose a .zip and copies it to [destinationPath]. The
  /// copy works for files from any provider, such as Google Drive. Returns
  /// false when the user cancels.
  Future<bool> pickZip(String destinationPath) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null) return false;
    final sink = File(destinationPath).openWrite();
    try {
      await sink.addStream(picked.readAsByteStream());
    } finally {
      await sink.close();
    }
    return true;
  }

  /// Opens the Android share menu with the file.
  Future<void> share(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'application/zip')]),
    );
  }
}
```

- [ ] **Passo 2: escrever o service falso**

`test/fakes/fake_backup_file_service.dart`:
```dart
import 'dart:io';

import 'package:my_flashcards/data/services/backup_file_service.dart';

class FakeBackupFileService implements BackupFileService {
  /// The path of a real file to "pick", or null to cancel.
  String? nextPick;
  final shared = <String>[];

  @override
  Future<bool> pickZip(String destinationPath) async {
    final source = nextPick;
    if (source == null) return false;
    await File(source).copy(destinationPath);
    return true;
  }

  @override
  Future<void> share(String path) async => shared.add(path);
}
```

- [ ] **Passo 3: rodar a análise**

```bash
flutter analyze
```

Esperado: `No issues found!`

- [ ] **Passo 4: commit**

```bash
git add lib/data/services/backup_file_service.dart test/fakes/fake_backup_file_service.dart
git commit -m "feat: escolhe e compartilha o arquivo de backup"
```

---

### Tarefa 3: `BackupRepository`

> **Recomendações da revisão da etapa 5 (2026-10-18):** antes de substituir `media/` numa importação, pare o áudio (`stopPlayback`). No zip, guarde os `.jpg` e `.m4a` sem compressão (`level: ZipFileEncoder.STORE` no `addFileSync`), porque eles já são comprimidos e comprimir de novo só gasta tempo.

> **Recomendação da revisão da etapa 4 (2026-10-16):** um banco importado pode trazer nomes de arquivo inesperados. Antes de apagar ou abrir um arquivo de mídia pelo nome guardado no banco, confira que `p.basename(nome) == nome` (sem `../`). E depois da troca de dados, rode `ensureDirectories()`, porque `commitDrafts` supõe que `media/` existe.

**Arquivos:**
- Criar: `lib/data/repositories/backup_repository.dart`
- Criar: `test/fakes/fake_backup_repository.dart`
- Modificar: `lib/app_dependencies.dart` e `lib/main.dart`
- Testar: `test/data/repositories/backup_repository_test.dart`. Modificar: `test/app_test.dart`

**Interfaces:**
- Consome:
  - `DatabaseService` (`path`, `db`, `open`, `close`, `copyTo` e `checkReadable`);
  - `MediaFileService` (`mediaDir` e `ensureDirectories`);
  - `ZipService`, `BackupFileService`, `BackupManifest` e `formatDate`.
- Produz: `class BackupRepository`, com:
  - o construtor `BackupRepository({required DatabaseService database, required MediaFileService mediaFiles, required ZipService zip, required BackupFileService files, required Directory workDir, DateTime Function()? now})`;
  - os métodos:

    | Método | O que faz |
    |---|---|
    | `Future<Result<String>> exportBackup()` | Gera o `.zip` e devolve o caminho dele |
    | `Future<Result<void>> shareBackup(String zipPath)` | Abre o menu de compartilhar |
    | `Future<Result<String?>> pickBackupFile()` | Devolve o caminho da cópia local do arquivo escolhido, ou `null` se a usuária cancelou |
    | `Future<Result<BackupManifest>> prepareImport(String zipPath)` | Extrai e valida o backup |
    | `Future<Result<void>> applyImport()` | Troca os dados, com rollback |
    | `Future<void> cancelImport()` | Apaga a pasta extraída |
    | `Future<void> cleanOldExports()` | Apaga `.zip` antigos e as pastas `export/` e `import/` |

  - Em `AppDependencies`, o campo novo `final BackupRepository backups`. Ao abrir o app, `cleanOldExports()` roda depois de `clearDrafts()` e antes de `topUp()`.
  - Nos testes: `FakeBackupRepository`, com:
    - `Exception? exportError`, `String? pickedPath`, `Exception? prepareError` e `Exception? applyError`;
    - o campo `BackupManifest manifest` e a lista `shared`;
    - os contadores `applyCalls`, `cancelCalls` e `cleanCalls`.

- [ ] **Passo 1: escrever o teste**

`test/data/repositories/backup_repository_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/backup_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:my_flashcards/data/services/zip_service.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';
import 'package:my_flashcards/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../helpers/result.dart';

/// Fails the second time it opens, which is the reopening during an import.
class _FailingReopenDatabase extends DatabaseService {
  _FailingReopenDatabase({required super.factory, required super.path});

  var opens = 0;

  @override
  Future<void> open() async {
    opens++;
    if (opens == 2) throw const FileSystemException('falha simulada');
    await super.open();
  }
}

void main() {
  late Directory root;
  late DatabaseService database;
  late MediaFileService mediaFiles;
  late FakeBackupFileService files;
  late BackupRepository repository;
  final zip = ZipService();

  Future<void> setUpWith(DatabaseService db) async {
    database = db;
    await database.open();
    repository = BackupRepository(
      database: database,
      mediaFiles: mediaFiles,
      zip: zip,
      files: files,
      workDir: Directory(p.join(root.path, 'backup')),
      now: () => DateTime(2026, 10, 12, 20, 15),
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('backup_test_');
    await Directory(p.join(root.path, 'db')).create();
    mediaFiles = MediaFileService(
      mediaDir: Directory(p.join(root.path, 'media')),
      draftDir: Directory(p.join(root.path, 'drafts')),
    );
    await mediaFiles.ensureDirectories();
    files = FakeBackupFileService();
    await setUpWith(DatabaseService(
      factory: databaseFactoryFfi,
      path: p.join(root.path, 'db', DatabaseService.fileName),
    ));
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  Future<void> seedDeck(String name, {String? image}) async {
    final deckId = await database.db.insert('decks', {'name': name, 'created_at': 0});
    await database.db.insert('cards', {
      'deck_id': deckId,
      'front_text': 'frente',
      'front_image': image,
      'back_text': 'verso',
      'created_at': 0,
    });
    if (image != null) await mediaFiles.mediaFile(image).writeAsString('foto');
  }

  Future<List<String>> deckNames() async => [
        for (final row in await database.db.query('decks', orderBy: 'name'))
          row['name']! as String,
      ];

  /// Builds a zip by hand, for backups this app would never produce.
  Future<String> handMadeZip(Map<String, String> contents) async {
    final dir = await Directory(p.join(root.path, 'feito_a_mao')).create();
    final entries = <String, String>{};
    var i = 0;
    for (final MapEntry(key: name, value: content) in contents.entries) {
      final source = File(p.join(dir.path, 'arquivo_${i++}'));
      await source.writeAsString(content);
      entries[name] = source.path;
    }
    final zipPath = p.join(root.path, 'feito_a_mao.zip');
    await zip.createZip(zipPath, entries);
    return zipPath;
  }

  String manifestJson({String app = 'my_flashcards', int schemaVersion = 1}) =>
      jsonEncode(BackupManifest(
        app: app,
        formatVersion: 1,
        schemaVersion: schemaVersion,
        exportedAt: DateTime(2026),
        decks: 0,
        cards: 0,
      ).toJson());

  test('exporta um zip com manifesto, banco e mídias', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');

    final zipPath = okValue(await repository.exportBackup());

    expect(p.basename(zipPath), 'my-flashcards-backup-2026-10-12.zip');
    expect(await zip.listEntries(zipPath),
        containsAll(['manifest.json', 'flashcards.db', 'media/img_1.jpg']));
    final manifest = okValue(await repository.prepareImport(zipPath));
    expect(manifest.decks, 1);
    expect(manifest.cards, 1);
    expect(manifest.exportedAt, DateTime(2026, 10, 12, 20, 15));
  });

  test('exporta mesmo sem nenhum deck', () async {
    final zipPath = okValue(await repository.exportBackup());

    expect(await File(zipPath).exists(), isTrue);
  });

  test('importar devolve exatamente os dados exportados', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');
    final zipPath = okValue(await repository.exportBackup());
    await database.db.delete('decks');
    await mediaFiles.mediaFile('img_1.jpg').delete();
    await seedDeck('Deck novo', image: 'img_2.jpg');

    okValue(await repository.prepareImport(zipPath));
    okValue(await repository.applyImport());

    expect(await deckNames(), ['Inglês']);
    expect(await mediaFiles.mediaFile('img_1.jpg').readAsString(), 'foto');
    expect(await mediaFiles.mediaFile('img_2.jpg').exists(), isFalse);
    expect(await database.db.query('cards'), hasLength(1));
  });

  test('recusa um arquivo que não é zip', () async {
    final notZip = File(p.join(root.path, 'foto.zip'));
    await notZip.writeAsString('não sou um zip');

    expect(await repository.prepareImport(notZip.path),
        isA<Error<BackupManifest>>());
  });

  test('recusa um zip que tenta escrever fora da pasta', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(),
      'flashcards.db': 'x',
      '../fora.txt': 'ataque',
    });

    expect(await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>());
    expect(await File(p.join(root.path, 'backup', 'fora.txt')).exists(),
        isFalse);
    expect(await File(p.join(root.path, 'fora.txt')).exists(), isFalse);
  });

  test('recusa um zip de outro app', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(app: 'outro_app'),
      'flashcards.db': 'x',
    });

    expect(await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>());
  });

  test('recusa um backup de uma versão mais nova do app', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(schemaVersion: 99),
      'flashcards.db': 'x',
    });

    expect(await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>());
  });

  test('recusa um backup com banco corrompido', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(),
      'flashcards.db': 'não sou um banco',
    });

    expect(await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>());
  });

  test('falha no meio da troca devolve os dados originais', () async {
    await seedDeck('Backup', image: 'img_backup.jpg');
    final zipPath = okValue(await repository.exportBackup());
    await database.close();

    await setUpWith(_FailingReopenDatabase(
      factory: databaseFactoryFfi,
      path: p.join(root.path, 'db', DatabaseService.fileName),
    ));
    await database.db.delete('decks');
    await seedDeck('Atual', image: 'img_atual.jpg');
    okValue(await repository.prepareImport(zipPath));

    expect(await repository.applyImport(), isA<Error<void>>());

    expect(await deckNames(), ['Atual']);
    expect(await mediaFiles.mediaFile('img_atual.jpg').readAsString(), 'foto');
  });

  test('cancelImport apaga a pasta extraída', () async {
    final zipPath = okValue(await repository.exportBackup());
    okValue(await repository.prepareImport(zipPath));

    await repository.cancelImport();

    expect(await Directory(p.join(root.path, 'backup', 'import')).exists(),
        isFalse);
  });

  test('pickBackupFile copia o arquivo escolhido, ou devolve null', () async {
    expect(okValue(await repository.pickBackupFile()), isNull);

    final source = File(p.join(root.path, 'escolhido.zip'));
    await source.writeAsString('conteúdo');
    files.nextPick = source.path;

    final copy = okValue(await repository.pickBackupFile());
    expect(await File(copy!).readAsString(), 'conteúdo');
  });

  test('shareBackup entrega o zip ao menu de compartilhar', () async {
    okValue(await repository.shareBackup('/algum/backup.zip'));

    expect(files.shared, ['/algum/backup.zip']);
  });

  test('cleanOldExports apaga os zips antigos', () async {
    final zipPath = okValue(await repository.exportBackup());

    await repository.cleanOldExports();

    expect(await File(zipPath).exists(), isFalse);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/backup_repository_test.dart
```

Esperado: FALHA de compilação (`backup_repository.dart` não existe).

- [ ] **Passo 3: implementar**

`lib/data/repositories/backup_repository.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/backup_manifest.dart';
import '../../utils/dates.dart';
import '../../utils/result.dart';
import '../services/backup_file_service.dart';
import '../services/database_service.dart';
import '../services/media_file_service.dart';
import '../services/zip_service.dart';

class BackupRepository {
  BackupRepository({
    required DatabaseService database,
    required MediaFileService mediaFiles,
    required ZipService zip,
    required BackupFileService files,
    required Directory workDir,
    DateTime Function()? now,
  })  : _database = database,
        _mediaFiles = mediaFiles,
        _zip = zip,
        _files = files,
        _workDir = workDir,
        _now = now ?? DateTime.now;

  static const _manifestName = 'manifest.json';

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final ZipService _zip;
  final BackupFileService _files;
  final Directory _workDir;
  final DateTime Function() _now;

  Directory get _importDir => Directory(p.join(_workDir.path, 'import'));

  /// Builds the backup and returns the path of the .zip.
  Future<Result<String>> exportBackup() => guard(() async {
        final exportDir = await _freshDir('export');
        final now = _now();
        final zipPath = p.join(
          _workDir.path,
          'my-flashcards-backup-${formatDate(now)}.zip',
        );
        try {
          final dbCopy = p.join(exportDir.path, DatabaseService.fileName);
          await _database.copyTo(dbCopy);
          final manifest = BackupManifest(
            app: BackupManifest.appId,
            formatVersion: BackupManifest.currentFormatVersion,
            schemaVersion: DatabaseService.schemaVersion,
            exportedAt: now,
            decks: await _count('decks'),
            cards: await _count('cards'),
          );
          final manifestPath = p.join(exportDir.path, _manifestName);
          await File(manifestPath).writeAsString(jsonEncode(manifest.toJson()));
          final media = await _mediaFiles.mediaDir.exists()
              ? _mediaFiles.mediaDir.listSync().whereType<File>()
              : const <File>[];
          await _zip.createZip(zipPath, {
            _manifestName: manifestPath,
            DatabaseService.fileName: dbCopy,
            for (final file in media) 'media/${p.basename(file.path)}': file.path,
          });
        } on Exception {
          await _deleteIfExists(zipPath);
          rethrow;
        } finally {
          await exportDir.delete(recursive: true);
        }
        return zipPath;
      });

  Future<Result<void>> shareBackup(String zipPath) =>
      guard(() => _files.share(zipPath));

  /// Lets the user choose a backup and returns the path of a local copy of
  /// it, or null when the user cancels.
  Future<Result<String?>> pickBackupFile() => guard(() async {
        await _workDir.create(recursive: true);
        final destination = p.join(_workDir.path, 'import_source.zip');
        return await _files.pickZip(destination) ? destination : null;
      });

  /// Extracts and checks the backup. Returns its manifest, so the user can
  /// confirm before anything changes.
  Future<Result<BackupManifest>> prepareImport(String zipPath) =>
      guard(() async {
        final importDir = await _freshDir('import');
        _checkEntryNames(await _zip.listEntries(zipPath));
        await _zip.extract(zipPath, importDir.path);

        final manifestFile = File(p.join(importDir.path, _manifestName));
        final manifest =
            BackupManifest.fromJson(jsonDecode(await manifestFile.readAsString()));
        if (manifest.app != BackupManifest.appId ||
            manifest.formatVersion != BackupManifest.currentFormatVersion ||
            manifest.schemaVersion > DatabaseService.schemaVersion) {
          throw const FormatException('Backup de outro app ou mais novo.');
        }
        await _database
            .checkReadable(p.join(importDir.path, DatabaseService.fileName));
        return manifest;
      });

  /// Replaces all app data with the prepared backup. The current data is
  /// kept aside and put back if any step fails.
  Future<Result<void>> applyImport() => guard(() async {
        final rollbackDir = await _freshDir('rollback');
        final dbFiles = [
          for (final suffix in ['', '-wal', '-shm', '-journal'])
            '${_database.path}$suffix',
        ];

        await _database.close();
        try {
          for (final path in dbFiles) {
            await _moveIfExists(path, p.join(rollbackDir.path, p.basename(path)));
          }
          await _moveIfExists(
              _mediaFiles.mediaDir.path, p.join(rollbackDir.path, 'media'));
          await _move(
            p.join(_importDir.path, DatabaseService.fileName),
            _database.path,
          );
          await _moveIfExists(
              p.join(_importDir.path, 'media'), _mediaFiles.mediaDir.path);
          await _mediaFiles.ensureDirectories();
          await _database.open();
        } on Exception {
          await _restore(rollbackDir, dbFiles);
          rethrow;
        }
        await rollbackDir.delete(recursive: true);
        await _importDir.delete(recursive: true);
      });

  Future<void> cancelImport() async {
    await guard(() async {
      if (await _importDir.exists()) await _importDir.delete(recursive: true);
    });
  }

  /// Deletes the .zip files of earlier exports and leftover work folders.
  /// The rollback folder is never touched: it may hold the user's data.
  Future<void> cleanOldExports() async {
    await guard(() async {
      if (!await _workDir.exists()) return;
      for (final entity in _workDir.listSync()) {
        final name = p.basename(entity.path);
        if (entity is File && name.endsWith('.zip')) {
          await entity.delete();
        } else if (entity is Directory && (name == 'export' || name == 'import')) {
          await entity.delete(recursive: true);
        }
      }
    });
  }

  Future<void> _restore(Directory rollbackDir, List<String> dbFiles) async {
    try {
      await _database.close();
      for (final path in dbFiles) {
        await _deleteIfExists(path);
      }
      if (await _mediaFiles.mediaDir.exists()) {
        await _mediaFiles.mediaDir.delete(recursive: true);
      }
      for (final path in dbFiles) {
        await _moveIfExists(p.join(rollbackDir.path, p.basename(path)), path);
      }
      await _moveIfExists(
          p.join(rollbackDir.path, 'media'), _mediaFiles.mediaDir.path);
      await _mediaFiles.ensureDirectories();
      await _database.open();
    } on Exception catch (error) {
      debugPrint('Não foi possível restaurar os dados: $error');
    }
  }

  Future<int> _count(String table) async {
    final rows = await _database.db.rawQuery('SELECT COUNT(*) FROM $table');
    return rows.single.values.single! as int;
  }

  Future<Directory> _freshDir(String name) async {
    final dir = Directory(p.join(_workDir.path, name));
    if (await dir.exists()) await dir.delete(recursive: true);
    return dir.create(recursive: true);
  }
}

/// Only the three kinds of entries this app writes are accepted, which also
/// rules out paths that would escape the extraction folder.
void _checkEntryNames(List<String> names) {
  for (final name in names) {
    final parts = p.posix.split(name);
    final allowed = name == 'manifest.json' ||
        name == DatabaseService.fileName ||
        (parts.isNotEmpty && parts.first == 'media' && parts.length <= 2);
    final safe = !p.posix.isAbsolute(name) &&
        !name.contains(r'\') &&
        !parts.contains('..');
    if (!allowed || !safe) {
      throw FormatException('Entrada inesperada no backup: $name');
    }
  }
  if (!names.contains('manifest.json') ||
      !names.contains(DatabaseService.fileName)) {
    throw const FormatException('Backup incompleto.');
  }
}

Future<void> _move(String from, String to) async {
  if (await FileSystemEntity.isDirectory(from)) {
    await Directory(from).rename(to);
  } else {
    await File(from).rename(to);
  }
}

Future<void> _moveIfExists(String from, String to) async {
  if (await FileSystemEntity.type(from) != FileSystemEntityType.notFound) {
    await _move(from, to);
  }
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/data/repositories/backup_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: escrever o repositório falso**

`test/fakes/fake_backup_repository.dart`:
```dart
import 'package:my_flashcards/data/repositories/backup_repository.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';
import 'package:my_flashcards/utils/result.dart';

class FakeBackupRepository implements BackupRepository {
  Exception? exportError;
  String? pickedPath = '/tmp/escolhido.zip';
  Exception? prepareError;
  Exception? applyError;
  BackupManifest manifest = BackupManifest(
    app: BackupManifest.appId,
    formatVersion: 1,
    schemaVersion: 1,
    exportedAt: DateTime(2026, 10, 11, 20, 15),
    decks: 3,
    cards: 87,
  );

  final shared = <String>[];
  var applyCalls = 0;
  var cancelCalls = 0;
  var cleanCalls = 0;

  @override
  Future<Result<String>> exportBackup() async {
    final error = exportError;
    if (error != null) return Result.error(error);
    return const Result.ok('/tmp/my-flashcards-backup-2026-10-12.zip');
  }

  @override
  Future<Result<void>> shareBackup(String zipPath) async {
    shared.add(zipPath);
    return const Result.ok(null);
  }

  @override
  Future<Result<String?>> pickBackupFile() async => Result.ok(pickedPath);

  @override
  Future<Result<BackupManifest>> prepareImport(String zipPath) async {
    final error = prepareError;
    if (error != null) return Result.error(error);
    return Result.ok(manifest);
  }

  @override
  Future<Result<void>> applyImport() async {
    applyCalls++;
    final error = applyError;
    if (error != null) return Result.error(error);
    return const Result.ok(null);
  }

  @override
  Future<void> cancelImport() async => cancelCalls++;

  @override
  Future<void> cleanOldExports() async => cleanCalls++;
}
```

- [ ] **Passo 6: pôr o `BackupRepository` nas dependências do app**

Em `test/app_test.dart`, acrescente o import `import 'fakes/fake_backup_repository.dart';` e, no helper `dependencies`, `backups: FakeBackupRepository(),`.

Em `lib/app_dependencies.dart`:

1. Acrescente os imports:
```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'data/repositories/backup_repository.dart';
import 'data/services/backup_file_service.dart';
import 'data/services/zip_service.dart';
```

2. Acrescente o parâmetro ao construtor e o campo:
```dart
    required this.backups,
```
```dart
  final BackupRepository backups;
```

3. Em `create()`, antes do `return`, acrescente:
```dart
    final temporary = await getTemporaryDirectory();
```
E, dentro do `AppDependencies(...)`:
```dart
      backups: BackupRepository(
        database: database,
        mediaFiles: mediaFiles,
        zip: ZipService(),
        files: BackupFileService(),
        workDir: Directory(p.join(temporary.path, 'backup')),
      ),
```

`lib/main.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  await dependencies.media.clearDrafts();
  await dependencies.backups.cleanOldExports();
  await dependencies.reminders.topUp();
  runApp(App(dependencies: dependencies));
}
```

- [ ] **Passo 7: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 8: commit**

```bash
git add lib/data/repositories/backup_repository.dart lib/app_dependencies.dart lib/main.dart test/fakes/fake_backup_repository.dart test/data/repositories/backup_repository_test.dart test/app_test.dart
git commit -m "feat: cria o BackupRepository com validação e rollback"
```

---

### Tarefa 4: backup no `SettingsViewModel`

> **Ajustes da etapa 6 que esta tarefa precisa manter (2026-10-19):** o `SettingsViewModel` atual tem `with DisposeSafeNotifier`, o parâmetro nomeado privado `required this._reminderRepository`, a proteção contra toque duplo (`isBusy`), o `_isBusy` zerado num `finally` e o `_syncStoredState` (relê o lembrete depois de um erro). **Acrescente o backup ao arquivo atual, sem substituí-lo.** O `resetAfterImport` também limpa `reminder_times`. Se ele desligar o lembrete por falta de permissão, vale avisar a usuária com uma mensagem.

**Arquivos:**
- Modificar: `lib/ui/settings/view_models/settings_view_model.dart` e `lib/routes.dart`
- Testar: modificar `test/ui/settings/settings_view_model_test.dart` e `test/ui/settings/settings_screen_test.dart`

**Interfaces:**
- Consome: `BackupRepository` (tarefa 3) e `ReminderRepository.resetAfterImport`.
- Produz: em `SettingsViewModel`:
  - o construtor passa a ser `SettingsViewModel({required ReminderRepository reminderRepository, required BackupRepository backupRepository})`;
  - os métodos novos:

    | Método | O que faz |
    |---|---|
    | `Future<bool> exportBackup()` | Gera o backup e abre o menu de compartilhar |
    | `Future<BackupManifest?> pickAndPrepareImport()` | Devolve o manifesto para pedir confirmação, ou `null` se a usuária cancelou ou se o arquivo é inválido (nesse caso, com a mensagem em `message`) |
    | `Future<bool> confirmImport()` | Troca os dados e recomeça o lembrete |
    | `Future<void> cancelImport()` | Desiste da importação |

  - as constantes `exportErrorMessage`, `openFileErrorMessage`, `invalidBackupMessage` e `importErrorMessage`.
  - Em `AppRoutes.settings()`, o ViewModel passa a receber `backupRepository: _dependencies.backups`.

- [ ] **Passo 1: ajustar o teste da tela ao construtor novo**

Em `test/ui/settings/settings_screen_test.dart`:

1. Acrescente o import `import '../../fakes/fake_backup_repository.dart';`.

2. Acrescente `late FakeBackupRepository backups;`. Troque o `setUp` e o `pumpScreen` pelos de baixo. A tela agora é aberta a partir de uma página "host", para que a tarefa 5 consiga ver quando ela se fecha:
```dart
  setUp(() {
    reminders = FakeReminderRepository();
    backups = FakeBackupRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  viewModel: SettingsViewModel(
                    reminderRepository: reminders,
                    backupRepository: backups,
                  ),
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }
```
Apague a linha antiga `setUp(() => reminders = FakeReminderRepository());`.

- [ ] **Passo 2: ajustar os testes do ViewModel e escrever os novos**

Em `test/ui/settings/settings_view_model_test.dart`:

1. Acrescente o import `import '../../fakes/fake_backup_repository.dart';`.

2. Acrescente `late FakeBackupRepository backups;`. Troque o `setUp` por:
```dart
  setUp(() {
    reminders = FakeReminderRepository();
    backups = FakeBackupRepository();
    viewModel = SettingsViewModel(
      reminderRepository: reminders,
      backupRepository: backups,
    );
  });
```

3. Acrescente ao fim do `main()`:
```dart
  group('backup', () {
    test('exportar gera o zip e abre o menu de compartilhar', () async {
      expect(await viewModel.exportBackup(), isTrue);

      expect(backups.shared, ['/tmp/my-flashcards-backup-2026-10-12.zip']);
      expect(viewModel.isBusy, isFalse);
    });

    test('falha ao exportar mostra a mensagem', () async {
      backups.exportError = Exception('sem espaço');

      expect(await viewModel.exportBackup(), isFalse);

      expect(viewModel.message, SettingsViewModel.exportErrorMessage);
      expect(backups.shared, isEmpty);
    });

    test('escolher um backup válido devolve o manifesto', () async {
      final manifest = await viewModel.pickAndPrepareImport();

      expect(manifest?.cards, 87);
      expect(viewModel.message, isNull);
    });

    test('cancelar a escolha do arquivo não mostra mensagem', () async {
      backups.pickedPath = null;

      expect(await viewModel.pickAndPrepareImport(), isNull);
      expect(viewModel.message, isNull);
    });

    test('arquivo inválido mostra a mensagem de backup inválido', () async {
      backups.prepareError = const FormatException('não é zip');

      expect(await viewModel.pickAndPrepareImport(), isNull);
      expect(viewModel.message, SettingsViewModel.invalidBackupMessage);
    });

    test('confirmar troca os dados e recomeça o lembrete', () async {
      reminders.enabled = true;

      expect(await viewModel.confirmImport(), isTrue);

      expect(backups.applyCalls, 1);
      expect(reminders.resetCalls, 1);
      expect(viewModel.reminderEnabled, isTrue);
    });

    test('falha ao importar avisa que nada mudou', () async {
      backups.applyError = Exception('falha');

      expect(await viewModel.confirmImport(), isFalse);

      expect(viewModel.message, SettingsViewModel.importErrorMessage);
      expect(reminders.resetCalls, 0);
    });

    test('cancelImport desiste da importação', () async {
      await viewModel.cancelImport();

      expect(backups.cancelCalls, 1);
    });
  });
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/ui/settings/settings_view_model_test.dart
```

Esperado: FALHA de compilação (`backupRepository` não existe).

- [ ] **Passo 4: implementar**

`lib/ui/settings/view_models/settings_view_model.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/backup_repository.dart';
import '../../../data/repositories/reminder_repository.dart';
import '../../../domain/models/backup_manifest.dart';
import '../../../utils/result.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required ReminderRepository reminderRepository,
    required BackupRepository backupRepository,
  })  : _reminderRepository = reminderRepository,
        _backupRepository = backupRepository;

  static const permissionDeniedMessage =
      'Sem permissão para notificações. Ative em Configurações › Apps › '
      'My Flashcards › Notificações.';
  static const reminderErrorMessage = 'Não foi possível mudar o lembrete.';
  static const exportErrorMessage = 'Não foi possível gerar o backup.';
  static const openFileErrorMessage = 'Não foi possível abrir o arquivo.';
  static const invalidBackupMessage =
      'Este arquivo não é um backup do My Flashcards.';
  static const importErrorMessage =
      'Não foi possível importar. Seus dados não foram alterados.';

  final ReminderRepository _reminderRepository;
  final BackupRepository _backupRepository;

  bool _reminderEnabled = false;
  bool _isBusy = false;
  String? _message;

  bool get reminderEnabled => _reminderEnabled;
  bool get isBusy => _isBusy;

  /// The message for the last action that failed.
  String? get message => _message;

  Future<void> load() async {
    if (await _reminderRepository.isEnabled() case Ok(:final value)) {
      _reminderEnabled = value;
    }
    notifyListeners();
  }

  Future<bool> setReminderEnabled(bool enabled) async {
    _begin();
    if (enabled) {
      switch (await _reminderRepository.enable()) {
        case Ok(value: true):
          _reminderEnabled = true;
        case Ok():
          _message = permissionDeniedMessage;
        case Error():
          _message = reminderErrorMessage;
      }
    } else {
      switch (await _reminderRepository.disable()) {
        case Ok():
          _reminderEnabled = false;
        case Error():
          _message = reminderErrorMessage;
      }
    }
    return _end();
  }

  /// Builds the backup and opens the share menu with it.
  Future<bool> exportBackup() async {
    _begin();
    switch (await _backupRepository.exportBackup()) {
      case Ok(value: final zipPath):
        if (await _backupRepository.shareBackup(zipPath) is Error) {
          _message = exportErrorMessage;
        }
      case Error():
        _message = exportErrorMessage;
    }
    return _end();
  }

  /// Lets the user choose a backup and checks it. Returns its manifest, to
  /// ask for confirmation, or null when the user cancelled or the file is
  /// not a valid backup (then [message] says so).
  Future<BackupManifest?> pickAndPrepareImport() async {
    _begin();
    BackupManifest? manifest;
    switch (await _backupRepository.pickBackupFile()) {
      case Ok(value: final zipPath?):
        switch (await _backupRepository.prepareImport(zipPath)) {
          case Ok(:final value):
            manifest = value;
          case Error():
            _message = invalidBackupMessage;
        }
      case Ok():
        break;
      case Error():
        _message = openFileErrorMessage;
    }
    _end();
    return manifest;
  }

  /// Replaces all data with the prepared backup, then restarts the reminder
  /// schedule, which belonged to the old data.
  Future<bool> confirmImport() async {
    _begin();
    if (await _backupRepository.applyImport() is Error) {
      _message = importErrorMessage;
    } else {
      await _reminderRepository.resetAfterImport();
      if (await _reminderRepository.isEnabled() case Ok(:final value)) {
        _reminderEnabled = value;
      }
    }
    return _end();
  }

  Future<void> cancelImport() => _backupRepository.cancelImport();

  void _begin() {
    _isBusy = true;
    _message = null;
    notifyListeners();
  }

  bool _end() {
    _isBusy = false;
    notifyListeners();
    return _message == null;
  }
}
```

- [ ] **Passo 5: passar o `BackupRepository` na rota**

Em `lib/routes.dart`, troque o método `settings` por:
```dart
  Route<void> settings() {
    final viewModel = SettingsViewModel(
      reminderRepository: _dependencies.reminders,
      backupRepository: _dependencies.backups,
    );
    return MaterialPageRoute(
      builder: (_) => SettingsScreen(viewModel: viewModel),
    );
  }
```

- [ ] **Passo 6: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 7: commit**

```bash
git add lib/ui/settings/view_models/settings_view_model.dart lib/routes.dart test/ui/settings
git commit -m "feat: SettingsViewModel exporta e importa backup"
```

---

### Tarefa 5: seção BACKUP na tela de configurações

**Arquivos:**
- Substituir: `lib/ui/settings/widgets/settings_screen.dart`
- Testar: modificar `test/ui/settings/settings_screen_test.dart`

**Interfaces:**
- Consome: `SettingsViewModel.exportBackup`, `pickAndPrepareImport`, `confirmImport` e `cancelImport` (tarefa 4).
- Produz: a função `String importConfirmationText(BackupManifest manifest)`.

- [ ] **Passo 1: escrever os testes**

Em `test/ui/settings/settings_screen_test.dart`, acrescente o import `import 'package:my_flashcards/domain/models/backup_manifest.dart';` e, ao fim do `main()`:
```dart
  testWidgets('Exportar backup abre o menu de compartilhar', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();

    expect(backups.shared, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('falha ao exportar mostra a mensagem', (tester) async {
    backups.exportError = Exception('sem espaço');
    await pumpScreen(tester);

    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível gerar o backup.'), findsOneWidget);
  });

  testWidgets('Importar pede confirmação com o resumo e volta aos decks',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();

    expect(find.text('Substituir todos os dados?'), findsOneWidget);
    expect(
      find.text('O backup de 11/10/2026 tem 3 decks e 87 cards. '
          'Seus decks atuais serão apagados.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();

    expect(backups.applyCalls, 1);
    expect(reminders.resetCalls, 1);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('Cancelar na confirmação não muda nada', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(backups.applyCalls, 0);
    expect(backups.cancelCalls, 1);
    expect(find.text('Configurações'), findsOneWidget);
  });

  testWidgets('arquivo inválido mostra a mensagem e não pede confirmação',
      (tester) async {
    backups.prepareError = const FormatException('não é zip');
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();

    expect(find.text('Este arquivo não é um backup do My Flashcards.'),
        findsOneWidget);
    expect(find.text('Substituir todos os dados?'), findsNothing);
  });

  test('importConfirmationText usa singular e plural', () {
    BackupManifest manifest(int decks, int cards) => BackupManifest(
          app: BackupManifest.appId,
          formatVersion: 1,
          schemaVersion: 1,
          exportedAt: DateTime(2026, 3, 7),
          decks: decks,
          cards: cards,
        );

    expect(
      importConfirmationText(manifest(1, 1)),
      'O backup de 07/03/2026 tem 1 deck e 1 card. '
      'Seus decks atuais serão apagados.',
    );
    expect(
      importConfirmationText(manifest(0, 0)),
      'O backup de 07/03/2026 tem 0 decks e 0 cards. '
      'Seus decks atuais serão apagados.',
    );
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/settings/settings_screen_test.dart
```

Esperado: FALHA de compilação (`importConfirmationText` não existe).

- [ ] **Passo 3: seção BACKUP na tela**

`lib/ui/settings/widgets/settings_screen.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import '../../../app_version.dart';
import '../../../domain/models/backup_manifest.dart';
import '../view_models/settings_view_model.dart';

String importConfirmationText(BackupManifest manifest) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = manifest.exportedAt;
  final when = '${two(date.day)}/${two(date.month)}/${date.year}';
  final decks = manifest.decks == 1 ? '1 deck' : '${manifest.decks} decks';
  final cards = manifest.cards == 1 ? '1 card' : '${manifest.cards} cards';
  return 'O backup de $when tem $decks e $cards. '
      'Seus decks atuais serão apagados.';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsViewModel get _viewModel => widget.viewModel;

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

  void _showMessage() {
    final message = _viewModel.message;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows a blocking progress dialog while [action] runs.
  Future<T> _withProgress<T>(String label, Future<T> Function() action) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await action();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _setReminder(bool enabled) async {
    if (!await _viewModel.setReminderEnabled(enabled)) _showMessage();
  }

  Future<void> _export() async {
    final ok = await _withProgress('Gerando backup…', _viewModel.exportBackup);
    if (!ok) _showMessage();
  }

  Future<void> _import() async {
    final manifest = await _withProgress(
      'Conferindo o arquivo…',
      _viewModel.pickAndPrepareImport,
    );
    if (!mounted) return;
    if (manifest == null) {
      _showMessage();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Substituir todos os dados?'),
        content: Text(importConfirmationText(manifest)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      await _viewModel.cancelImport();
      return;
    }

    final ok = await _withProgress('Importando…', _viewModel.confirmImport);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _showMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('LEMBRETE'),
            SwitchListTile(
              title: const Text('Lembrete diário'),
              subtitle:
                  const Text('Um por dia, em horário aleatório entre 9h e 20h'),
              value: _viewModel.reminderEnabled,
              onChanged: _viewModel.isBusy ? null : _setReminder,
            ),
            const Divider(),
            const _SectionHeader('BACKUP'),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Exportar backup'),
              subtitle: const Text('Gera um .zip com tudo'),
              enabled: !_viewModel.isBusy,
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Importar backup'),
              subtitle: const Text('Substitui todos os dados'),
              enabled: !_viewModel.isBusy,
              onTap: _import,
            ),
            const Divider(),
            const ListTile(title: Text('Versão $appVersion')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
```

- [ ] **Passo 4: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 5: commit**

```bash
git add lib/ui/settings/widgets/settings_screen.dart test/ui/settings/settings_screen_test.dart
git commit -m "feat: exportar e importar backup pelas configurações"
```

---

### Tarefa 6: conferir no celular e fechar a etapa

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

Antes, deixe alguns decks com cards de texto, imagem e áudio, e o lembrete ligado.

- [ ] **Exportar backup** mostra *"Gerando backup…"* e depois o menu de compartilhar do Android
- [ ] Salvar no **Google Drive** funciona, e o arquivo `my-flashcards-backup-AAAA-MM-DD.zip` aparece no Drive
- [ ] No computador, baixe o zip do Drive e liste o conteúdo:
  ```bash
  unzip -l my-flashcards-backup-*.zip
  ```
  Ele tem `manifest.json`, `flashcards.db` e `media/...`.
- [ ] Crie um deck novo "Teste", apague uma imagem de outro card e use **Importar backup** escolhendo o arquivo do Drive
- [ ] A confirmação mostra a data e as quantidades certas
- [ ] **Cancelar** não muda nada
- [ ] **Substituir** volta para a lista de decks: o "Teste" sumiu, e a imagem apagada voltou na revisão
- [ ] Os áudios tocam depois da importação
- [ ] O lembrete continua ligado (confira com `adb shell dumpsys alarm | grep -A2 com.sorayaferreira.myflashcards`)
- [ ] Importar um zip qualquer (por exemplo, de fotos) mostra *"Este arquivo não é um backup do My Flashcards."*
- [ ] Os `.zip` antigos somem da pasta temporária depois de reabrir o app:
  ```bash
  adb shell run-as com.sorayaferreira.myflashcards ls cache/backup
  ```

Se o `.zip` aparecer desativado no seletor de arquivos do Drive, troque, em `BackupFileService.pickZip`, `type: FileType.custom, allowedExtensions: ['zip']` por `type: FileType.any`. A validação do backup continua recusando qualquer outro tipo de arquivo.

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-7-backup -m "Etapa 7: backup" && git branch -d etapa-7-backup
```
