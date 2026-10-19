# Etapa 5: áudio. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** cada lado do card pode ter um áudio gravado no app, de até 60 s. O áudio pode ser ouvido no editor e na revisão, e só toca quando a usuária aperta ▶.

**Arquitetura:**
- **Services:** `AudioRecorderService` (embrulha o `record`) e `AudioPlayerService` (embrulha o `audioplayers`, com um único player para o app inteiro).
- **`MediaRepository`:** ganha os métodos de áudio. Os áudios novos seguem o mesmo ciclo de rascunho das imagens.
- **`CardEditorViewModel`:** controla a gravação, com um cronômetro que para sozinho em 60 s, e a reprodução.
- **`ReviewViewModel`:** toca e para o áudio.
- **Na tela:** as Views desenham o ▶ e o campo de gravação. O `AppLifecycleListener` do editor para a gravação quando o app sai da tela.

**Tecnologias:** `record` 7.1, `audioplayers` 6.8 e `fake_async` (só nos testes).

**Spec:** [docs/design.md](../design.md), parte 2 ("3. Editor de card" e "4. Revisão") e parte 3 ("Áudio" e "Permissões"). Requisitos RF-06, RF-10 e RF-18.

**Branch:** `etapa-5-audio`

## Restrições globais

- **Gravação:**
  - formato AAC-LC (`AudioEncoder.aacLc`), 32 kbps, mono, 22.050 Hz, arquivo `.m4a`;
  - nome `aud_<epoch-ms>_<4 caracteres>.m4a`;
  - limite de **60 s**: ao chegar nele, a gravação para sozinha e mantém o que foi gravado.
- **Microfone:** a permissão `RECORD_AUDIO` já vem declarada pelo `record_android` e é pedida no primeiro toque em **Gravar**. Se for negada, aparece *"Sem acesso ao microfone. Ative em Configurações › Apps › My Flashcards › Permissões."*
- **Uma gravação por vez:** enquanto um lado grava, o Gravar do outro fica desativado e o SALVAR também.
- **App fora da tela:** a gravação para e o que foi gravado fica.
- **Reprodução:**
  - só ao apertar ▶;
  - um único player para o app inteiro;
  - o áudio para ao virar o card, trocar de card, sair da tela ou começar a gravar.
- **Arquivo de áudio sumido:** o ▶ aparece desativado, com *"Áudio não encontrado"*.
- **Camadas:** ViewModels nunca chamam services.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

## Pontos de atenção na revisão

1. **Microfone negado.** Aparece a mensagem, nada é gravado e o resto do editor continua funcionando. Testado nas tarefas 3 e 4.
2. **Gravação que chega a 60 s.** Para sozinha e o áudio fica no card. Testado na tarefa 3, com `fake_async`.
3. **App sai da tela durante a gravação.** A gravação para e o áudio fica. Testado na tarefa 4.
4. **Sair do editor gravando ou tocando.** A gravação para, o rascunho é apagado e o som para. Testado na tarefa 3.
5. **Arquivo de áudio apagado por fora.** O ▶ aparece desativado, com *"Áudio não encontrado"*, sem travar o app. Testado na tarefa 4.

---

### Tarefa 1: services de gravação e reprodução, e o `MediaRepository` com áudio

**Arquivos:**
- Criar: `lib/data/services/audio_recorder_service.dart`
- Criar: `lib/data/services/audio_player_service.dart`
- Substituir: `lib/data/repositories/media_repository.dart`
- Modificar: `lib/app_dependencies.dart`
- Substituir: `test/fakes/fake_media_repository.dart`
- Testar: modificar `test/data/repositories/media_repository_test.dart` e `test/helpers/temp_media.dart`

**Interfaces:**
- Consome: `MediaFileService.newFileName` e `MediaFileService.draftFile`.
- Produz:
  - `class AudioRecorderService`, com:
    - o construtor `AudioRecorderService({AudioRecorder? recorder})`;
    - o método `Future<bool> requestPermission()`, que mostra o pedido do sistema na primeira vez;
    - os métodos `Future<void> start(String path)` e `Future<void> stop()`;
    - a constante `static const config`.
  - `class AudioPlayerService`, com:
    - o construtor `AudioPlayerService({AudioPlayer? player})`;
    - o getter `ValueListenable<String?> playingPath`;
    - os métodos `Future<void> play(String path)`, `Future<void> stop()` e `Future<Duration?> durationOf(String path)`.
  - `MediaRepository`:
    - o construtor passa a ser `MediaRepository({required MediaFileService files, required ImagePickerService imagePicker, required AudioRecorderService recorder, required AudioPlayerService player})`;
    - os métodos novos:

      | Método | O que faz |
      |---|---|
      | `Future<Result<bool>> requestMicrophone()` | Pede o microfone. Devolve `Ok(false)` se a usuária negou |
      | `Future<Result<String>> startRecording()` | Começa a gravar num rascunho novo e devolve o nome dele |
      | `Future<Result<void>> stopRecording()` | Para a gravação |
      | `Future<Result<void>> play(String path)` | Toca o arquivo, parando o que estiver tocando |
      | `Future<void> stopPlayback()` | Para o som |
      | `ValueListenable<String?> playingPath` | O caminho que está tocando, ou `null` |
      | `Future<Duration?> durationOf(String path)` | A duração do arquivo, ou `null` se não der para ler |

  - Nos testes, em `FakeMediaRepository`:
    - o campo `String root = ''`: os caminhos ficam `'$root/drafts/<nome>'` e `'$root/media/<nome>'`;
    - os campos `bool microphoneAllowed` e `Exception? recordError`;
    - as listas `recordings` e `played`, e o contador `stopRecordingCalls`;
    - o campo `Duration? duration` e o método `void finishPlayback()`.
  - Em `test/helpers/temp_media.dart`: `String createFakeMediaRoot(List<String> files)`, que cria arquivos vazios numa pasta temporária e devolve a pasta.

- [ ] **Passo 1: criar o branch e adicionar os pacotes**

```bash
git switch main && git switch -c etapa-5-audio
flutter pub add record audioplayers
flutter pub add dev:fake_async
```

- [ ] **Passo 2: escrever os testes**

