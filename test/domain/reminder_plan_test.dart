import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/reminder_plan.dart';
import 'package:my_flashcards/utils/dates.dart';

void main() {
  List<PlannedReminder> plan(DateTime now, {DateTime? scheduledUntil}) =>
      ReminderPlan.plan(
        now: now,
        scheduledUntil: scheduledUntil,
        random: Random(1),
      );

  int minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

  test('ligado às 10h: 30 dias, começando hoje, depois das 10:30', () {
    final now = DateTime(2026, 10, 12, 10, 0);

    final reminders = plan(now);

    expect(reminders, hasLength(30));
    expect(reminders.first.id, 20261012);
    expect(reminders.last.id, 20261110);
    expect(minuteOfDay(reminders.first.at), greaterThanOrEqualTo(10 * 60 + 30));
  });

  test('todos os horários ficam entre 9:00 e 19:59', () {
    final reminders = plan(DateTime(2026, 10, 12, 6, 0));

    for (final reminder in reminders) {
      expect(minuteOfDay(reminder.at), greaterThanOrEqualTo(9 * 60));
      expect(minuteOfDay(reminder.at), lessThan(20 * 60));
    }
  });

  test('cada dia tem um único lembrete, no próprio dia', () {
    final reminders = plan(DateTime(2026, 10, 12, 6, 0));

    expect(reminders.map((r) => r.id).toSet(), hasLength(30));
    for (final reminder in reminders) {
      final at = reminder.at;
      expect(reminder.id, at.year * 10000 + at.month * 100 + at.day);
    }
  });

  test('os horários variam de um dia para o outro', () {
    final reminders = plan(DateTime(2026, 10, 12, 6, 0));

    expect(
      reminders.map((r) => minuteOfDay(r.at)).toSet().length,
      greaterThan(10),
    );
  });

  test('ligado às 19:40: hoje não dá mais tempo, começa amanhã', () {
    final reminders = plan(DateTime(2026, 10, 12, 19, 40));

    expect(reminders.first.id, 20261013);
    expect(reminders, hasLength(29));
  });

  test('ligado às 19:29: hoje ainda entra, às 19:59', () {
    final reminders = plan(DateTime(2026, 10, 12, 19, 29));

    expect(reminders.first.id, 20261012);
    expect(reminders.first.at, DateTime(2026, 10, 12, 19, 59));
  });

  test('ligado às 23:50: começa amanhã', () {
    expect(plan(DateTime(2026, 10, 12, 23, 50)).first.id, 20261013);
  });

  test('com a agenda completa, não agenda nada', () {
    final reminders = plan(
      DateTime(2026, 10, 12, 10, 0),
      scheduledUntil: DateTime(2026, 11, 10),
    );

    expect(reminders, isEmpty);
  });

  test('completa só os dias depois do último agendado', () {
    final reminders = plan(
      DateTime(2026, 10, 12, 10, 0),
      scheduledUntil: DateTime(2026, 10, 17),
    );

    expect(reminders.first.id, 20261018);
    expect(reminders.last.id, 20261110);
    expect(reminders, hasLength(24));
  });

  test('agenda vencida há muito tempo recomeça a partir de hoje', () {
    final reminders = plan(
      DateTime(2026, 10, 12, 10, 0),
      scheduledUntil: DateTime(2026, 8, 1),
    );

    expect(reminders.first.id, 20261012);
    expect(reminders, hasLength(30));
  });

  test('vira o mês e o ano sem errar as datas', () {
    final reminders = plan(DateTime(2026, 12, 31, 8, 0));

    expect(reminders[0].id, 20261231);
    expect(reminders[1].id, 20270101);
    expect(reminders[1].at.year, 2027);
  });

  test('formatDate e parseDate vão e voltam', () {
    expect(formatDate(DateTime(2026, 3, 7, 15, 30)), '2026-03-07');
    expect(parseDate('2026-03-07'), DateTime(2026, 3, 7));
  });
}
