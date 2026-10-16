# Etapa 4: imagens. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** cada lado do card pode ter uma imagem, tirada com a câmera ou escolhida na galeria, que aparece no editor e na revisão. Os arquivos ficam na pasta privada do app e somem quando deixam de ser usados.

**Arquitetura:**
- **Services:**
  - `MediaFileService` cuida das pastas `media/` (definitiva) e `editor_tmp/` (rascunhos), e de mover e apagar arquivos;
  - `ImagePickerService` embrulha o `image_picker`.
- **`MediaRepository`:** é o único caminho dos ViewModels até esses dois services.
- **`CardRepository` e `DeckRepository`:** passam a receber o `MediaFileService` para apagar arquivos órfãos.
- **No editor:**
  1. os arquivos novos ficam como rascunho;
  2. ao salvar, o ViewModel move os rascunhos para `media/` e só então grava o banco;
  3. se o banco falhar, os arquivos voltam a ser rascunho.

**Tecnologias:** `path_provider` 2.1 e `image_picker` 1.2.

**Spec:** [docs/design.md](../design.md), parte 1 ("Ciclo de vida dos arquivos de mídia" e "Como a View recebe a mídia") e parte 3 ("Imagens"). Requisitos RF-06, RF-09 e RNF-04.

**Branch:** `etapa-4-imagens`

## Restrições globais

- **Captura:** `maxWidth: 1280`, `maxHeight: 1280`, `imageQuality: 80`.
- **Permissões:** a câmera abre o app de câmera do sistema e a galeria usa o seletor de fotos do Android 13. **Nenhuma permissão é declarada nem pedida.** Não acrescente `CAMERA` nem `READ_MEDIA_IMAGES` ao manifesto.
- **Banco:** guarda só o nome do arquivo, no formato `img_<epoch-ms>_<4 caracteres>.<extensão>`.
- **Imagem sumida:** aparece *"Imagem não encontrada"*, sem travar o app.
- **Tamanho da decodificação:** imagens são decodificadas na largura em que aparecem (`cacheWidth`).
- **Limpeza:** apagar um card ou um deck, ou trocar ou remover a imagem e salvar, apaga o arquivo antigo. `editor_tmp/` é esvaziada ao abrir o app.
- **Camadas:** ViewModels nunca chamam services. Repositórios não dependem uns dos outros.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Câmera ou galeria cancelada.** Nada muda e nenhuma mensagem de erro aparece. Testado na tarefa 4.
2. **Trocar uma imagem nova antes de salvar.** O primeiro arquivo é apagado na hora e não fica órfão. Testado na tarefa 4.
3. **Descartar o editor depois de escolher imagens.** Os rascunhos são apagados. Testado nas tarefas 4 e 5.
4. **Falha ao gravar o banco depois de mover as imagens.** Os arquivos voltam para rascunho, e nada fica órfão em `media/`. Testado na tarefa 4.
5. **Arquivo de imagem apagado por fora.** O card mostra *"Imagem não encontrada"*, no editor e na revisão. Testado na tarefa 5.

---

### Tarefa 1: `MediaFileService`

**Arquivos:**
- Criar: `lib/data/services/media_file_service.dart`
- Criar: `test/helpers/temp_media.dart`
- Testar: `test/data/services/media_file_service_test.dart`

**Interfaces:**
- Produz:
  - `class MediaFileService`, com:
    - o construtor `MediaFileService({required Directory mediaDir, required Directory draftDir, Random? random, DateTime Function()? now})`;
    - o método `static Future<MediaFileService> create()`, que usa `media/` dentro dos documentos do app e `editor_tmp/` dentro da pasta temporária;
    - os campos `final Directory mediaDir` e `final Directory draftDir`;
    - os métodos:

      | Método | O que faz |
      |---|---|
      | `Future<void> ensureDirectories()` | Cria as duas pastas, se faltarem |
      | `String newFileName(String prefix, String extension)` | Gera um nome novo e único |
      | `File mediaFile(String name)` / `File draftFile(String name)` | Devolvem o arquivo em cada pasta |
      | `Future<String> moveIntoDrafts(String sourcePath, String prefix)` | Move o arquivo para os rascunhos e devolve o nome novo |
      | `Future<void> commitDrafts(Iterable<String> names)` | Move rascunhos para `media/` |
      | `Future<void> revertCommit(Iterable<String> names)` | Desfaz o `commitDrafts` |
      | `Future<void> deleteDrafts(Iterable<String> names)` / `Future<void> deleteMedia(Iterable<String> names)` | Apagam, ignorando o que não existe |
      | `Future<void> clearDrafts()` | Esvazia `editor_tmp/` |

  - Nos testes:
    - `Future<MediaFileService> createTempMediaFiles()`, que usa uma pasta temporária apagada ao fim do teste;
    - `Future<String> writeMedia(MediaFileService files, String name, {bool draft = false})`.

- [ ] **Passo 1: criar o branch e adicionar os pacotes**

```bash
git switch main && git switch -c etapa-4-imagens
flutter pub add path_provider image_picker
```

- [ ] **Passo 2: escrever o helper e o teste**

`test/helpers/temp_media.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:path/path.dart' as p;

/// A [MediaFileService] over a temporary folder deleted after the test.
Future<MediaFileService> createTempMediaFiles() async {
  final root = await Directory.systemTemp.createTemp('my_flashcards_test_');
  addTearDown(() => root.delete(recursive: true));
  final files = MediaFileService(
    mediaDir: Directory(p.join(root.path, 'media')),
    draftDir: Directory(p.join(root.path, 'drafts')),
  );
  await files.ensureDirectories();
  return files;
}

/// Writes a small file named [name] in the media folder, or in the drafts.
Future<String> writeMedia(
  MediaFileService files,
  String name, {
  bool draft = false,
}) async {
  final file = draft ? files.draftFile(name) : files.mediaFile(name);
  await file.writeAsString('conteúdo de teste');
  return name;
}
```