Em `test/helpers/temp_media.dart`, acrescente ao fim do arquivo:
```dart
/// Creates empty files at [files] (paths relative to a temporary folder)
/// and returns that folder. It is deleted after the test.
String createFakeMediaRoot(List<String> files) {
  final root = Directory.systemTemp.createTempSync('fake_media_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final file in files) {
    File(p.join(root.path, file)).createSync(recursive: true);
  }
  return root.path;
}
```

Em `test/data/repositories/media_repository_test.dart`:

1. Acrescente os imports:
```dart
import 'package:flutter/foundation.dart';
import 'package:my_flashcards/data/services/audio_player_service.dart';
import 'package:my_flashcards/data/services/audio_recorder_service.dart';
```

2. Acrescente estas duas classes falsas, logo abaixo de `_FakeImagePicker`:
```dart
class _FakeRecorder implements AudioRecorderService {
  bool allowed = true;
  final started = <String>[];
  var stops = 0;

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    started.add(path);
    await File(path).writeAsString('áudio');
  }

  @override
  Future<void> stop() async => stops++;
}

class _FakePlayer implements AudioPlayerService {
  final _playing = ValueNotifier<String?>(null);

  @override
  ValueListenable<String?> get playingPath => _playing;

  @override
  Future<void> play(String path) async => _playing.value = path;

  @override
  Future<void> stop() async => _playing.value = null;

  @override
  Future<Duration?> durationOf(String path) async =>
      const Duration(seconds: 4);
}
```

3. Acrescente `late _FakeRecorder recorder;` e `late _FakePlayer player;`. No `setUp`, troque a criação do repositório por:
```dart
    recorder = _FakeRecorder();
    player = _FakePlayer();
    repository = MediaRepository(
      files: files,
      imagePicker: picker,
      recorder: recorder,
      player: player,
    );
```

4. Acrescente ao fim do `main()`:
```dart
  test('requestMicrophone devolve se a usuária deixou', () async {
    expect(okValue(await repository.requestMicrophone()), isTrue);

    recorder.allowed = false;
    expect(okValue(await repository.requestMicrophone()), isFalse);
  });

  test('startRecording grava num rascunho .m4a novo', () async {
    final name = okValue(await repository.startRecording());

    expect(name, matches(RegExp(r'^aud_\d+_[a-z0-9]{4}\.m4a$')));
    expect(recorder.started, [repository.draftPath(name)]);
    expect(await File(repository.draftPath(name)).exists(), isTrue);

    okValue(await repository.stopRecording());
    expect(recorder.stops, 1);
  });

  test('play e stopPlayback mudam o que está tocando', () async {
    okValue(await repository.play('/algum/audio.m4a'));
    expect(repository.playingPath.value, '/algum/audio.m4a');

    await repository.stopPlayback();
    expect(repository.playingPath.value, isNull);
  });

  test('durationOf devolve a duração do arquivo', () async {
    expect(
      await repository.durationOf('/algum/audio.m4a'),
      const Duration(seconds: 4),
    );
  });
```

`test/fakes/fake_media_repository.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/foundation.dart';
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';

/// [MediaRepository] that records calls. Paths are '$root/drafts/<name>'
/// and '$root/media/<name>'; point [root] at a real folder when a test
/// needs the files to exist.
class FakeMediaRepository implements MediaRepository {
  String root = '';

  /// What the next [pickImage] returns: a file name, null for "cancelled",
  /// or an [Exception] for a failure.
  Object? nextPick;
  Exception? commitError;
  bool microphoneAllowed = true;
  Exception? recordError;
  Duration? duration = const Duration(seconds: 4);

  final picks = <ImageOrigin>[];
  final committed = <String>[];
  final reverted = <String>[];
  final discarded = <String>[];
  final recordings = <String>[];
  final played = <String>[];
  var clearedDrafts = 0;
  var stopRecordingCalls = 0;

  final _playingPath = ValueNotifier<String?>(null);

  /// Simulates the audio reaching its end.
  void finishPlayback() => _playingPath.value = null;

  @override
  Future<Result<String?>> pickImage(ImageOrigin origin) async {
    picks.add(origin);
    final next = nextPick;
    if (next is Exception) return Result.error(next);
    return Result.ok(next as String?);
  }

  @override
  String draftPath(String name) => '$root/drafts/$name';

  @override
  String mediaPath(String name) => '$root/media/$name';

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

  @override
  Future<Result<bool>> requestMicrophone() async =>
      Result.ok(microphoneAllowed);

  @override
  Future<Result<String>> startRecording() async {
    final error = recordError;
    if (error != null) return Result.error(error);
    final name = 'aud_${recordings.length + 1}.m4a';
    recordings.add(name);
    return Result.ok(name);
  }

  @override
  Future<Result<void>> stopRecording() async {
    stopRecordingCalls++;
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> play(String path) async {
    played.add(path);
    _playingPath.value = path;
    return const Result.ok(null);
  }

  @override
  Future<void> stopPlayback() async => _playingPath.value = null;

  @override
  ValueListenable<String?> get playingPath => _playingPath;

  @override
  Future<Duration?> durationOf(String path) async => duration;
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/data/repositories/media_repository_test.dart
```

Esperado: FALHA de compilação (os services de áudio não existem).

- [ ] **Passo 4: implementar os services**

`lib/data/services/audio_recorder_service.dart`:
```dart
import 'package:record/record.dart';

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// Compact AAC, good enough for voice: about 40 KB every 10 seconds.
  static const config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 32000,
    sampleRate: 22050,
    numChannels: 1,
  );

  final AudioRecorder _recorder;

  /// Shows the system prompt the first time. Returns whether the app may
  /// record.
  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<void> start(String path) => _recorder.start(config, path: path);

  Future<void> stop() async {
    await _recorder.stop();
  }
}
```

