import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/reminder_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/utils/result.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

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

  Future<void> put(String key, String value) => database.db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  group('alarmes perdidos', () {
    test('abrir o app registra de novo os horários já sorteados', () async {
      await repository.enable();
      final before = Map.of(notifications.scheduled);
      notifications.scheduled.clear(); // força parar: o Android perdeu tudo
      now = now.add(const Duration(hours: 1)); // hoje às 11:00

      okValue(await repository.topUp());

      final expected = {
        for (final MapEntry(:key, :value) in before.entries)
          if (value.isAfter(now)) key: value,
      };
      expect(expected.length, greaterThan(25));
      expect(notifications.scheduled, expected);
      expect(notifications.timeZoneRefreshes, greaterThanOrEqualTo(2));
    });

    test('horários passados são podados e não reagendados', () async {
      await repository.enable();
      final before = Map.of(notifications.scheduled);
      notifications.scheduled.clear();
      now = DateTime(2026, 10, 15, 8, 0); // 12, 13 e 14 já passaram

      okValue(await repository.topUp());

      for (final id in [20261012, 20261013, 20261014]) {
        expect(notifications.scheduled.containsKey(id), isFalse);
      }
      expect(notifications.scheduled[20261015], before[20261015]);
      final stored =
          jsonDecode((await setting(ReminderRepository.timesKey))!) as Map;
      expect(stored.keys, isNot(contains('20261012')));
      expect(stored.keys, contains('20261015'));
    });

    test('reminder_times malformado age como mapa vazio', () async {
      await put(ReminderRepository.enabledKey, '1');
      await put(ReminderRepository.timesKey, '{"20261012": "lixo"');

      okValue(await repository.topUp());

      expect(notifications.scheduled, hasLength(30));
      expect(notifications.scheduled.keys, contains(20261012));
    });

    test('reminder_times de outro tipo também é ignorado', () async {
      await put(ReminderRepository.enabledKey, '1');
      await put(ReminderRepository.timesKey, '[1, 2]');

      okValue(await repository.topUp());

      expect(notifications.scheduled, hasLength(30));
    });

    test('desligar apaga reminder_times', () async {
      await repository.enable();
      expect(await setting(ReminderRepository.timesKey), isNotNull);

      okValue(await repository.disable());

      expect(await setting(ReminderRepository.timesKey), isNull);
    });

    test('importar recomeça os horários do zero', () async {
      await put(ReminderRepository.enabledKey, '1');
      await put(ReminderRepository.timesKey, '{"20300101":"2030-01-01T10:00"}');

      okValue(await repository.resetAfterImport());

      final stored =
          jsonDecode((await setting(ReminderRepository.timesKey))!) as Map;
      expect(stored, hasLength(30));
      expect(stored.keys, isNot(contains('20300101')));
    });
  });

  test('scheduled_until além de hoje + 29 recomeça do zero', () async {
    await put(ReminderRepository.enabledKey, '1');
    await put(ReminderRepository.scheduledUntilKey, '2026-12-31');

    okValue(await repository.topUp());

    expect(notifications.scheduled, hasLength(30));
    expect(notifications.scheduled.keys, contains(20261012));
    expect(await setting(ReminderRepository.scheduledUntilKey), '2026-11-10');
  });

  group('falhas de agendamento', () {
    test('ArgumentError do plugin em um dia vira Result.error', () async {
      notifications.failScheduleFor.add(20261020);

      expect(await repository.enable(), isA<Error<bool>>());

      await put(ReminderRepository.enabledKey, '1');
      expect(await repository.topUp(), isA<Error<void>>());
    });

    test('enable que falha desfaz tudo', () async {
      notifications.failScheduleWith = Exception('plugin');

      expect(await repository.enable(), isA<Error<bool>>());

      expect(okValue(await repository.isEnabled()), isFalse);
      expect(notifications.scheduled, isEmpty);
      expect(await setting(ReminderRepository.scheduledUntilKey), isNull);
      expect(await setting(ReminderRepository.timesKey), isNull);
    });

    test('enable que falha no meio cancela o que já foi agendado', () async {
      notifications.failScheduleFor.add(20261020);

      expect(await repository.enable(), isA<Error<bool>>());

      expect(notifications.scheduled, isEmpty);
      expect(okValue(await repository.isEnabled()), isFalse);
    });
  });
}
