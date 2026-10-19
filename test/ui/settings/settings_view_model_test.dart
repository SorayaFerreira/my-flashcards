import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/settings/view_models/settings_view_model.dart';
import 'package:my_flashcards/utils/result.dart';

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
  late SettingsViewModel viewModel;

  setUp(() {
    reminders = FakeReminderRepository();
    viewModel = SettingsViewModel(reminderRepository: reminders);
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
      final viewModel = SettingsViewModel(reminderRepository: reminders);

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
    final viewModel = SettingsViewModel(reminderRepository: _EnableThrows());

    await expectLater(
      viewModel.setReminderEnabled(true),
      throwsA(isA<StateError>()),
    );

    expect(viewModel.isBusy, isFalse);
  });
}