`lib/data/services/audio_player_service.dart`:
```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's only audio player, so two sounds never play at once.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _player.onPlayerComplete.listen((_) => _playingPath.value = null);
  }

  final AudioPlayer _player;
  final _playingPath = ValueNotifier<String?>(null);

  /// The file being played, or null when nothing is playing.
  ValueListenable<String?> get playingPath => _playingPath;

  Future<void> play(String path) async {
    await _player.stop();
    _playingPath.value = path;
    try {
      await _player.play(DeviceFileSource(path));
    } catch (_) {
      _playingPath.value = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _playingPath.value = null;
  }

  /// Reads the length with a separate player, so it doesn't interrupt what
  /// is playing.
  Future<Duration?> durationOf(String path) async {
    final probe = AudioPlayer();
    try {
      await probe.setSourceDeviceFile(path);
      return await probe.getDuration();
    } finally {
      await probe.dispose();
    }
  }
}
```

- [ ] **Passo 5: implementar o `MediaRepository` com áudio**

`lib/data/repositories/media_repository.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/foundation.dart';

import '../../domain/models/image_origin.dart';
import '../../utils/result.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/image_picker_service.dart';
import '../services/media_file_service.dart';

class MediaRepository {
  MediaRepository({
    required MediaFileService files,
    required ImagePickerService imagePicker,
    required AudioRecorderService recorder,
    required AudioPlayerService player,
  })  : _files = files,
        _imagePicker = imagePicker,
        _recorder = recorder,
        _player = player;

  final MediaFileService _files;
  final ImagePickerService _imagePicker;
  final AudioRecorderService _recorder;
  final AudioPlayerService _player;

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

  /// Ok(false) when the user denies the microphone.
  Future<Result<bool>> requestMicrophone() => guard(_recorder.requestPermission);

  /// Starts recording into a new draft file and returns its name.
  Future<Result<String>> startRecording() => guard(() async {
        final name = _files.newFileName('aud', 'm4a');
        await _recorder.start(_files.draftFile(name).path);
        return name;
      });

  Future<Result<void>> stopRecording() => guard(_recorder.stop);

  /// Plays the file at [path], stopping whatever was playing before.
  Future<Result<void>> play(String path) => guard(() => _player.play(path));

  Future<void> stopPlayback() async {
    await guard(_player.stop);
  }

  ValueListenable<String?> get playingPath => _player.playingPath;

  /// The length of an audio file, or null when it can't be read.
  Future<Duration?> durationOf(String path) async =>
      switch (await guard(() => _player.durationOf(path))) {
        Ok(:final value) => value,
        Error() => null,
      };
}
```

- [ ] **Passo 6: passar os services de áudio no app**

Em `lib/app_dependencies.dart`, acrescente os imports:
```dart
import 'data/services/audio_player_service.dart';
import 'data/services/audio_recorder_service.dart';
```
E troque a criação do `MediaRepository` por:
```dart
      media: MediaRepository(
        files: mediaFiles,
        imagePicker: ImagePickerService(),
        recorder: AudioRecorderService(),
        player: AudioPlayerService(),
      ),
```

- [ ] **Passo 7: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 8: commit**

```bash
git add pubspec.yaml pubspec.lock lib/data lib/app_dependencies.dart test/fakes/fake_media_repository.dart test/helpers/temp_media.dart test/data/repositories/media_repository_test.dart
git commit -m "feat: acrescenta gravação e reprodução de áudio ao MediaRepository"
```

---

### Tarefa 2: áudio no `SideDraft`

**Arquivos:**
- Substituir: `lib/ui/card_editor/view_models/side_draft.dart`
- Testar: criar `test/ui/card_editor/side_draft_test.dart`

**Interfaces:**
- Produz: em `SideDraft`, o campo novo `DraftFile? audio` e o método `SideDraft withAudio(DraftFile? audio)`. `isEmpty`, `newFileNames`, `fromCardSide` e `toCardSide` passam a considerar o áudio.

- [ ] **Passo 1: escrever o teste**

`test/ui/card_editor/side_draft_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/ui/card_editor/view_models/side_draft.dart';

void main() {
  test('um lado só com áudio não está vazio', () {
    const draft = SideDraft(audio: DraftFile('aud_1.m4a', isNew: true));

    expect(draft.isEmpty, isFalse);
  });

  test('newFileNames lista imagem e áudio novos, nunca os já salvos', () {
    const draft = SideDraft(
      image: DraftFile('img_salva.jpg', isNew: false),
      audio: DraftFile('aud_novo.m4a', isNew: true),
    );

    expect(draft.newFileNames, ['aud_novo.m4a']);
  });

  test('vai e volta de CardSide mantendo os três conteúdos', () {
    const side = CardSide(text: 'oi', image: 'img_1.jpg', audio: 'aud_1.m4a');

    final draft = SideDraft.fromCardSide(side);

    expect(draft.audio, const DraftFile('aud_1.m4a', isNew: false));
    expect(draft.toCardSide(), side);
  });

  test('withText e withImage não perdem o áudio', () {
    const draft = SideDraft(audio: DraftFile('aud_1.m4a', isNew: true));

    expect(draft.withText('x').audio, draft.audio);
    expect(draft.withImage(null).audio, draft.audio);
    expect(draft.withAudio(null).isEmpty, isTrue);
  });
}
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/card_editor/side_draft_test.dart
```

Esperado: FALHA de compilação (`audio` não existe).

- [ ] **Passo 3: implementar**

> **Ajuste da etapa 4 (2026-10-16):** o `SideDraft` atual é o da etapa 4. Ao substituir o arquivo, mantenha `DraftFile`, `newFileNames` e o restante do contrato de imagem.

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

  @override
  String toString() => 'DraftFile($name, isNew: $isNew)';
}

/// What the editor holds for one side of the card while it is being edited.
class SideDraft {
  const SideDraft({this.text = '', this.image, this.audio});

  factory SideDraft.fromCardSide(CardSide side) => SideDraft(
        text: side.text ?? '',
        image: side.image == null ? null : DraftFile(side.image!, isNew: false),
        audio: side.audio == null ? null : DraftFile(side.audio!, isNew: false),
      );

  final String text;
  final DraftFile? image;
  final DraftFile? audio;

  bool get isEmpty => text.trim().isEmpty && image == null && audio == null;

  /// Files created during this editing session, still in the draft folder.
  List<String> get newFileNames => [
        if (image case DraftFile(:final name, isNew: true)) name,
        if (audio case DraftFile(:final name, isNew: true)) name,
      ];

