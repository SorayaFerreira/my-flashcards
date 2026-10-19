import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's only audio player, so two sounds never play at once.
class AudioPlayerService {
  AudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _player.onPlayerComplete.listen(
      (_) => _playingPath.value = null,
      onError: (Object _) => _playingPath.value = null,
    );
    // Anything but "playing" (paused by the system, stopped by an error...)
    // must not leave the button on ■.
    _player.onPlayerStateChanged.listen((state) {
      if (!_isStarting && state != PlayerState.playing) {
        _playingPath.value = null;
      }
    }, onError: (Object _) => _playingPath.value = null);
  }

  final AudioPlayer _player;
  final _playingPath = ValueNotifier<String?>(null);

  /// True inside [play], so the `stopped` event of its own `stop()` doesn't
  /// clear the path that is about to be set.
  bool _isStarting = false;

  /// The file being played, or null when nothing is playing.
  ValueListenable<String?> get playingPath => _playingPath;

  Future<void> play(String path) async {
    _isStarting = true;
    try {
      await _player.stop();
      _playingPath.value = path;
      await _player.play(DeviceFileSource(path));
    } catch (_) {
      _playingPath.value = null;
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      _playingPath.value = null;
    }
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
