import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app_version.dart';
import 'package:my_flashcards/ui/settings/view_models/settings_view_model.dart';
import 'package:my_flashcards/ui/settings/widgets/settings_screen.dart';

import '../../fakes/fake_backup_repository.dart';
import '../../fakes/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository reminders;
  late FakeBackupRepository backups;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(
                      viewModel: SettingsViewModel(
                        reminderRepository: reminders,
                        backupRepository: backups,
                      ),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  setUp(() {
    reminders = FakeReminderRepository();
    backups = FakeBackupRepository();
  });

  testWidgets('mostra o lembrete desligado, a explicação e a versão', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Lembrete diário'), findsOneWidget);
    expect(
      find.text('Um por dia, em horário aleatório entre 9h e 20h'),
      findsOneWidget,
    );
    expect(find.text('Versão $appVersion'), findsOneWidget);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('tocar no interruptor liga o lembrete', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lembrete diário'));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isTrue);
    expect(reminders.enabled, isTrue);
  });

  testWidgets('permissão negada volta para desligado com a mensagem', (
    tester,
  ) async {
    reminders.permissionAllowed = false;
    await pumpScreen(tester);

    await tester.tap(find.text('Lembrete diário'));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(
      find.text(SettingsViewModel.permissionDeniedMessage),
      findsOneWidget,
    );
  });
}