  SideDraft withText(String text) =>
      SideDraft(text: text, image: image, audio: audio);

  SideDraft withImage(DraftFile? image) =>
      SideDraft(text: text, image: image, audio: audio);

  SideDraft withAudio(DraftFile? audio) =>
      SideDraft(text: text, image: image, audio: audio);

  CardSide toCardSide() => CardSide(
        text: text.trim().isEmpty ? null : text.trim(),
        image: image?.name,
        audio: audio?.name,
      );

  @override
  bool operator ==(Object other) =>
      other is SideDraft &&
      other.text == text &&
      other.image == image &&
      other.audio == audio;

  @override
  int get hashCode => Object.hash(text, image, audio);
}
```

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/ui/card_editor
```

Esperado: `All tests passed!`

- [ ] **Passo 5: commit**

```bash
git add lib/ui/card_editor/view_models/side_draft.dart test/ui/card_editor/side_draft_test.dart
git commit -m "feat: rascunho do lado guarda áudio"
```

---

### Tarefa 3: gravar e tocar no `CardEditorViewModel`

**Arquivos:**
- Substituir: `lib/ui/card_editor/view_models/card_editor_view_model.dart`
- Testar: modificar `test/ui/card_editor/card_editor_view_model_test.dart`

**Interfaces:**
- Consome: `MediaRepository.requestMicrophone`, `startRecording`, `stopRecording`, `play`, `stopPlayback`, `playingPath` e `durationOf` (tarefa 1), e `SideDraft.withAudio` (tarefa 2).
- Produz: em `CardEditorViewModel`:
  - as constantes `maxRecording`, `microphoneDeniedMessage`, `recordErrorMessage` e `playErrorMessage`;
  - os getters `Side? recordingSide`, `bool isRecording` e `Duration recordingElapsed`;
  - os métodos novos:
    - `String? audioPath(Side side)`, `Duration? audioDuration(Side side)` e `bool isPlaying(Side side)`;
    - `Future<bool> startRecording(Side side)` e `Future<void> stopRecording()`. Chamar `stopRecording` sem gravação em curso não faz nada;
    - `Future<void> removeAudio(Side side)` e `Future<bool> togglePlay(Side side)`.
  - Mudanças de comportamento:
    - `canSave` fica `false` enquanto grava;
    - `discard()` também para a gravação e o som;
    - `dispose()` para a gravação e o som.

- [ ] **Passo 1: escrever os testes**

Em `test/ui/card_editor/card_editor_view_model_test.dart`, acrescente o import `import 'package:fake_async/fake_async.dart';` e, ao fim do `main()`:

```dart
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
        expect(viewModel.draft(Side.back).audio,
            const DraftFile('aud_1.m4a', isNew: true));
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
        expect(viewModel.audioDuration(Side.front),
            CardEditorViewModel.maxRecording);
      });
    });

    test('microfone negado mostra a mensagem e não grava', () async {
      media.microphoneAllowed = false;
      final viewModel = newCard();

      expect(await viewModel.startRecording(Side.front), isFalse);

      expect(viewModel.isRecording, isFalse);
      expect(media.recordings, isEmpty);
      expect(viewModel.actionError,
          CardEditorViewModel.microphoneDeniedMessage);
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
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui/card_editor/card_editor_view_model_test.dart
```

Esperado: FALHA de compilação (`startRecording` não existe).

- [ ] **Passo 3: implementar**

> **Ajustes das etapas 2 a 4 que este arquivo precisa manter (2026-10-16):** `extends ChangeNotifier with DisposeSafeNotifier`; parâmetros nomeados privados (`required this._cardRepository`, `required this._mediaRepository`); no `save()`, a foto dos lados (`frontDraft`/`backDraft`, `newFiles`, `front`/`back`) tirada **antes** do primeiro `await`; o conjunto `_committed`, que faz o `imagePath` apontar para `media/` durante a gravação no banco; o `_isPicking` contra toque duplo; `pickImage` e `removeImage` sem efeito enquanto salva, com o descarte do rascunho que chegar tarde. Aplique a mesma regra ao áudio: gravar, parar e remover áudio não mexem nos lados enquanto salva, e um áudio que terminar de gravar durante o salvamento é descartado. Os testes desses comportamentos precisam continuar passando.

