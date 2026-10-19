import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/reminder_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';

import '../../fakes/fake_notification_service.dart';
import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late FakeNotificationService notifications;
  late ReminderRepository repository;
  late DateTime now;

  setUp(() async {
    database = await openTestDatabase();
    notifications = FakeNotificationService();
    now = DateTime(2026, 10, 12, 10, 0);
    repository = ReminderRepository(
      database: database,
      notifications: notifications,
      random: Random(1),
      now: () => now,
    );
  });
  tearDown(() => database.close());

  Future<String?> setting(String key) async {
    final rows = await database.db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  test('começa desligado', () async {
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('ligar pede permissão e agenda 30 dias', () async {
    expect(okValue(await repository.enable()), isTrue);

    expect(notifications.permissionRequests, 1);
    expect(notifications.scheduled, hasLength(30));
    expect(notifications.scheduled.keys, contains(20261012));
    expect(okValue(await repository.isEnabled()), isTrue);
    expect(await setting(ReminderRepository.scheduledUntilKey), '2026-11-10');
  });

  test('permissão negada não liga nem agenda', () async {
    notifications.allowed = false;

    expect(okValue(await repository.enable()), isFalse);

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('abrir o app de novo no mesmo dia não sorteia nada', () async {
    await repository.enable();
    final before = Map.of(notifications.scheduled);

    okValue(await repository.topUp());
    okValue(await repository.topUp());

    expect(notifications.scheduled, before);
  });

  test('abrir no dia seguinte agenda só o dia novo do fim', () async {
    await repository.enable();
    final before = Map.of(notifications.scheduled);
    now = now.add(const Duration(days: 1));

    okValue(await repository.topUp());

    expect(notifications.scheduled.length, before.length + 1);
    expect(notifications.scheduled[20261111], isNotNull);
    for (final MapEntry(:key, :value) in before.entries) {
      expect(notifications.scheduled[key], value);
    }
  });

  test('topUp com o lembrete desligado não faz nada', () async {
    okValue(await repository.topUp());

    expect(notifications.scheduled, isEmpty);
  });

  test(
    'topUp com data gravada inválida agenda 30 dias a partir de hoje',
    () async {
      await database.db.insert('settings', {
        'key': ReminderRepository.enabledKey,
        'value': '1',
      });
      await database.db.insert('settings', {
        'key': ReminderRepository.scheduledUntilKey,
        'value': 'lixo',
      });

      okValue(await repository.topUp());

      expect(notifications.scheduled, hasLength(30));
      expect(notifications.scheduled.keys, contains(20261012));
    },
  );

  test('desligar cancela tudo e esquece a agenda', () async {
    await repository.enable();

    okValue(await repository.disable());

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
    expect(await setting(ReminderRepository.scheduledUntilKey), isNull);
  });

  test(
    'depois de importar um backup ligado, recomeça a agenda do zero',
    () async {
      await database.db.insert('settings', {
        'key': ReminderRepository.enabledKey,
        'value': '1',
      });
      await database.db.insert('settings', {
        'key': ReminderRepository.scheduledUntilKey,
        'value': '2026-12-31',
      });

      okValue(await repository.resetAfterImport());

      expect(notifications.cancelAllCalls, 1);
      expect(notifications.scheduled, hasLength(30));
      expect(await setting(ReminderRepository.scheduledUntilKey), '2026-11-10');
    },
  );

  test('importar com o lembrete ligado, mas sem permissão, desliga', () async {
    await database.db.insert('settings', {
      'key': ReminderRepository.enabledKey,
      'value': '1',
    });
    notifications.allowed = false;

    okValue(await repository.resetAfterImport());

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('importar um backup desligado só cancela', () async {
    okValue(await repository.resetAfterImport());

    expect(notifications.cancelAllCalls, 1);
    expect(notifications.permissionRequests, 0);
  });
}
