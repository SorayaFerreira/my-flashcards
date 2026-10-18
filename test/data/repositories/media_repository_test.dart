import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/data/services/audio_player_service.dart';
import 'package:my_flashcards/data/services/audio_recorder_service.dart';
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
  Future<Duration?> durationOf(String path) async => const Duration(seconds: 4);
}

void main() {
  late MediaFileService files;
  late _FakeImagePicker picker;
  late _FakeRecorder recorder;
  late _FakePlayer player;
  late MediaRepository repository;

  setUp(() async {
    files = await createTempMediaFiles();
    picker = _FakeImagePicker();
    recorder = _FakeRecorder();
    player = _FakePlayer();
    repository = MediaRepository(
      files: files,
      imagePicker: picker,
      recorder: recorder,
      player: player,
    );
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

    final leftover = File(p.join(files.draftDir.parent.path, 'scaled_1.jpg'))
      ..writeAsStringSync('x');

    await repository.clearDrafts();
    expect(files.draftDir.listSync(), isEmpty);
    expect(leftover.existsSync(), isFalse);
  });

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
}