`lib/ui/card_editor/view_models/card_editor_view_model.dart` (substitui o arquivo inteiro):
```dart
import 'dart:async';

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
        _mediaRepository = mediaRepository {
    _mediaRepository.playingPath.addListener(notifyListeners);
  }

  static const maxRecording = Duration(seconds: 60);

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';
  static const imageErrorMessage = 'Não foi possível carregar a imagem.';
  static const microphoneDeniedMessage =
      'Sem acesso ao microfone. Ative em Configurações › Apps › '
      'My Flashcards › Permissões.';
  static const recordErrorMessage = 'Não foi possível gravar o áudio.';
  static const playErrorMessage = 'Não foi possível tocar o áudio.';

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

  Side? _recordingSide;
  String? _recordingName;
  Duration _recordingElapsed = Duration.zero;
  Timer? _ticker;
  final Map<String, Duration> _durations = {};

  bool get isNew => cardId == null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  Side? get recordingSide => _recordingSide;
  bool get isRecording => _recordingSide != null;
  Duration get recordingElapsed => _recordingElapsed;

  bool get hasChanges => _front != _initialFront || _back != _initialBack;

  bool get canSave =>
      !_isLoading &&
      !_isSaving &&
      !isRecording &&
      _loadError == null &&
      !_front.isEmpty &&
      !_back.isEmpty;

  SideDraft draft(Side side) => switch (side) {
        Side.front => _front,
        Side.back => _back,
      };

  /// The full path of the side's image, wherever the file currently lives.
  String? imagePath(Side side) => _pathOf(draft(side).image);

  /// The full path of the side's audio, wherever the file currently lives.
  String? audioPath(Side side) => _pathOf(draft(side).audio);

  Duration? audioDuration(Side side) {
    final audio = draft(side).audio;
    return audio == null ? null : _durations[audio.name];
  }

  bool isPlaying(Side side) {
    final path = audioPath(side);
    return path != null && _mediaRepository.playingPath.value == path;
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
        for (final audio in [card.front.audio, card.back.audio]) {
          if (audio != null) _loadDuration(audio);
        }
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

  Future<bool> startRecording(Side side) async {
    _actionError = null;
    if (isRecording) return false;

    switch (await _mediaRepository.requestMicrophone()) {
      case Ok(value: true):
        break;
      case Ok():
        return _fail(microphoneDeniedMessage);
      case Error():
        return _fail(recordErrorMessage);
    }

    await _mediaRepository.stopPlayback();
    switch (await _mediaRepository.startRecording()) {
      case Ok(value: final name):
        _recordingSide = side;
        _recordingName = name;
        _recordingElapsed = Duration.zero;
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        notifyListeners();
        return true;
      case Error():
        return _fail(recordErrorMessage);
    }
  }

  /// Stops the recording and keeps what was recorded. Does nothing when no
  /// recording is going on.
  Future<void> stopRecording() async {
    final side = _recordingSide;
    final name = _recordingName;
    if (side == null || name == null) return;
    _ticker?.cancel();
    _ticker = null;
    _recordingSide = null;
    _recordingName = null;

    if (await _mediaRepository.stopRecording() is Error) {
      await _mediaRepository.discardDrafts([name]);
      _fail(recordErrorMessage);
      return;
    }
    await _dropIfNew(draft(side).audio);
    _durations[name] = _recordingElapsed;
    _setDraft(side, draft(side).withAudio(DraftFile(name, isNew: true)));
  }

  Future<void> removeAudio(Side side) async {
    if (isPlaying(side)) await _mediaRepository.stopPlayback();
    await _dropIfNew(draft(side).audio);
    _setDraft(side, draft(side).withAudio(null));
  }

  Future<bool> togglePlay(Side side) async {
    _actionError = null;
    if (isPlaying(side)) {
      await _mediaRepository.stopPlayback();
      return true;
    }
    final path = audioPath(side);
    if (path == null) return false;
    if (await _mediaRepository.play(path) is Error) {
      return _fail(playErrorMessage);
    }
    return true;
  }

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();
    await _mediaRepository.stopPlayback();

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
      return _fail(deleteErrorMessage);
    }
    await discard();
    return true;
  }

  /// Stops any recording or sound and throws away the files created while
  /// editing. Call it when leaving without saving.
  Future<void> discard() async {
    await stopRecording();
    await _mediaRepository.stopPlayback();
    await _mediaRepository
        .discardDrafts([..._front.newFileNames, ..._back.newFileNames]);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (isRecording) _mediaRepository.stopRecording();
    _mediaRepository.playingPath.removeListener(notifyListeners);
    _mediaRepository.stopPlayback();
    super.dispose();
  }

  void _tick() {
    _recordingElapsed += const Duration(seconds: 1);
    if (_recordingElapsed >= maxRecording) {
      stopRecording();
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadDuration(String name) async {
    final duration =
        await _mediaRepository.durationOf(_mediaRepository.mediaPath(name));
    if (duration == null) return;
    _durations[name] = duration;
    notifyListeners();
  }

  String? _pathOf(DraftFile? file) {
    if (file == null) return null;
    return file.isNew
        ? _mediaRepository.draftPath(file.name)
        : _mediaRepository.mediaPath(file.name);
  }

  bool _fail(String message) {
    _actionError = message;
    notifyListeners();
    return false;
  }

  bool _saveFailed() {
    _isSaving = false;
    return _fail(saveErrorMessage);
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

- [ ] **Passo 4: rodar e ver passar**

```bash
flutter test test/ui/card_editor/card_editor_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 5: rodar todos os testes**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/card_editor/view_models/card_editor_view_model.dart test/ui/card_editor/card_editor_view_model_test.dart
git commit -m "feat: editor grava, limita a 60 s e toca áudio"
```

---

### Tarefa 4: áudio nas telas (editor e revisão)

**Arquivos:**
- Criar: `lib/ui/core/widgets/audio_play_button.dart`
- Criar: `lib/ui/card_editor/widgets/audio_recorder_field.dart`
- Substituir: `lib/ui/core/widgets/card_side_view.dart`, `lib/ui/card_editor/widgets/side_editor.dart`, `lib/ui/card_editor/widgets/card_editor_screen.dart` e `lib/ui/review/view_models/review_view_model.dart`
- Modificar: `lib/ui/review/widgets/review_screen.dart`
- Testar:
  - criar `test/ui/card_editor/audio_recorder_field_test.dart`;
  - modificar `test/ui/card_editor/card_editor_screen_test.dart`, `test/ui/review/review_view_model_test.dart` e `test/ui/review/review_screen_test.dart`.

**Interfaces:**
- Consome: os métodos de áudio do `CardEditorViewModel` (tarefa 3) e os do `MediaRepository` (tarefa 1).
- Produz:
  - `class AudioPlayButton extends StatelessWidget`, com o construtor `const AudioPlayButton({super.key, required String path, required bool isPlaying, required VoidCallback onPressed})`;
  - `String formatDuration(Duration duration)`, que devolve no formato `m:ss`;
  - `class AudioRecorderField extends StatelessWidget`, com o construtor `const AudioRecorderField({super.key, required bool isRecording, required Duration recordingElapsed, required String? audioPath, required Duration? duration, required bool isPlaying, required bool canRecord, required VoidCallback onRecord, required VoidCallback onStop, required VoidCallback onTogglePlay, required VoidCallback onRemove})`;
  - em `SideEditor`, o parâmetro novo `required Widget audioField`;
  - `CardSideView({String? text, String? imagePath, String? audioPath, bool isPlaying = false, VoidCallback? onToggleAudio})`;
  - em `ReviewViewModel`:
    - os métodos `String? audioPathOf(CardSide side)`, `bool isPlaying(CardSide side)`, `Future<bool> toggleAudio(CardSide side)` e `Future<void> stopAudio()`;
    - a constante `audioErrorMessage`;
    - `next()` e `previous()` passam a parar o som.

- [ ] **Passo 1: escrever os testes**

`test/ui/card_editor/audio_recorder_field_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/card_editor/widgets/audio_recorder_field.dart';
import 'package:my_flashcards/ui/core/widgets/audio_play_button.dart';

