import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's only audio player, so two sounds never play at once.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
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