`test/data/services/media_file_service_test.dart`:
```dart
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:path/path.dart' as p;

import '../../helpers/temp_media.dart';

void main() {
  late MediaFileService files;

  setUp(() async => files = await createTempMediaFiles());

  test('newFileName usa prefixo, horário, 4 caracteres e extensão', () {
    final named = MediaFileService(
      mediaDir: files.mediaDir,
      draftDir: files.draftDir,
      random: Random(1),
      now: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );

    expect(
      named.newFileName('img', 'jpg'),
      matches(RegExp(r'^img_1760000000000_[a-z0-9]{4}\.jpg$')),
    );
  });

  test('moveIntoDrafts move o arquivo e mantém a extensão em minúsculas',
      () async {
    final source = File(p.join(files.mediaDir.parent.path, 'IMG_0001.JPG'));
    await source.writeAsString('foto');

    final name = await files.moveIntoDrafts(source.path, 'img');

    expect(name, startsWith('img_'));
    expect(name, endsWith('.jpg'));
    expect(await files.draftFile(name).readAsString(), 'foto');
    expect(await source.exists(), isFalse);
  });

  test('commitDrafts move para media e revertCommit traz de volta', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);

    await files.commitDrafts(['img_1.jpg']);
    expect(await files.mediaFile('img_1.jpg').exists(), isTrue);
    expect(await files.draftFile('img_1.jpg').exists(), isFalse);

    await files.revertCommit(['img_1.jpg']);
    expect(await files.draftFile('img_1.jpg').exists(), isTrue);
    expect(await files.mediaFile('img_1.jpg').exists(), isFalse);
  });

  test('deleteMedia apaga e ignora arquivos que não existem', () async {
    await writeMedia(files, 'img_1.jpg');

    await files.deleteMedia(['img_1.jpg', 'nao_existe.jpg']);

    expect(await files.mediaFile('img_1.jpg').exists(), isFalse);
  });

  test('deleteDrafts apaga só da pasta de rascunhos', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);
    await writeMedia(files, 'img_1.jpg');

    await files.deleteDrafts(['img_1.jpg']);

    expect(await files.draftFile('img_1.jpg').exists(), isFalse);
    expect(await files.mediaFile('img_1.jpg').exists(), isTrue);
  });

  test('clearDrafts esvazia a pasta de rascunhos', () async {
    await writeMedia(files, 'a.jpg', draft: true);
    await writeMedia(files, 'b.m4a', draft: true);

    await files.clearDrafts();

    expect(await files.draftDir.exists(), isTrue);
    expect(files.draftDir.listSync(), isEmpty);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/data/services/media_file_service_test.dart
```

