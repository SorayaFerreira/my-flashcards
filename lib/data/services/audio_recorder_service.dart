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
