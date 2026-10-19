import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/settings/view_models/settings_view_model.dart';
import 'package:my_flashcards/utils/result.dart';

import '../../fakes/fake_backup_repository.dart';
import '../../fakes/fake_reminder_repository.dart';

/// Schedules nothing and fails, but the stored flag was already switched on.
class _EnableFailsAfterSaving extends FakeReminderRepository {
  @override
  Future<Result<bool>> enable() async {
    enabled = true;
    return Result.error(Exception('agendamento'));
  }
}

/// Throws instead of returning an Error, like an unexpected bug would.
class _EnableThrows extends FakeReminderRepository {
  @override
  Future<Result<bool>> enable() async => throw StateError('bug');
}

void main() {
  late FakeReminderRepository reminders;
  late FakeBackupRepository backups;
  late SettingsViewModel viewModel;

  setUp(() {
    reminders = FakeReminderRepository();
    backups = FakeBackupRepository();
    viewModel = SettingsViewModel(
      reminderRepository: reminders,
      backupRepository: backups,
    );
  });

  test('load lê se o lembrete está ligado', () async {
    reminders.enabled = true;

    await viewModel.load();

    expect(viewModel.reminderEnabled, isTrue);
  });

  test('ligar o lembrete', () async {
    expect(await viewModel.setReminderEnabled(true), isTrue);

    expect(viewModel.reminderEnabled, isTrue);
    expect(viewModel.message, isNull);
    expect(viewModel.isBusy, isFalse);
  });

  test('permissão negada mantém desligado e explica o que fazer', () async {
    reminders.permissionAllowed = false;

    expect(await viewModel.setReminderEnabled(true), isFalse);

    expect(viewModel.reminderEnabled, isFalse);
    expect(viewModel.message, SettingsViewModel.permissionDeniedMessage);
  });

  test('desligar o lembrete', () async {
    reminders.enabled = true;
    await viewModel.load();

    expect(await viewModel.setReminderEnabled(false), isTrue);

    expect(viewModel.reminderEnabled, isFalse);
  });

  test('falha mantém o estado anterior e mostra a mensagem', () async {
    reminders.failWith = Exception('disco');

    expect(await viewModel.setReminderEnabled(true), isFalse);

    expect(viewModel.reminderEnabled, isFalse);
    expect(viewModel.message, SettingsViewModel.reminderErrorMessage);
  });

  test(
    'falha ao ligar após salvar o estado mostra o que está gravado',
    () async {
      final reminders = _EnableFailsAfterSaving();
      final viewModel = SettingsViewModel(
        reminderRepository: reminders,
        backupRepository: backups,
      );

      expect(await viewModel.setReminderEnabled(true), isFalse);

      expect(viewModel.reminderEnabled, isTrue);
      expect(viewModel.message, SettingsViewModel.reminderErrorMessage);
    },
  );

  test('toque duplo executa a ação uma vez só', () async {
    final first = viewModel.setReminderEnabled(true);
    final second = await viewModel.setReminderEnabled(true);

    expect(second, isFalse);
    expect(viewModel.message, isNull);
    expect(await first, isTrue);
    expect(reminders.enableCalls, 1);
  });

  test('erro inesperado se propaga, mas a chave não fica travada', () async {
    final viewModel = SettingsViewModel(
      reminderRepository: _EnableThrows(),
      backupRepository: backups,
    );

    await expectLater(
      viewModel.setReminderEnabled(true),
      throwsA(isA<StateError>()),
    );

    expect(viewModel.isBusy, isFalse);
  });

  group('backup', () {
    test('exportar gera o zip e abre o menu de compartilhar', () async {
      expect(await viewModel.exportBackup(), isTrue);

      expect(backups.shared, ['/tmp/my-flashcards-backup-2026-10-12.zip']);
      expect(viewModel.isBusy, isFalse);
    });

    test('falha ao exportar mostra a mensagem', () async {
      backups.exportError = Exception('sem espaço');

      expect(await viewModel.exportBackup(), isFalse);

      expect(viewModel.message, SettingsViewModel.exportErrorMessage);
      expect(backups.shared, isEmpty);
    });

    test('toque duplo em exportar executa a exportação uma vez só', () async {
      final first = viewModel.exportBackup();
      final second = await viewModel.exportBackup();

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(backups.exportCalls, 1);
      expect(viewModel.isBusy, isFalse);
    });

    test('escolher um backup válido devolve o manifesto', () async {
      final manifest = await viewModel.pickAndPrepareImport();

      expect(manifest?.cards, 87);
      expect(viewModel.message, isNull);
    });

    test('cancelar a escolha do arquivo não mostra mensagem', () async {
      backups.pickedPath = null;

      expect(await viewModel.pickAndPrepareImport(), isNull);
      expect(viewModel.message, isNull);
    });

    test('arquivo inválido mostra a mensagem de backup inválido', () async {
      backups.prepareError = const FormatException('não é zip');

      expect(await viewModel.pickAndPrepareImport(), isNull);
      expect(viewModel.message, SettingsViewModel.invalidBackupMessage);
    });

    test('confirmar troca os dados e recomeça o lembrete', () async {
      reminders.enabled = true;

      expect(await viewModel.confirmImport(), isTrue);

      expect(backups.applyCalls, 1);
      expect(reminders.resetCalls, 1);
      expect(viewModel.reminderEnabled, isTrue);
      expect(viewModel.notice, isNull);
    });

    test('confirmar avisa quando o lembrete foi desligado', () async {
      reminders.enabled = true;
      reminders.disableOnReset = true;

      expect(await viewModel.confirmImport(), isTrue);

      expect(viewModel.reminderEnabled, isFalse);
      expect(viewModel.notice, SettingsViewModel.reminderOffAfterImportNotice);
      expect(viewModel.message, isNull);
    });

    test('falha ao importar avisa que nada mudou', () async {
      backups.applyError = Exception('falha');

      expect(await viewModel.confirmImport(), isFalse);

      expect(viewModel.message, SettingsViewModel.importErrorMessage);
      expect(reminders.resetCalls, 0);
      expect(viewModel.isBusy, isFalse);
    });

    test('cancelImport desiste da importação', () async {
      await viewModel.cancelImport();

      expect(backups.cancelCalls, 1);
    });
  });
}
