import 'package:flutter/foundation.dart';

import '../../domain/models/image_origin.dart';
import '../../utils/result.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/image_picker_service.dart';
import '../services/media_file_service.dart';

class MediaRepository {
  MediaRepository({
    required this._files,
    required this._imagePicker,
    required this._recorder,
    required this._player,
  });

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
    await guard(() async {
      await _files.clearDrafts();
      await _files.clearPickerLeftovers();
    });
  }

  /// Ok(false) when the user denies the microphone.
  Future<Result<bool>> requestMicrophone() =>
      guard(_recorder.requestPermission);

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
