import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../domain/reminder_plan.dart';
import '../../utils/dates.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ReminderRepository {
  ReminderRepository({
    required this._database,
    required this._notifications,
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  static const enabledKey = 'reminder_enabled';
  static const scheduledUntilKey = 'reminder_scheduled_until';

  final DatabaseService _database;
  final NotificationService _notifications;
  final Random _random;
  final DateTime Function() _now;

  Future<Result<bool>> isEnabled() => guard(_isEnabled);

  /// Asks for permission and schedules the next 30 days. Ok(false) when
  /// notifications are not allowed.
  Future<Result<bool>> enable() => guard(() async {
    if (!await _notifications.requestPermission()) return false;
    await _notifications.cancelAll();
    await _write(enabledKey, '1');
    await _delete(scheduledUntilKey);
    await _schedule(scheduledUntil: null);
    return true;
  });

  Future<Result<void>> disable() => guard(() async {
    await _notifications.cancelAll();
    await _write(enabledKey, '0');
    await _delete(scheduledUntilKey);
  });

  /// Schedules the days still missing, up to 29 days ahead. Runs every time
  /// the app opens. An unreadable stored date counts as no schedule.
  Future<Result<void>> topUp() => guard(() async {
    if (!await _isEnabled()) return;
    final stored = await _read(scheduledUntilKey);
    await _schedule(
      scheduledUntil: stored == null ? null : tryParseDate(stored),
    );
  });

  /// A restored backup brings the schedule of another install, whose
  /// notifications don't exist here, so the schedule starts over.
  Future<Result<void>> resetAfterImport() => guard(() async {
    await _notifications.cancelAll();
    await _delete(scheduledUntilKey);
    if (!await _isEnabled()) return;
    if (!await _notifications.requestPermission()) {
      await _write(enabledKey, '0');
      return;
    }
    await _schedule(scheduledUntil: null);
  });

  Future<bool> _isEnabled() async => await _read(enabledKey) == '1';

  Future<void> _schedule({required DateTime? scheduledUntil}) async {
    final plan = ReminderPlan.plan(
      now: _now(),
      scheduledUntil: scheduledUntil,
      random: _random,
    );
    for (final reminder in plan) {
      await _notifications.schedule(id: reminder.id, at: reminder.at);
    }
    if (plan.isNotEmpty) {
      await _write(scheduledUntilKey, formatDate(plan.last.at));
    }
  }

  Future<String?> _read(String key) async {
    final rows = await _database.db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> _write(String key, String value) => _database.db.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> _delete(String key) =>
      _database.db.delete('settings', where: 'key = ?', whereArgs: [key]);
}
