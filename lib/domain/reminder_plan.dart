import 'dart:math';

import '../utils/dates.dart';

class PlannedReminder {
  const PlannedReminder({required this.id, required this.at});

  /// The day as a number, such as 20261012: one notification per day, so
  /// scheduling the same day again replaces it instead of adding another.
  final int id;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder && other.id == id && other.at == at;

  @override
  int get hashCode => Object.hash(id, at);

  @override
  String toString() => 'PlannedReminder($id, $at)';
}

abstract final class ReminderPlan {
  static const firstMinute = 9 * 60;
  static const lastMinute = 20 * 60;
  static const days = 30;
  static const minimumLead = Duration(minutes: 30);

  /// The reminders still missing so that every day from today to 29 days
  /// ahead has one, each at a random minute from 9:00 to 19:59.
  ///
  /// [scheduledUntil] is the last day that already has a reminder; those days
  /// are never drawn again.
  static List<PlannedReminder> plan({
    required DateTime now,
    required DateTime? scheduledUntil,
    required Random random,
  }) {
    final today = dateOnly(now);
    final lastDay = addDays(today, days - 1);
    final DateTime start;
    if (scheduledUntil != null && !scheduledUntil.isBefore(today)) {
      start = addDays(dateOnly(scheduledUntil), 1);
    } else {
      start = _earliestMinuteToday(now) < lastMinute
          ? today
          : addDays(today, 1);
    }
    return [
      for (var day = start; !day.isAfter(lastDay); day = addDays(day, 1))
        _reminderOn(
          day,
          earliest: day == today ? _earliestMinuteToday(now) : firstMinute,
          random: random,
        ),
    ];
  }

  static int _earliestMinuteToday(DateTime now) {
    final lead = now.add(minimumLead);
    if (dateOnly(lead) != dateOnly(now)) return 24 * 60;
    final roundUp =
        lead.second > 0 || lead.millisecond > 0 || lead.microsecond > 0;
    final minute = lead.hour * 60 + lead.minute + (roundUp ? 1 : 0);
    return max(firstMinute, minute);
  }

  static PlannedReminder _reminderOn(
    DateTime day, {
    required int earliest,
    required Random random,
  }) {
    final minute = earliest + random.nextInt(lastMinute - earliest);
    return PlannedReminder(
      id: day.year * 10000 + day.month * 100 + day.day,
      at: DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60),
    );
  }
}