import '../../helpers/temp_media.dart';

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  Widget field({
    bool isRecording = false,
    Duration elapsed = Duration.zero,
    String? audioPath,
    Duration? duration,
    bool canRecord = true,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: AudioRecorderField(
            isRecording: isRecording,
            recordingElapsed: elapsed,
            audioPath: audioPath,
            duration: duration,
            isPlaying: false,
            canRecord: canRecord,
            onRecord: () => calls.add('gravar'),
            onStop: () => calls.add('parar'),
            onTogglePlay: () => calls.add('tocar'),
            onRemove: () => calls.add('remover'),
          ),
        ),
      );

  test('formatDuration usa m:ss', () {
    expect(formatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatDuration(const Duration(seconds: 60)), '1:00');
  });

  testWidgets('sem áudio mostra Gravar', (tester) async {
    await tester.pumpWidget(field());

    await tester.tap(find.text('Gravar'));

    expect(calls, ['gravar']);
  });

  testWidgets('Gravar fica desativado enquanto o outro lado grava',
      (tester) async {
    await tester.pumpWidget(field(canRecord: false));

    await tester.tap(find.text('Gravar'));

    expect(calls, isEmpty);
  });

  testWidgets('gravando mostra o tempo e Parar', (tester) async {
    await tester.pumpWidget(
      field(isRecording: true, elapsed: const Duration(seconds: 7)),
    );

    expect(find.text('0:07'), findsOneWidget);
    await tester.tap(find.text('Parar'));
    expect(calls, ['parar']);
  });

  testWidgets('com áudio mostra ▶, duração, Regravar e ✕', (tester) async {
    final root = createFakeMediaRoot(['aud_1.m4a']);
    await tester.pumpWidget(field(
      audioPath: '$root/aud_1.m4a',
      duration: const Duration(seconds: 4),
    ));

    expect(find.text('0:04'), findsOneWidget);
    await tester.tap(find.byTooltip('Ouvir'));
    await tester.tap(find.text('Regravar'));
    await tester.tap(find.byTooltip('Remover áudio'));

    expect(calls, ['tocar', 'gravar', 'remover']);
  });

  testWidgets('áudio sumido mostra "Áudio não encontrado" desativado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AudioPlayButton(
          path: '/nao/existe.m4a',
          isPlaying: false,
          onPressed: () => calls.add('tocar'),
        ),
      ),
    ));

    await tester.tap(find.text('Áudio não encontrado'));

    expect(calls, isEmpty);
  });
}
```

Em `test/ui/card_editor/card_editor_screen_test.dart`, acrescente ao fim do `main()`:
```dart
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
      find.text('Sem acesso ao microfone. Ative em Configurações › Apps › '
          'My Flashcards › Permissões.'),
      findsOneWidget,
    );
  });

  testWidgets('a gravação para quando o app sai da tela', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Gravar').first);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Parar'), findsNothing);
    expect(find.text('Regravar'), findsOneWidget);
  });
```

Em `test/ui/review/review_view_model_test.dart`:

1. Troque `late ReviewViewModel viewModel;` por:
```dart
  late ReviewViewModel viewModel;
  late FakeMediaRepository media;
```

2. No `setUp`, crie `media = FakeMediaRepository();` antes do ViewModel e passe `mediaRepository: media` para ele.

3. Acrescente ao fim do `main()`:
```dart
  test('toggleAudio toca e para o áudio do lado', () async {
    const side = CardSide(audio: 'aud_1.m4a');

    await viewModel.toggleAudio(side);
    expect(media.played, ['/media/aud_1.m4a']);
    expect(viewModel.isPlaying(side), isTrue);

    await viewModel.toggleAudio(side);
    expect(viewModel.isPlaying(side), isFalse);
  });

  test('trocar de card para o som', () async {
    await viewModel.start();
    const side = CardSide(audio: 'aud_1.m4a');
    await viewModel.toggleAudio(side);

    viewModel.next();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isPlaying(side), isFalse);
  });
```

Em `test/ui/review/review_screen_test.dart`:

1. Troque `late FakeCardRepository cards;` por:
```dart
  late FakeCardRepository cards;
  late FakeMediaRepository media;
```

2. Acrescente o import `import '../../helpers/temp_media.dart';`.

3. Troque a assinatura de `pumpScreen` por esta, que aceita a pasta das mídias falsas:
```dart
  Future<void> pumpScreen(
    WidgetTester tester,
    List<Flashcard> deck, {
    String mediaRoot = '',
  }) async {
    cards = FakeCardRepository(deck);
    media = FakeMediaRepository()..root = mediaRoot;
```
O resto da função continua igual, mas o `ReviewViewModel` passa a receber `mediaRepository: media`.

4. Acrescente ao fim do `main()`:
```dart
  testWidgets('▶ toca o áudio e virar o card para o som', (tester) async {
    final root = createFakeMediaRoot(['media/aud_1.m4a']);
    await pumpScreen(
      tester,
      [
        Flashcard(
          id: 1,
          deckId: 1,
          front: const CardSide(text: 'apple', audio: 'aud_1.m4a'),
          back: const CardSide(text: 'maçã'),
          createdAt: DateTime(2026),
        ),
      ],
      mediaRoot: root,
    );

    await tester.tap(find.byTooltip('Ouvir'));
    await tester.pumpAndSettle();
    expect(media.played, ['$root/media/aud_1.m4a']);
    expect(find.byTooltip('Parar'), findsOneWidget);

    await flip(tester);

    expect(media.playingPath.value, isNull);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test test/ui
```

Esperado: FALHA de compilação (`AudioRecorderField`, `AudioPlayButton` e `toggleAudio` não existem).

- [ ] **Passo 3: implementar o `AudioPlayButton`**

`lib/ui/core/widgets/audio_play_button.dart`:
```dart
import 'dart:io';

import 'package:flutter/material.dart';

/// ▶ / ■ for an audio file. Shows a disabled "Áudio não encontrado" when the
/// file is missing.
class AudioPlayButton extends StatelessWidget {
  const AudioPlayButton({
    super.key,
    required this.path,
    required this.isPlaying,
    required this.onPressed,
  });

  final String path;
  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!File(path).existsSync()) {
      return TextButton.icon(
        onPressed: null,
        icon: const Icon(Icons.volume_off_outlined),
        label: const Text('Áudio não encontrado'),
      );
    }
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: isPlaying ? 'Parar' : 'Ouvir',
      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
    );
  }
}
```

- [ ] **Passo 4: implementar o `AudioRecorderField`**

`lib/ui/card_editor/widgets/audio_recorder_field.dart`:
```dart
import 'package:flutter/material.dart';

