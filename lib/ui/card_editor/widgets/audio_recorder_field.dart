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
    this.enabled = true,
    this.canPlay = true,
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

  /// False while the card is saving: record, re-record and remove are off.
  final bool enabled;

  /// False while any side records: playing then would stop the recording.
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return Row(
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: Theme.of(context).colorScheme.error,
          ),
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
          onPressed: enabled && canRecord ? onRecord : null,
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
          enabled: canPlay,
        ),
        if (duration != null) ...[
          const SizedBox(width: 8),
          Text(formatDuration(duration)),
        ],
        const Spacer(),
        TextButton.icon(
          onPressed: enabled && canRecord ? onRecord : null,
          icon: const Icon(Icons.replay),
          label: const Text('Regravar'),
        ),
        IconButton(
          onPressed: enabled ? onRemove : null,
          tooltip: 'Remover áudio',
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
