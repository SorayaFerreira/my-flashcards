import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembrete_diario',
      'Lembrete diário',
      channelDescription: 'Um lembrete por dia para revisar os flashcards.',
      icon: 'ic_notification',
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  /// Shows the system prompt the first time. Returns whether notifications
  /// are allowed.
  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;

  /// Schedules a notification at the local time [at]. It may arrive a few
  /// minutes late, which spares the app the exact-alarm permission.
  Future<void> schedule({required int id, required DateTime at}) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Hora de revisar!',
        body: 'Seus flashcards estão esperando por você.',
      );

  Future<void> cancelAll() => _plugin.cancelAll();
}