import '../../core/widgets/audio_play_button.dart';

String formatDuration(Duration duration) {
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '${duration.inMinutes}:$seconds';
}

class AudioRecorderField extends StatelessWidget {
  const AudioRecorderField({
    super.key,
    required this.isRecording,
    required this.recordingElapsed,
    required this.audioPath,
    required this.duration,
    required this.isPlaying,
    required this.canRecord,
    required this.onRecord,
    required this.onStop,
    required this.onTogglePlay,
    required this.onRemove,
  });

  final bool isRecording;
  final Duration recordingElapsed;
  final String? audioPath;
  final Duration? duration;
  final bool isPlaying;

  /// False while the other side is recording.
  final bool canRecord;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onTogglePlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return Row(
        children: [
          Icon(Icons.circle, size: 12, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Text(formatDuration(recordingElapsed)),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Parar'),
          ),
        ],
      );
    }

    final audioPath = this.audioPath;
    if (audioPath == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: canRecord ? onRecord : null,
          icon: const Icon(Icons.mic_none),
          label: const Text('Gravar'),
        ),
      );
    }

    final duration = this.duration;
    return Row(
      children: [
        AudioPlayButton(
          path: audioPath,
          isPlaying: isPlaying,
          onPressed: onTogglePlay,
        ),
        if (duration != null) ...[
          const SizedBox(width: 8),
          Text(formatDuration(duration)),
        ],
        const Spacer(),
        TextButton.icon(
          onPressed: canRecord ? onRecord : null,
          icon: const Icon(Icons.replay),
          label: const Text('Regravar'),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: 'Remover áudio',
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
```

- [ ] **Passo 5: áudio no `SideEditor`**

> **Ajuste da etapa 4 (2026-10-16):** o `SideEditor` também tem `mediaEnabled` (padrão `true`), que desativa Câmera, Galeria e ✕ enquanto salva. Mantenha esse parâmetro e use-o também nos botões de áudio.

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
    required this.audioField,
  });

  final String label;
  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onTextChanged;
  final String? imagePath;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRemoveImage;
  final Widget audioField;

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
        const SizedBox(height: 8),
        audioField,
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

- [ ] **Passo 6: a tela do editor com áudio**

> **Ajuste da etapa 4 (2026-10-16):** a tela passa `mediaEnabled: !_viewModel.isSaving` ao `SideEditor`. Mantenha.

> **Ajuste da etapa 2 (2026-10-15):** o arquivo abaixo precisa manter as proteções de quando o card está salvando: `onPressed: _viewModel.isSaving ? null : _delete` na 🗑, `!_viewModel.isSaving` somado ao `canPop`, o diálogo de descarte só com `!didPop && !_viewModel.isSaving`, e `autofocus: side == Side.front && _viewModel.isNew` no `SideEditor`. Os testes "enquanto salva, a lixeira fica desativada e o voltar não faz nada" e "card novo abre com o cursor na frente" precisam continuar passando.

`lib/ui/card_editor/widgets/card_editor_screen.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../../../domain/models/image_origin.dart';
import '../view_models/card_editor_view_model.dart';
import 'audio_recorder_field.dart';
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
  late final AppLifecycleListener _lifecycle;

  CardEditorViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    // A recording must not go on while the app is out of sight.
    _lifecycle = AppLifecycleListener(onHide: _viewModel.stopRecording);
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
    _lifecycle.dispose();
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
    if (discard != true) return;
    await _viewModel.discard();
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _pickImage(Side side, ImageOrigin origin) async {
    if (!await _viewModel.pickImage(side, origin)) _showActionError();
  }

  Future<void> _startRecording(Side side) async {
    if (!await _viewModel.startRecording(side)) _showActionError();
  }

  Future<void> _togglePlay(Side side) async {
    if (!await _viewModel.togglePlay(side)) _showActionError();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => PopScope<bool>(
        canPop: !_viewModel.hasChanges && !_viewModel.isRecording,
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
      imagePath: _viewModel.imagePath(side),
      onTakePhoto: () => _pickImage(side, ImageOrigin.camera),
      onPickFromGallery: () => _pickImage(side, ImageOrigin.gallery),
      onRemoveImage: () => _viewModel.removeImage(side),
      audioField: AudioRecorderField(
        isRecording: _viewModel.recordingSide == side,
        recordingElapsed: _viewModel.recordingElapsed,
        audioPath: _viewModel.audioPath(side),
        duration: _viewModel.audioDuration(side),
        isPlaying: _viewModel.isPlaying(side),
        canRecord: !_viewModel.isRecording,
        onRecord: () => _startRecording(side),
        onStop: _viewModel.stopRecording,
        onTogglePlay: () => _togglePlay(side),
        onRemove: () => _viewModel.removeAudio(side),
      ),
    );
  }
}
```

- [ ] **Passo 7: áudio no `CardSideView`**

`lib/ui/core/widgets/card_side_view.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'audio_play_button.dart';
import 'media_image.dart';

/// The content of one side of a card, centred, scrolling when it is long.
class CardSideView extends StatelessWidget {
  const CardSideView({
    super.key,
    this.text,
    this.imagePath,
    this.audioPath,
    this.isPlaying = false,
    this.onToggleAudio,
  });

  final String? text;
  final String? imagePath;
  final String? audioPath;
  final bool isPlaying;
  final VoidCallback? onToggleAudio;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final imagePath = this.imagePath;
    final audioPath = this.audioPath;
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
      if (audioPath != null)
        AudioPlayButton(
          path: audioPath,
          isPlaying: isPlaying,
          onPressed: onToggleAudio ?? () {},
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

- [ ] **Passo 8: áudio no `ReviewViewModel`**

`lib/ui/review/view_models/review_view_model.dart` (substitui o arquivo inteiro):
```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../domain/models/flashcard.dart';
import '../../../domain/review_order.dart';
import '../../../utils/result.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel({
    required this.deckId,
    required CardRepository cardRepository,
    required MediaRepository mediaRepository,
    Random? random,
  })  : _cardRepository = cardRepository,
        _mediaRepository = mediaRepository,
        _random = random ?? Random() {
    _mediaRepository.playingPath.addListener(notifyListeners);
  }

  static const loadErrorMessage = 'Não foi possível carregar os cards.';
  static const countErrorMessage = 'Não foi possível salvar a revisão.';
  static const audioErrorMessage = 'Não foi possível tocar o áudio.';

  final int deckId;
  final CardRepository _cardRepository;
  final MediaRepository _mediaRepository;
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

  String? imagePathOf(CardSide side) {
    final image = side.image;
    return image == null ? null : _mediaRepository.mediaPath(image);
  }

  String? audioPathOf(CardSide side) {
    final audio = side.audio;
    return audio == null ? null : _mediaRepository.mediaPath(audio);
  }

  bool isPlaying(CardSide side) {
    final path = audioPathOf(side);
    return path != null && _mediaRepository.playingPath.value == path;
  }

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
    unawaited(stopAudio());
    if (isLast) {
      _isFinished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void previous() {
    if (current == null || isFirst) return;
    unawaited(stopAudio());
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

  /// Plays the side's audio, or stops it when it is already playing.
  /// Returns false when it could not be played.
  Future<bool> toggleAudio(CardSide side) async {
    if (isPlaying(side)) {
      await stopAudio();
      return true;
    }
    final path = audioPathOf(side);
    if (path == null) return false;
    return await _mediaRepository.play(path) is Ok;
  }

  Future<void> stopAudio() => _mediaRepository.stopPlayback();

  @override
  void dispose() {
    _mediaRepository.playingPath.removeListener(notifyListeners);
    _mediaRepository.stopPlayback();
    super.dispose();
  }
}
```

- [ ] **Passo 9: áudio na tela de revisão**

Em `lib/ui/review/widgets/review_screen.dart`:

1. Troque o método `_onFlip` por:
```dart
  Future<void> _onFlip(bool showingBack) async {
    if (!_hasFlipped) setState(() => _hasFlipped = true);
    await _viewModel.stopAudio();
    if (!showingBack) return;
    if (!await _viewModel.markBackSeen() && mounted) {
      _showMessage(ReviewViewModel.countErrorMessage);
    }
  }

  Future<void> _toggleAudio(CardSide side) async {
    if (!await _viewModel.toggleAudio(side) && mounted) {
      _showMessage(ReviewViewModel.audioErrorMessage);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
```

2. Acrescente o import `import '../../../domain/models/card_side.dart';`.

3. Troque os dois `CardSideView` por:
```dart
                child: CardSideView(
                  text: card.front.text,
                  imagePath: _viewModel.imagePathOf(card.front),
                  audioPath: _viewModel.audioPathOf(card.front),
                  isPlaying: _viewModel.isPlaying(card.front),
                  onToggleAudio: () => _toggleAudio(card.front),
                ),
```
e
```dart
                child: CardSideView(
                  text: card.back.text,
                  imagePath: _viewModel.imagePathOf(card.back),
                  audioPath: _viewModel.audioPathOf(card.back),
                  isPlaying: _viewModel.isPlaying(card.back),
                  onToggleAudio: () => _toggleAudio(card.back),
                ),
```

- [ ] **Passo 10: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 11: commit**

```bash
git add lib/ui test/ui
git commit -m "feat: grava e toca áudio no editor e na revisão"
```

---

### Tarefa 5: conferir no celular e fechar a etapa

> **Ajustes feitos na execução (2026-10-18):** os arquivos que as etapas 2 a 4 tinham reforçado receberam o áudio por acréscimo, sem ser substituídos. Depois da revisão final: a contagem na revisão acontece antes de parar o áudio; o ▶ fica desativado durante a gravação; parar sem arquivo ou com falha mostra a mensagem; a gravação ignora interrupções de áudio (`AudioInterruptionMode.none`); o player não fica preso no ■. Veja "Áudio" no [design](../design.md). Os itens novos do checklist conferem isso no celular.

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

- [ ] O primeiro toque em **Gravar** mostra o pedido de permissão do microfone do Android
- [ ] Negar a permissão mostra a mensagem, e o editor continua funcionando. Para conceder depois, use **Configurações › Apps › My Flashcards › Permissões › Microfone**
- [ ] Durante a gravação aparecem o ponto vermelho, o tempo correndo e **Parar**. O SALVAR e o Gravar do outro lado ficam desativados
- [ ] **Parar** mostra **▶**, a duração, **Regravar** e **✕**. O ▶ toca a voz gravada com som claro
- [ ] Gravar por 60 segundos faz a gravação parar sozinha em **1:00**
- [ ] Apertar o botão Home durante a gravação e voltar mostra que ela parou e o áudio ficou
- [ ] Os áudios têm cerca de 40 KB a cada 10 segundos:
  ```bash
  adb shell run-as com.sorayaferreira.myflashcards ls -l app_flutter/media
  ```
- [ ] Na revisão, o áudio **não** toca sozinho. O ▶ toca, e virar o card ou trocar de card para o som
- [ ] Ao reabrir um card salvo no editor, a duração do áudio aparece
- [ ] Um card só com áudio na frente aparece na lista como *"(só áudio)"*, com o ícone de som
- [ ] Durante a gravação de um lado, o ▶ do outro lado fica desativado
- [ ] Ao terminar de tocar um áudio, o botão volta de ■ para ▶ sozinho
- [ ] Tocar um alarme (ou chamar o assistente) durante a gravação não faz ela parar às escondidas: o tempo e o áudio gravado batem
- [ ] Voltar durante a gravação pergunta *"Descartar alterações?"*
- [ ] Apagar um áudio à mão (`adb shell run-as ... rm app_flutter/media/<nome>`) faz aparecer *"Áudio não encontrado"*

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-5-audio -m "Etapa 5: áudio" && git branch -d etapa-5-audio
```
