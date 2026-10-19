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
    this.enabled = true,
  });

  final String path;
  final bool isPlaying;
  final VoidCallback onPressed;

  /// False turns ▶ / ■ off, e.g. while a recording is going on.
  final bool enabled;

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
      onPressed: enabled ? onPressed : null,
      tooltip: isPlaying ? 'Parar' : 'Ouvir',
      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
    );
  }
}
