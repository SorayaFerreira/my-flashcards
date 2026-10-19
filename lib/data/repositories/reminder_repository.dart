import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

  /// JSON object from the day id ("20261012") to the drawn local time
  /// ("2026-10-12T14:37"), so lost alarms can be registered again without
  /// drawing a day twice.
  static const timesKey = 'reminder_times';

  final DatabaseService _database;
  final NotificationService _notifications;
  final Random _random;
  final DateTime Function() _now;

  Future<Result<bool>> isEnabled() => guard(_isEnabled);

  /// Asks for permission and schedules the next 30 days. Ok(false) when
  /// notifications are not allowed. If scheduling fails, everything is rolled
  /// back to "off" before the error is rethrown.
  Future<Result<bool>> enable() => guard(() async {
    if (!await _notifications.requestPermission()) return false;
    try {
      await _notifications.cancelAll();
      await _write(enabledKey, '1');
      await _delete(scheduledUntilKey);
      await _delete(timesKey);
      await _schedule(scheduledUntil: null, times: {});
    } on Object {
      await _rollBack();
      rethrow;
    }
    return true;
  });

  Future<void> _rollBack() async {
    try {
      await _notifications.cancelAll();
    } on Object catch (error) {
      debugPrint('Rollback could not cancel the reminders: $error');
    }
    await _write(enabledKey, '0');
    await _delete(scheduledUntilKey);
    await _delete(timesKey);
  }

  Future<Result<void>> disable() => guard(() async {
    await _notifications.cancelAll();
    await _write(enabledKey, '0');
    await _delete(scheduledUntilKey);
    await _delete(timesKey);
  });

  /// Runs every time the app opens. Registers again the drawn times that are
  /// still in the future (Android loses all alarms on a force stop or when an
  /// OEM blocks the boot broadcast), then schedules the days still missing,
  /// up to 29 days ahead. An unreadable stored date counts as no schedule.
  Future<Result<void>> topUp() => guard(() async {
    if (!await _isEnabled()) return;
    await _notifications.refreshTimeZone();
    final now = _now();
    final times = await _readTimes()
      ..removeWhere((_, at) => !at.isAfter(now));
    for (final MapEntry(:key, :value) in times.entries) {
      await _notifications.schedule(id: key, at: value);
    }
    await _writeTimes(times);

    final stored = await _read(scheduledUntilKey);
    var scheduledUntil = stored == null ? null : tryParseDate(stored);
    // A date beyond the window means the clock was moved far ahead and back.
    if (scheduledUntil != null &&
        scheduledUntil.isAfter(addDays(dateOnly(now), ReminderPlan.days - 1))) {
      scheduledUntil = null;
    }
    await _schedule(scheduledUntil: scheduledUntil, times: times);
  });

  /// A restored backup brings the schedule of another install, whose
  /// notifications don't exist here, so the schedule starts over.
  Future<Result<void>> resetAfterImport() => guard(() async {
    await _notifications.cancelAll();
    await _delete(scheduledUntilKey);
    await _delete(timesKey);
    if (!await _isEnabled()) return;
    if (!await _notifications.requestPermission()) {
      await _write(enabledKey, '0');
      return;
    }
    await _schedule(scheduledUntil: null, times: {});
  });

  Future<bool> _isEnabled() async => await _read(enabledKey) == '1';

  /// Plans and schedules the missing days, adding them to [times] and saving
  /// both the times and the last scheduled day.
  Future<void> _schedule({
    required DateTime? scheduledUntil,
    required Map<int, DateTime> times,
  }) async {
    await _notifications.refreshTimeZone();
    final plan = ReminderPlan.plan(
      now: _now(),
      scheduledUntil: scheduledUntil,
      random: _random,
    );
    for (final reminder in plan) {
      await _notifications.schedule(id: reminder.id, at: reminder.at);
      times[reminder.id] = reminder.at;
    }
    if (plan.isNotEmpty) {
      await _database.db.transaction((txn) async {
        await _writeTimes(times, txn);
        await _write(scheduledUntilKey, formatDate(plan.last.at), txn);
      });
    }
  }

  /// A malformed value counts as an empty map.
  Future<Map<int, DateTime>> _readTimes() async {
    final stored = await _read(timesKey);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return {};
      final times = <int, DateTime>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        final id = int.tryParse(key);
        final at = value is String ? tryParseDateTime(value) : null;
        if (id == null || at == null) return {};
        times[id] = at;
      }
      return times;
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeTimes(Map<int, DateTime> times, [DatabaseExecutor? db]) =>
      _write(
        timesKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in times.entries)
            '$key': formatDateTime(value),
        }),
        db,
      );

  Future<String?> _read(String key) async {
    final rows = await _database.db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> _write(String key, String value, [DatabaseExecutor? db]) =>
      (db ?? _database.db).insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _delete(String key) =>
      _database.db.delete('settings', where: 'key = ?', whereArgs: [key]);
}