Esperado: FALHA de compilação (`media_file_service.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/data/services/media_file_service.dart`:
```dart
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's private media folder, plus the scratch folder where the editor
/// keeps new files until the card is saved.
class MediaFileService {
  MediaFileService({
    required this.mediaDir,
    required this.draftDir,
    Random? random,
    DateTime Function()? now,
  })  : _random = random ?? Random(),
        _now = now ?? DateTime.now;

  final Directory mediaDir;
  final Directory draftDir;
  final Random _random;
  final DateTime Function() _now;

  static Future<MediaFileService> create() async {
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await getTemporaryDirectory();
    final files = MediaFileService(
      mediaDir: Directory(p.join(documents.path, 'media')),
      draftDir: Directory(p.join(temporary.path, 'editor_tmp')),
    );
    await files.ensureDirectories();
    return files;
  }

  Future<void> ensureDirectories() async {
    await mediaDir.create(recursive: true);
    await draftDir.create(recursive: true);
  }

  /// A new file name such as `img_1760000000000_a3f9.jpg`.
  String newFileName(String prefix, String extension) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = String.fromCharCodes([
      for (var i = 0; i < 4; i++) chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
    return '${prefix}_${_now().millisecondsSinceEpoch}_$suffix.$extension';
  }

  File mediaFile(String name) => File(p.join(mediaDir.path, name));

  File draftFile(String name) => File(p.join(draftDir.path, name));

  /// Moves [sourcePath] into the draft folder under a new name and returns
  /// that name.
  Future<String> moveIntoDrafts(String sourcePath, String prefix) async {
    final extension =
        p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final name = newFileName(prefix, extension.isEmpty ? 'bin' : extension);
    await _move(File(sourcePath), draftFile(name).path);
    return name;
  }

  Future<void> commitDrafts(Iterable<String> names) async {
    for (final name in names) {
      await _move(draftFile(name), mediaFile(name).path);
    }
  }

  Future<void> revertCommit(Iterable<String> names) async {
    for (final name in names) {
      final file = mediaFile(name);
      if (await file.exists()) await _move(file, draftFile(name).path);
    }
  }

  Future<void> deleteDrafts(Iterable<String> names) =>
      _deleteAll(names.map(draftFile));

  Future<void> deleteMedia(Iterable<String> names) =>
      _deleteAll(names.map(mediaFile));

  Future<void> clearDrafts() async {
    if (await draftDir.exists()) await draftDir.delete(recursive: true);
    await draftDir.create(recursive: true);
  }
}

Future<void> _move(File file, String destination) async {
  try {
    await file.rename(destination);
  } on FileSystemException {
    // rename can't cross file systems; copying can.
    await file.copy(destination);
    await file.delete();
  }
}

Future<void> _deleteAll(Iterable<File> files) async {
  for (final file in files) {
    if (await file.exists()) await file.delete();
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/data/services/media_file_service_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/services/media_file_service.dart test/helpers/temp_media.dart test/data/services/media_file_service_test.dart
git commit -m "feat: cria o MediaFileService para as pastas de mídia"
```

---

### Tarefa 2: `ImagePickerService` e `MediaRepository`

**Arquivos:**
- Criar: `lib/domain/models/image_origin.dart`
- Criar: `lib/data/services/image_picker_service.dart`
- Criar: `lib/data/repositories/media_repository.dart`
- Criar: `test/fakes/fake_media_repository.dart`
- Modificar: `lib/app_dependencies.dart` e `lib/main.dart`
- Testar: `test/data/repositories/media_repository_test.dart`. Modificar: `test/app_test.dart`

**Interfaces:**
- Consome: `MediaFileService` (tarefa 1).
- Produz:
  - `enum ImageOrigin { camera, gallery }`;
  - `class ImagePickerService`, com o construtor `ImagePickerService({ImagePicker? picker})` e o método `Future<String?> pickImage(ImageOrigin origin)`, que devolve `null` quando a usuária cancela;
  - `class MediaRepository`, com o construtor `MediaRepository({required MediaFileService files, required ImagePickerService imagePicker})` e os métodos:

    | Método | O que faz |
    |---|---|
    | `Future<Result<String?>> pickImage(ImageOrigin origin)` | Devolve o nome do rascunho, ou `null` se a usuária cancelou |
    | `String draftPath(String name)` / `String mediaPath(String name)` | Devolvem o caminho completo em cada pasta |
    | `Future<Result<void>> commitDrafts(Iterable<String> names)` | Move rascunhos para `media/` |
    | `Future<void> revertCommit(Iterable<String> names)` | Desfaz o `commitDrafts`. Nunca falha: um erro só é registrado |
    | `Future<void> discardDrafts(Iterable<String> names)` | Apaga rascunhos. Nunca falha |
    | `Future<void> clearDrafts()` | Esvazia `editor_tmp/`. Nunca falha |

  **A etapa 5 acrescenta os métodos de áudio.**
  - Em `AppDependencies`, o campo novo `final MediaRepository media`, com o construtor `AppDependencies({required this.decks, required this.cards, required this.media})`.
  - Em `main.dart`, `editor_tmp/` passa a ser esvaziada ao abrir o app.
  - Nos testes: `FakeMediaRepository`, com:
    - `Object? nextPick` (um nome, `null` para "cancelou" ou uma `Exception`) e `Exception? commitError`;
    - as listas `picks`, `committed`, `reverted` e `discarded`;
    - o contador `clearedDrafts`.

- [ ] **Passo 1: escrever o teste**

`test/data/repositories/media_repository_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/data/services/image_picker_service.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';
import 'package:path/path.dart' as p;

import '../../helpers/result.dart';
import '../../helpers/temp_media.dart';

/// Returns whatever path the test puts in [nextPath], or throws [error].
class _FakeImagePicker implements ImagePickerService {
  String? nextPath;
  Exception? error;
  final origins = <ImageOrigin>[];

  @override
  Future<String?> pickImage(ImageOrigin origin) async {
    origins.add(origin);
    if (error != null) throw error!;
    return nextPath;
  }
}

void main() {
  late MediaFileService files;
  late _FakeImagePicker picker;
  late MediaRepository repository;

  setUp(() async {
    files = await createTempMediaFiles();
    picker = _FakeImagePicker();
    repository = MediaRepository(files: files, imagePicker: picker);
  });

  test('pickImage traz a foto escolhida para os rascunhos', () async {
    final picked = File(p.join(files.mediaDir.parent.path, 'scaled_1.jpg'));
    await picked.writeAsString('foto');
    picker.nextPath = picked.path;

    final name = okValue(await repository.pickImage(ImageOrigin.camera));

    expect(picker.origins, [ImageOrigin.camera]);
    expect(name, startsWith('img_'));
    expect(await File(repository.draftPath(name!)).readAsString(), 'foto');
    expect(await picked.exists(), isFalse);
  });

  test('pickImage cancelado devolve null', () async {
    expect(okValue(await repository.pickImage(ImageOrigin.gallery)), isNull);
  });

  test('pickImage com erro do seletor devolve Error', () async {
    picker.error = Exception('câmera ocupada');

    expect(
      await repository.pickImage(ImageOrigin.camera),
      isA<Error<String?>>(),
    );
  });

  test('commitDrafts e revertCommit movem entre as pastas', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);

    okValue(await repository.commitDrafts(['img_1.jpg']));
    expect(await File(repository.mediaPath('img_1.jpg')).exists(), isTrue);

    await repository.revertCommit(['img_1.jpg']);
    expect(await File(repository.draftPath('img_1.jpg')).exists(), isTrue);
  });

  test('commitDrafts de um rascunho inexistente devolve Error', () async {
    expect(await repository.commitDrafts(['sumiu.jpg']), isA<Error<void>>());
  });

  test('discardDrafts e clearDrafts apagam rascunhos', () async {
    await writeMedia(files, 'a.jpg', draft: true);
    await writeMedia(files, 'b.jpg', draft: true);

    await repository.discardDrafts(['a.jpg']);
    expect(await files.draftFile('a.jpg').exists(), isFalse);

    await repository.clearDrafts();
    expect(files.draftDir.listSync(), isEmpty);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/media_repository_test.dart
```

Esperado: FALHA de compilação (os arquivos não existem).

- [ ] **Passo 3: implementar**

`lib/domain/models/image_origin.dart`:
```dart
enum ImageOrigin { camera, gallery }
```

`lib/data/services/image_picker_service.dart`:
```dart
import 'package:image_picker/image_picker.dart';

import '../../domain/models/image_origin.dart';

class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxDimension = 1280.0;
  static const quality = 80;

  final ImagePicker _picker;

  /// Opens the system camera or photo picker. Returns the path of the image,
  /// already resized and compressed, or null when the user cancels.
  Future<String?> pickImage(ImageOrigin origin) async {
    final file = await _picker.pickImage(
      source: switch (origin) {
        ImageOrigin.camera => ImageSource.camera,
        ImageOrigin.gallery => ImageSource.gallery,
      },
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}
```

`lib/data/repositories/media_repository.dart`:
```dart
import '../../domain/models/image_origin.dart';
import '../../utils/result.dart';
import '../services/image_picker_service.dart';
import '../services/media_file_service.dart';

class MediaRepository {
  MediaRepository({
    required MediaFileService files,
    required ImagePickerService imagePicker,
  })  : _files = files,
        _imagePicker = imagePicker;

  final MediaFileService _files;
  final ImagePickerService _imagePicker;

  /// Lets the user take or choose a picture and keeps it as a draft. Returns
  /// the draft's file name, or null when the user cancels.
  Future<Result<String?>> pickImage(ImageOrigin origin) => guard(() async {
        final path = await _imagePicker.pickImage(origin);
        if (path == null) return null;
        return _files.moveIntoDrafts(path, 'img');
      });

  String draftPath(String name) => _files.draftFile(name).path;

  String mediaPath(String name) => _files.mediaFile(name).path;

  Future<Result<void>> commitDrafts(Iterable<String> names) =>
      guard(() => _files.commitDrafts(names));

  // The clean-up steps below never fail: at worst a stray file stays behind,
  // and guard() already logs the error.

  Future<void> revertCommit(Iterable<String> names) async {
    await guard(() => _files.revertCommit(names));
  }

  Future<void> discardDrafts(Iterable<String> names) async {
    await guard(() => _files.deleteDrafts(names));
  }

  Future<void> clearDrafts() async {
    await guard(_files.clearDrafts);
  }
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/data/repositories/media_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: escrever o repositório falso**

`test/fakes/fake_media_repository.dart`:
```dart
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';

/// [MediaRepository] that records calls. Paths start with /drafts or /media
/// and point nowhere.
class FakeMediaRepository implements MediaRepository {
  /// What the next [pickImage] returns: a file name, null for "cancelled",
  /// or an [Exception] for a failure.
  Object? nextPick;
  Exception? commitError;

  final picks = <ImageOrigin>[];
  final committed = <String>[];
  final reverted = <String>[];
  final discarded = <String>[];
  var clearedDrafts = 0;

  @override
  Future<Result<String?>> pickImage(ImageOrigin origin) async {
    picks.add(origin);
    final next = nextPick;
    if (next is Exception) return Result.error(next);
    return Result.ok(next as String?);
  }

  @override
  String draftPath(String name) => '/drafts/$name';

  @override
  String mediaPath(String name) => '/media/$name';

  @override
  Future<Result<void>> commitDrafts(Iterable<String> names) async {
    final error = commitError;
    if (error != null) return Result.error(error);
    committed.addAll(names);
    return const Result.ok(null);
  }

  @override
  Future<void> revertCommit(Iterable<String> names) async =>
      reverted.addAll(names);

  @override
  Future<void> discardDrafts(Iterable<String> names) async =>
      discarded.addAll(names);

  @override
  Future<void> clearDrafts() async => clearedDrafts++;
}
```

- [ ] **Passo 6: pôr o `MediaRepository` nas dependências do app**

Em `test/app_test.dart`, acrescente o import `import 'fakes/fake_media_repository.dart';` e troque o helper `dependencies` por:
```dart
  AppDependencies dependencies({
    List<Deck> decks = const [],
    List<Flashcard> cards = const [],
  }) =>
      AppDependencies(
        decks: FakeDeckRepository(decks),
        cards: FakeCardRepository(cards),
        media: FakeMediaRepository(),
      );
```

`lib/app_dependencies.dart` (substitui o arquivo inteiro):
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/repositories/media_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/image_picker_service.dart';
import 'data/services/media_file_service.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({
    required this.decks,
    required this.cards,
    required this.media,
  });

  final DeckRepository decks;
  final CardRepository cards;
  final MediaRepository media;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    final mediaFiles = await MediaFileService.create();
    return AppDependencies(
      decks: DeckRepository(database: database),
      cards: CardRepository(database: database),
      media: MediaRepository(
        files: mediaFiles,
        imagePicker: ImagePickerService(),
      ),
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
  await dependencies.media.clearDrafts();
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
git add lib/domain/models/image_origin.dart lib/data/services/image_picker_service.dart lib/data/repositories/media_repository.dart lib/app_dependencies.dart lib/main.dart test/fakes/fake_media_repository.dart test/data/repositories/media_repository_test.dart test/app_test.dart
git commit -m "feat: cria o MediaRepository com câmera e galeria e limpa rascunhos ao abrir"
```

---

### Tarefa 3: repositórios apagam os arquivos que deixam de ser usados

**Arquivos:**
- Modificar: `lib/data/repositories/card_repository.dart`
- Modificar: `lib/data/repositories/deck_repository.dart`
- Testar: modificar `test/data/repositories/card_repository_test.dart` e `test/data/repositories/deck_repository_test.dart`

**Interfaces:**
- Consome: `MediaFileService.deleteMedia`.
- Produz: os construtores passam a ser:
  - `CardRepository({required DatabaseService database, required MediaFileService mediaFiles, DateTime Function()? now})`;
  - `DeckRepository({required DatabaseService database, required MediaFileService mediaFiles, DateTime Function()? now})`.

  Os métodos públicos não mudam.

- [ ] **Passo 1: ajustar o `setUp` dos testes e acrescentar os testes novos**

Em `test/data/repositories/card_repository_test.dart`:

1. Acrescente os imports:
```dart
import 'package:my_flashcards/data/services/media_file_service.dart';

import '../../helpers/temp_media.dart';
```

2. Acrescente `late MediaFileService mediaFiles;` junto das outras variáveis `late`. No `setUp`, troque a criação do repositório por:
```dart
    mediaFiles = await createTempMediaFiles();
    var clock = DateTime(2026, 10, 12, 9);
    repository = CardRepository(
      database: database,
      mediaFiles: mediaFiles,
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
```

3. Acrescente ao fim do `main()`:
```dart
  test('updateCard apaga a imagem trocada e mantém as outras', () async {
    await writeMedia(mediaFiles, 'img_velha.jpg');
    await writeMedia(mediaFiles, 'img_verso.jpg');
    await writeMedia(mediaFiles, 'img_nova.jpg');
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(text: 'a', image: 'img_velha.jpg'),
      back: const CardSide(image: 'img_verso.jpg'),
    ));

    okValue(await repository.updateCard(
      id: card.id,
      front: const CardSide(text: 'a', image: 'img_nova.jpg'),
      back: const CardSide(image: 'img_verso.jpg'),
    ));

    expect(await mediaFiles.mediaFile('img_velha.jpg').exists(), isFalse);
    expect(await mediaFiles.mediaFile('img_verso.jpg').exists(), isTrue);
    expect(await mediaFiles.mediaFile('img_nova.jpg').exists(), isTrue);
  });

  test('deleteCard apaga os arquivos do card', () async {
    await writeMedia(mediaFiles, 'img_1.jpg');
    final card = okValue(await repository.createCard(
      deckId: deckId,
      front: const CardSide(image: 'img_1.jpg'),
      back: const CardSide(text: 'b'),
    ));

    okValue(await repository.deleteCard(card.id));

    expect(await mediaFiles.mediaFile('img_1.jpg').exists(), isFalse);
  });
```

Em `test/data/repositories/deck_repository_test.dart`:

1. Acrescente os imports:
```dart
import 'package:my_flashcards/data/services/media_file_service.dart';

import '../../helpers/temp_media.dart';
```

2. Acrescente `late MediaFileService mediaFiles;`. No `setUp`, troque a criação do repositório por:
```dart
    mediaFiles = await createTempMediaFiles();
    repository = DeckRepository(
      database: database,
      mediaFiles: mediaFiles,
      now: () => now,
    );
```

3. Acrescente ao fim do `main()`:
```dart
  test('excluir o deck apaga os arquivos dos cards dele, e só deles',
      () async {
    final deck = okValue(await repository.createDeck('Com imagens'));
    final other = okValue(await repository.createDeck('Outro'));
    await writeMedia(mediaFiles, 'img_deck.jpg');
    await writeMedia(mediaFiles, 'aud_deck.m4a');
    await writeMedia(mediaFiles, 'img_outro.jpg');
    await database.db.insert('cards', {
      'deck_id': deck.id,
      'front_image': 'img_deck.jpg',
      'back_audio': 'aud_deck.m4a',
      'created_at': 0,
    });
    await database.db.insert('cards', {
      'deck_id': other.id,
      'front_image': 'img_outro.jpg',
      'back_text': 'x',
      'created_at': 0,
    });

    okValue(await repository.deleteDeck(deck.id));

    expect(await mediaFiles.mediaFile('img_deck.jpg').exists(), isFalse);
    expect(await mediaFiles.mediaFile('aud_deck.m4a').exists(), isFalse);
    expect(await mediaFiles.mediaFile('img_outro.jpg').exists(), isTrue);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/data/repositories/card_repository_test.dart test/data/repositories/deck_repository_test.dart
```

Esperado: FALHA de compilação (`mediaFiles` não existe nos construtores).

- [ ] **Passo 3: implementar no `CardRepository`**

Em `lib/data/repositories/card_repository.dart`:

1. Acrescente os imports:
```dart
import 'package:flutter/foundation.dart';

import '../services/media_file_service.dart';
```

2. Troque o construtor e os campos por:
```dart
  CardRepository({
    required DatabaseService database,
    required MediaFileService mediaFiles,
    DateTime Function()? now,
  })  : _database = database,
        _mediaFiles = mediaFiles,
        _now = now ?? DateTime.now;

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final DateTime Function() _now;
```

3. Troque `updateCard` e `deleteCard` por:
```dart
  Future<Result<void>> updateCard({
    required int id,
    required CardSide front,
    required CardSide back,
  }) =>
      guard(() async {
        final old = _cardFromRow(await _findRow(id));
        await _database.db.update(
          'cards',
          {..._sideToRow('front', front), ..._sideToRow('back', back)},
          where: 'id = ?',
          whereArgs: [id],
        );
        final kept = {...front.fileNames, ...back.fileNames};
        await _deleteFiles(old.fileNames.where((name) => !kept.contains(name)));
      });

  Future<Result<void>> deleteCard(int id) => guard(() async {
        final rows =
            await _database.db.query('cards', where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) return;
        await _database.db.delete('cards', where: 'id = ?', whereArgs: [id]);
        await _deleteFiles(_cardFromRow(rows.single).fileNames);
      });
```

4. Acrescente este método privado à classe:
```dart
  /// A file that can't be deleted only wastes space, so it never fails the
  /// operation that made it unused.
  Future<void> _deleteFiles(Iterable<String> names) async {
    try {
      await _mediaFiles.deleteMedia(names);
    } on Exception catch (error) {
      debugPrint('$error');
    }
  }
```

- [ ] **Passo 4: implementar no `DeckRepository`**

Em `lib/data/repositories/deck_repository.dart`:

1. Acrescente os imports:
```dart
import 'package:flutter/foundation.dart';

import '../services/media_file_service.dart';
```

2. Troque o construtor e os campos por:
```dart
  DeckRepository({
    required DatabaseService database,
    required MediaFileService mediaFiles,
    DateTime Function()? now,
  })  : _database = database,
        _mediaFiles = mediaFiles,
        _now = now ?? DateTime.now;

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final DateTime Function() _now;
```

3. Troque `deleteDeck` por:
```dart
  Future<Result<void>> deleteDeck(int id) => guard(() async {
        final rows = await _database.db.query(
          'cards',
          columns: ['front_image', 'front_audio', 'back_image', 'back_audio'],
          where: 'deck_id = ?',
          whereArgs: [id],
        );
        await _database.db.delete('decks', where: 'id = ?', whereArgs: [id]);
        final names = [
          for (final row in rows)
            for (final value in row.values)
              if (value is String) value,
        ];
        try {
          await _mediaFiles.deleteMedia(names);
        } on Exception catch (error) {
          debugPrint('$error');
        }
      });
```

- [ ] **Passo 5: passar o `MediaFileService` aos repositórios no app**

Em `lib/app_dependencies.dart`, dentro de `create()`, troque as duas linhas dos repositórios por:
```dart
      decks: DeckRepository(database: database, mediaFiles: mediaFiles),
      cards: CardRepository(database: database, mediaFiles: mediaFiles),
```

- [ ] **Passo 6: rodar todos os testes**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 7: commit**

```bash
git add lib/data/repositories/card_repository.dart lib/data/repositories/deck_repository.dart lib/app_dependencies.dart test/data/repositories/card_repository_test.dart test/data/repositories/deck_repository_test.dart
git commit -m "feat: apaga arquivos de mídia que deixam de ser usados"
```

---

### Tarefa 4: imagem no `SideDraft` e no `CardEditorViewModel`

**Arquivos:**
- Substituir: `lib/ui/card_editor/view_models/side_draft.dart`
- Substituir: `lib/ui/card_editor/view_models/card_editor_view_model.dart`
- Modificar: `lib/routes.dart` e `lib/ui/card_editor/widgets/card_editor_screen.dart`
- Testar: modificar `test/ui/card_editor/card_editor_view_model_test.dart` e `test/ui/card_editor/card_editor_screen_test.dart`

**Interfaces:**
- Consome: `MediaRepository` (tarefa 2).
- Produz:
  - `class DraftFile`, com o construtor `const DraftFile(String name, {required bool isNew})`. `isNew` quer dizer que o arquivo ainda está em `editor_tmp/`.
  - Em `SideDraft`:
    - o campo novo `DraftFile? image`;
    - os membros novos `List<String> newFileNames` e `SideDraft withImage(DraftFile? image)`.
  - Em `CardEditorViewModel`:
    - o parâmetro novo de construtor `required MediaRepository mediaRepository`;
    - os métodos novos `String? imagePath(Side side)`, `Future<bool> pickImage(Side side, ImageOrigin origin)`, `Future<void> removeImage(Side side)` e `Future<void> discard()`;
    - a constante `imageErrorMessage`.
  - Em `CardEditorScreen`: descartar as alterações chama `viewModel.discard()` antes de sair.

- [ ] **Passo 1: ajustar o teste da tela ao construtor novo**

Em `test/ui/card_editor/card_editor_screen_test.dart`:
1. Acrescente o import `import '../../fakes/fake_media_repository.dart';`.
2. Acrescente `late FakeMediaRepository media;` junto de `late FakeCardRepository cards;`.
3. No `setUp`, acrescente `media = FakeMediaRepository();`.
4. Em `openEditor`, passe `mediaRepository: media` para o `CardEditorViewModel`.

- [ ] **Passo 2: ajustar os testes do ViewModel e escrever os novos**

Em `test/ui/card_editor/card_editor_view_model_test.dart`:

1. Acrescente os imports:
```dart
import 'package:my_flashcards/domain/models/image_origin.dart';

import '../../fakes/fake_media_repository.dart';
```

2. Acrescente `late FakeMediaRepository media;`. Troque o `setUp` e os helpers por:
```dart
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
```

3. No teste `'card inexistente mostra erro de carregamento'`, troque a criação do ViewModel por `final viewModel = editCard(cardId: 99);`.

4. Acrescente ao fim do `main()`:
```dart
  group('imagens', () {
    test('pickImage põe a imagem nova no lado, com o caminho de rascunho',
        () async {
      media.nextPick = 'img_1.jpg';
      final viewModel = newCard();

      expect(await viewModel.pickImage(Side.front, ImageOrigin.camera), isTrue);

      expect(media.picks, [ImageOrigin.camera]);
      expect(viewModel.draft(Side.front).image?.name, 'img_1.jpg');
      expect(viewModel.imagePath(Side.front), '/drafts/img_1.jpg');
      expect(viewModel.hasChanges, isTrue);
    });

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

    test('remover uma imagem já salva não apaga o arquivo antes de salvar',
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
    });

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
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/ui/card_editor/card_editor_view_model_test.dart
```

Esperado: FALHA de compilação (`mediaRepository` e `pickImage` não existem).

- [ ] **Passo 4: implementar o `SideDraft` com imagem**

`lib/ui/card_editor/view_models/side_draft.dart` (substitui o arquivo inteiro):
```dart
import '../../../domain/models/card_side.dart';

/// A media file used by a draft. A new file stays in the editor's draft
/// folder until the card is saved.
class DraftFile {
  const DraftFile(this.name, {required this.isNew});

  final String name;
  final bool isNew;

  @override
  bool operator ==(Object other) =>
      other is DraftFile && other.name == name && other.isNew == isNew;

  @override
  int get hashCode => Object.hash(name, isNew);
}

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = '', this.image});

  factory SideDraft.fromCardSide(CardSide side) => SideDraft(
        text: side.text ?? '',
        image: side.image == null ? null : DraftFile(side.image!, isNew: false),
      );

  final String text;
  final DraftFile? image;

  bool get isEmpty => text.trim().isEmpty && image == null;

  /// Files created during this editing session, still in the draft folder.
  List<String> get newFileNames => [
        if (image case DraftFile(:final name, isNew: true)) name,
      ];

  SideDraft withText(String text) => SideDraft(text: text, image: image);

  SideDraft withImage(DraftFile? image) => SideDraft(text: text, image: image);

  CardSide toCardSide() => CardSide(
        text: text.trim().isEmpty ? null : text.trim(),
        image: image?.name,
      );

  @override
  bool operator ==(Object other) =>
      other is SideDraft && other.text == text && other.image == image;

  @override
  int get hashCode => Object.hash(text, image);
}
```

- [ ] **Passo 5: implementar o `CardEditorViewModel` com imagem**

`lib/ui/card_editor/view_models/card_editor_view_model.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../domain/models/image_origin.dart';
import '../../../utils/result.dart';
import 'side_draft.dart';

class CardEditorViewModel extends ChangeNotifier {
  CardEditorViewModel({
    required this.deckId,
    this.cardId,
    required CardRepository cardRepository,
    required MediaRepository mediaRepository,
  })  : _cardRepository = cardRepository,
        _mediaRepository = mediaRepository;

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';
  static const imageErrorMessage = 'Não foi possível carregar a imagem.';

  final int deckId;
  final int? cardId;
  final CardRepository _cardRepository;
  final MediaRepository _mediaRepository;

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

  /// The full path of the side's image, wherever the file currently lives.
  String? imagePath(Side side) {
    final image = draft(side).image;
    if (image == null) return null;
    return image.isNew
        ? _mediaRepository.draftPath(image.name)
        : _mediaRepository.mediaPath(image.name);
  }

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

  /// Returns false only when the picker failed; cancelling is not a failure.
  Future<bool> pickImage(Side side, ImageOrigin origin) async {
    switch (await _mediaRepository.pickImage(origin)) {
      case Ok(value: final name?):
        await _dropIfNew(draft(side).image);
        _setDraft(side, draft(side).withImage(DraftFile(name, isNew: true)));
        return true;
      case Ok():
        return true;
      case Error():
        _actionError = imageErrorMessage;
        notifyListeners();
        return false;
    }
  }

  Future<void> removeImage(Side side) async {
    await _dropIfNew(draft(side).image);
    _setDraft(side, draft(side).withImage(null));
  }

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();

    final newFiles = [..._front.newFileNames, ..._back.newFileNames];
    if (await _mediaRepository.commitDrafts(newFiles) is Error) {
      await _mediaRepository.revertCommit(newFiles);
      return _saveFailed();
    }

    final front = _front.toCardSide();
    final back = _back.toCardSide();
    final id = cardId;
    final result = id == null
        ? await _cardRepository.createCard(
            deckId: deckId, front: front, back: back)
        : await _cardRepository.updateCard(id: id, front: front, back: back);
    if (result is Error) {
      await _mediaRepository.revertCommit(newFiles);
      return _saveFailed();
    }

    _isSaving = false;
    _front = _initialFront = SideDraft.fromCardSide(front);
    _back = _initialBack = SideDraft.fromCardSide(back);
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
    await discard();
    return true;
  }

  /// Throws away the files created while editing. Call it when leaving
  /// without saving.
  Future<void> discard() => _mediaRepository
      .discardDrafts([..._front.newFileNames, ..._back.newFileNames]);

  bool _saveFailed() {
    _isSaving = false;
    _actionError = saveErrorMessage;
    notifyListeners();
    return false;
  }

  /// Deletes a file created in this session. Files that were already saved
  /// stay until the card is saved without them.
  Future<void> _dropIfNew(DraftFile? file) async {
    if (file != null && file.isNew) {
      await _mediaRepository.discardDrafts([file.name]);
    }
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

- [ ] **Passo 6: descartar apaga os rascunhos, e a rota passa o `MediaRepository`**

Em `lib/ui/card_editor/widgets/card_editor_screen.dart`, em `_confirmDiscard`, troque a última linha (`if (discard == true && mounted) Navigator.of(context).pop(false);`) por:
```dart
    if (discard != true) return;
    await _viewModel.discard();
    if (mounted) Navigator.of(context).pop(false);
```

Em `lib/routes.dart`, no método `cardEditor`, acrescente ao `CardEditorViewModel`:
```dart
      mediaRepository: _dependencies.media,
```

- [ ] **Passo 7: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 8: commit**

```bash
git add lib/ui/card_editor lib/routes.dart test/ui/card_editor
git commit -m "feat: editor guarda imagens como rascunho até salvar"
```

---

### Tarefa 5: imagem nas telas (editor e revisão)

> **Ajuste herdado da etapa 3 (2026-10-16):** o `ReviewCardFace` (`lib/ui/review/widgets/review_card_face.dart`) usa um `Stack` com 28 px fixos de espaço para a etiqueta e o contador. Com fonte grande no sistema, ou com imagem no card, eles podem encostar no conteúdo. Nesta tarefa, troque o `Stack` por uma `Column`: a etiqueta em cima, o conteúdo num `Expanded` e o contador numa linha alinhada à direita, mantendo a `Key('review-count')`. Os testes da revisão continuam valendo.

**Arquivos:**
- Criar: `lib/ui/core/widgets/media_image.dart`
- Substituir: `lib/ui/core/widgets/card_side_view.dart` e `lib/ui/card_editor/widgets/side_editor.dart`
- Modificar: `lib/ui/card_editor/widgets/card_editor_screen.dart`, `lib/ui/review/view_models/review_view_model.dart`, `lib/ui/review/widgets/review_screen.dart` e `lib/routes.dart`
- Testar:
  - criar `test/ui/core/media_image_test.dart`;
  - modificar `test/ui/card_editor/card_editor_screen_test.dart`, `test/ui/review/review_view_model_test.dart` e `test/ui/review/review_screen_test.dart`.

**Interfaces:**
- Consome: `CardEditorViewModel.imagePath`, `pickImage` e `removeImage` (tarefa 4), e `MediaRepository.mediaPath`.
- Produz:
  - `class MediaImage extends StatelessWidget`, com o construtor `const MediaImage({super.key, required String path, double? width, double? height, BoxFit fit = BoxFit.contain})`;
  - `CardSideView({String? text, String? imagePath})`;
  - em `SideEditor`, os parâmetros novos `String? imagePath`, `required VoidCallback onTakePhoto`, `required VoidCallback onPickFromGallery` e `required VoidCallback onRemoveImage`;
  - em `ReviewViewModel`:
    - o parâmetro novo de construtor `required MediaRepository mediaRepository`;
    - o método `String? imagePathOf(CardSide side)`.

- [ ] **Passo 1: escrever os testes**

`test/ui/core/media_image_test.dart`:
```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/core/widgets/card_side_view.dart';
import 'package:my_flashcards/ui/core/widgets/media_image.dart';
import 'package:path/path.dart' as p;

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('arquivo inexistente mostra "Imagem não encontrada"',
      (tester) async {
    await tester.pumpWidget(host(
      const MediaImage(path: '/nao/existe.jpg', width: 120, height: 120),
    ));

    expect(find.text('Imagem não encontrada'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('arquivo existente vira um Image.file', (tester) async {
    final dir = Directory.systemTemp.createTempSync('media_image_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'img.jpg'))..writeAsBytesSync([0]);

    await tester.pumpWidget(host(MediaImage(path: file.path, width: 120)));

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('CardSideView mostra o texto e a imagem', (tester) async {
    await tester.pumpWidget(host(
      const CardSideView(text: 'to give up', imagePath: '/nao/existe.jpg'),
    ));

    expect(find.text('to give up'), findsOneWidget);
    expect(find.text('Imagem não encontrada'), findsOneWidget);
  });
}
```

Em `test/ui/card_editor/card_editor_screen_test.dart`, acrescente o import `import 'package:my_flashcards/domain/models/image_origin.dart';` e, ao fim do `main()`:
```dart
  testWidgets('Câmera põe a imagem no lado e troca os botões pelo ✕',
      (tester) async {
    media.nextPick = 'img_1.jpg';
    await openEditor(tester);

    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();

    expect(media.picks, [ImageOrigin.camera]);
    expect(find.byTooltip('Remover imagem'), findsOneWidget);
    expect(find.text('Câmera'), findsOneWidget);
  });

  testWidgets('frente só com imagem e verso com texto já podem ser salvos',
      (tester) async {
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
```

Em `test/ui/review/review_view_model_test.dart`:

1. Acrescente o import `import '../../fakes/fake_media_repository.dart';`.
2. Passe `mediaRepository: FakeMediaRepository()` em **todas** as criações de `ReviewViewModel`: a do `setUp` e a do teste `'deck vazio termina na hora com zero cards'`.
3. Acrescente ao fim do `main()`:
```dart
  test('imagePathOf aponta para a pasta media', () {
    expect(viewModel.imagePathOf(const CardSide(image: 'img_1.jpg')),
        '/media/img_1.jpg');
    expect(viewModel.imagePathOf(const CardSide(text: 'sem imagem')), isNull);
  });
```

Em `test/ui/review/review_screen_test.dart`:

1. Acrescente o import `import '../../fakes/fake_media_repository.dart';`.
2. Em `pumpScreen`, passe `mediaRepository: FakeMediaRepository()` para o `ReviewViewModel`.
3. Acrescente ao fim do `main()`:
```dart
  testWidgets('mostra a imagem do lado, ou o aviso se o arquivo sumiu',
      (tester) async {
    await pumpScreen(tester, [
      Flashcard(
        id: 1,
        deckId: 1,
        front: const CardSide(text: 'apple', image: 'img_1.jpg'),
        back: const CardSide(text: 'maçã'),
        createdAt: DateTime(2026),
      ),
    ]);

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('Imagem não encontrada'), findsOneWidget);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui
```

Esperado: FALHA de compilação (`MediaImage`, `imagePath:` e `mediaRepository:` ainda não existem nas telas).

- [ ] **Passo 3: implementar o `MediaImage`**

`lib/ui/core/widgets/media_image.dart`:
```dart
import 'dart:io';

import 'package:flutter/material.dart';

/// An image file from the app's storage, decoded at the size it is shown.
/// Shows a grey box saying the image wasn't found when the file is missing
/// or can't be read.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return _MissingImage(width: width, height: height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final shownWidth = width ?? (maxWidth.isFinite ? maxWidth : null);
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: shownWidth == null
              ? null
              : (shownWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) =>
              _MissingImage(width: width, height: height),
        );
      },
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height ?? 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Imagem não encontrada',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
```

- [ ] **Passo 4: imagem no `CardSideView`**

`lib/ui/core/widgets/card_side_view.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'media_image.dart';

/// The content of one side of a card, centred, scrolling when it is long.
class CardSideView extends StatelessWidget {
  const CardSideView({super.key, this.text, this.imagePath});

  final String? text;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final imagePath = this.imagePath;
    final parts = <Widget>[
      if (text != null)
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      if (imagePath != null)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: MediaImage(path: imagePath),
        ),
    ];
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              parts[i],
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Passo 5: imagem no `SideEditor`**

> **Ajuste da etapa 2 (2026-10-15):** o `SideEditor` tem o parâmetro opcional `autofocus` (padrão `false`), repassado ao `TextField` do texto. Ao substituir o arquivo, mantenha esse parâmetro.

`lib/ui/card_editor/widgets/side_editor.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import '../../core/widgets/media_image.dart';

class SideEditor extends StatelessWidget {
  const SideEditor({
    super.key,
    required this.label,
    required this.controller,
    required this.isEmpty,
    required this.onTextChanged,
    required this.imagePath,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onRemoveImage,
  });

  final String label;
  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onTextChanged;
  final String? imagePath;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = this.imagePath;
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
        const SizedBox(height: 12),
        if (imagePath == null)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Câmera'),
              ),
              OutlinedButton.icon(
                onPressed: onPickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaImage(
                  path: imagePath,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              IconButton(
                onPressed: onRemoveImage,
                tooltip: 'Remover imagem',
                icon: const Icon(Icons.close),
              ),
            ],
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

- [ ] **Passo 6: ligar a imagem na tela do editor**

> **Ajuste da etapa 2 (2026-10-15):** a tela já desativa a 🗑 (`onPressed: _viewModel.isSaving ? null : _delete`) e o voltar (`canPop: !_viewModel.hasChanges && !_viewModel.isSaving`, e o diálogo de descarte só aparece com `!didPop && !_viewModel.isSaving`) enquanto salva, e passa `autofocus: side == Side.front && _viewModel.isNew` ao `SideEditor`. Mantenha isso ao mexer na tela.

Em `lib/ui/card_editor/widgets/card_editor_screen.dart`:

1. Acrescente o import `import '../../../domain/models/image_origin.dart';`.

2. Acrescente este método a `_CardEditorScreenState`:
```dart
  Future<void> _pickImage(Side side, ImageOrigin origin) async {
    if (!await _viewModel.pickImage(side, origin)) _showActionError();
  }
```

3. Troque o método `_sideEditor` por:
```dart
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
      imagePath: _viewModel.imagePath(side),
      onTakePhoto: () => _pickImage(side, ImageOrigin.camera),
      onPickFromGallery: () => _pickImage(side, ImageOrigin.gallery),
      onRemoveImage: () => _viewModel.removeImage(side),
    );
  }
```

- [ ] **Passo 7: imagem na revisão**

Em `lib/ui/review/view_models/review_view_model.dart`:

1. Acrescente os imports:
```dart
import '../../../data/repositories/media_repository.dart';
import '../../../domain/models/card_side.dart';
```

2. Troque o construtor e os campos `final` por:
```dart
  ReviewViewModel({
    required this.deckId,
    required CardRepository cardRepository,
    required MediaRepository mediaRepository,
    Random? random,
  })  : _cardRepository = cardRepository,
        _mediaRepository = mediaRepository,
        _random = random ?? Random();

  static const loadErrorMessage = 'Não foi possível carregar os cards.';
  static const countErrorMessage = 'Não foi possível salvar a revisão.';

  final int deckId;
  final CardRepository _cardRepository;
  final MediaRepository _mediaRepository;
  final Random _random;
```

3. Acrescente o método:
```dart
  String? imagePathOf(CardSide side) {
    final image = side.image;
    return image == null ? null : _mediaRepository.mediaPath(image);
  }
```

Em `lib/ui/review/widgets/review_screen.dart`, troque os dois `CardSideView` por:
```dart
                child: CardSideView(
                  text: card.front.text,
                  imagePath: _viewModel.imagePathOf(card.front),
                ),
```
e
```dart
                child: CardSideView(
                  text: card.back.text,
                  imagePath: _viewModel.imagePathOf(card.back),
                ),
```

Em `lib/routes.dart`, no método `review`, acrescente ao `ReviewViewModel`:
```dart
      mediaRepository: _dependencies.media,
```

- [ ] **Passo 8: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 9: commit**

```bash
git add lib/ui lib/routes.dart test/ui
git commit -m "feat: mostra e edita imagens no editor e na revisão"
```

---

### Tarefa 6: conferir no celular e fechar a etapa

> **Ajustes feitos na execução (2026-10-16):** depois da revisão final, a etapa ganhou o seletor de fotos do Android ligado no `AppDependencies.create()`, a limpeza das sobras do `image_picker` no cache ao abrir o app, e as proteções do `save()` (foto dos lados antes de mover os arquivos; Câmera, Galeria e ✕ desativados enquanto salva). Os três itens novos do checklist abaixo conferem isso no celular.

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

- [ ] No editor, **Câmera** abre a câmera do sistema **sem pedir permissão**. A foto tirada aparece como miniatura
- [ ] **Galeria** abre o seletor de fotos do Android **sem pedir permissão**
- [ ] O seletor que abre é o **seletor de fotos do Android** (grade de fotos e álbuns), e não o gerenciador de arquivos
- [ ] Uma foto tirada **em pé** (retrato) aparece em pé no editor e na revisão
- [ ] Cancelar a câmera ou a galeria volta ao editor sem mensagem de erro
- [ ] **✕** remove a imagem, e os botões Câmera e Galeria voltam
- [ ] Um card com a frente só com imagem e o verso com texto pode ser salvo. Na lista, ele aparece como *"(só imagem)"* com o ícone de imagem
- [ ] Na revisão, a imagem aparece inteira, sem cortes, abaixo do texto
- [ ] As imagens têm entre 100 e 300 KB:
  ```bash
  adb shell run-as com.sorayaferreira.myflashcards ls -l app_flutter/media
  ```
- [ ] Trocar a imagem de um card e salvar apaga o arquivo antigo (confira com o comando acima)
- [ ] Excluir o card, ou o deck, apaga os arquivos dele
- [ ] Escolher uma imagem e **descartar** o editor não deixa arquivo sobrando:
  ```bash
  adb shell run-as com.sorayaferreira.myflashcards ls -l cache/editor_tmp
  ```
- [ ] Depois de escolher algumas fotos da galeria, fechar e abrir o app de novo não deixa sobras no cache (nenhuma pasta com nome longo de letras e números):
  ```bash
  adb shell run-as com.sorayaferreira.myflashcards ls cache
  ```
- [ ] Apagar um arquivo à mão (`adb shell run-as com.sorayaferreira.myflashcards rm app_flutter/media/<nome>`) faz o card mostrar *"Imagem não encontrada"*, e o app não trava

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-4-imagens -m "Etapa 4: imagens" && git branch -d etapa-4-imagens
```
