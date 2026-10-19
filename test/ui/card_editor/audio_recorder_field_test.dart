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
    bool enabled = true,
  }) => MaterialApp(
    home: Scaffold(
      body: AudioRecorderField(
        isRecording: isRecording,
        recordingElapsed: elapsed,
        audioPath: audioPath,
        duration: duration,
        isPlaying: false,
        canRecord: canRecord,
        enabled: enabled,
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

  testWidgets('Gravar fica desativado enquanto o outro lado grava', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      field(audioPath: '$root/aud_1.m4a', duration: const Duration(seconds: 4)),
    );

    expect(find.text('0:04'), findsOneWidget);
    await tester.tap(find.byTooltip('Ouvir'));
    await tester.tap(find.text('Regravar'));
    await tester.tap(find.byTooltip('Remover áudio'));

    expect(calls, ['tocar', 'gravar', 'remover']);
  });

  testWidgets('áudio sumido mostra "Áudio não encontrado" desativado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioPlayButton(
            path: '/nao/existe.m4a',
            isPlaying: false,
            onPressed: () => calls.add('tocar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Áudio não encontrado'));

    expect(calls, isEmpty);
  });

  testWidgets('enabled false desativa Gravar, Regravar e ✕', (tester) async {
    await tester.pumpWidget(field(enabled: false));
    await tester.tap(find.text('Gravar'));
    expect(calls, isEmpty);

    final root = createFakeMediaRoot(['aud_1.m4a']);
    await tester.pumpWidget(
      field(
        audioPath: '$root/aud_1.m4a',
        duration: const Duration(seconds: 4),
        enabled: false,
      ),
    );
    await tester.tap(find.text('Regravar'));
    await tester.tap(find.byTooltip('Remover áudio'));
    expect(calls, isEmpty);
  });
}
