import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app_version.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';
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

  testWidgets('Exportar backup abre o menu de compartilhar', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();

    expect(backups.shared, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('falha ao exportar mostra a mensagem', (tester) async {
    backups.exportError = Exception('sem espaço');
    await pumpScreen(tester);

    await tester.tap(find.text('Exportar backup'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível gerar o backup.'), findsOneWidget);
  });

  testWidgets('Importar pede confirmação com o resumo e volta aos decks', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();

    expect(find.text('Substituir todos os dados?'), findsOneWidget);
    expect(
      find.text(
        'O backup de 11/10/2026 tem 3 decks e 87 cards. '
        'Seus decks atuais serão apagados.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();

    expect(backups.applyCalls, 1);
    expect(reminders.resetCalls, 1);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('lembrete desligado pela importação mostra o aviso nos decks', (
    tester,
  ) async {
    reminders.enabled = true;
    reminders.disableOnReset = true;
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Substituir'));
    await tester.pumpAndSettle();

    expect(find.text('abrir'), findsOneWidget);
    expect(
      find.text(SettingsViewModel.reminderOffAfterImportNotice),
      findsOneWidget,
    );
  });

  testWidgets('Cancelar na confirmação não muda nada', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(backups.applyCalls, 0);
    expect(backups.cancelCalls, 1);
    expect(find.text('Configurações'), findsOneWidget);
  });

  testWidgets('fechar a confirmação tocando fora cancela a importação', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Substituir todos os dados?'), findsNothing);
    expect(backups.cancelCalls, 1);
    expect(backups.applyCalls, 0);
    expect(find.text('Configurações'), findsOneWidget);
  });

  testWidgets('arquivo inválido mostra a mensagem e não pede confirmação', (
    tester,
  ) async {
    backups.prepareError = const FormatException('não é zip');
    await pumpScreen(tester);

    await tester.tap(find.text('Importar backup'));
    await tester.pumpAndSettle();

    expect(
      find.text('Este arquivo não é um backup do My Flashcards.'),
      findsOneWidget,
    );
    expect(find.text('Substituir todos os dados?'), findsNothing);
  });

  test('importConfirmationText usa singular e plural', () {
    BackupManifest manifest(int decks, int cards) => BackupManifest(
      app: BackupManifest.appId,
      formatVersion: 1,
      schemaVersion: 1,
      exportedAt: DateTime(2026, 3, 7),
      decks: decks,
      cards: cards,
    );

    expect(
      importConfirmationText(manifest(1, 1)),
      'O backup de 07/03/2026 tem 1 deck e 1 card. '
      'Seus decks atuais serão apagados.',
    );
    expect(
      importConfirmationText(manifest(0, 0)),
      'O backup de 07/03/2026 tem 0 decks e 0 cards. '
      'Seus decks atuais serão apagados.',
    );
  });
}
