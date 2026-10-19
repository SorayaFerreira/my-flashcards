import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thrown when the service is used before [NotificationService.initialize]
/// completed; scheduling then would use the wrong (UTC) time zone.
class NotificationsUnavailableException implements Exception {
  const NotificationsUnavailableException();

  @override
  String toString() => 'NotificationsUnavailableException';
}

/// Thrown when the plugin refuses a schedule, such as a time it considers to
/// be in the past. Wraps its [ArgumentError] so that `guard` can catch it.
class NotificationScheduleException implements Exception {
  const NotificationScheduleException(this.message);

  final String message;

  @override
  String toString() => 'NotificationScheduleException: $message';
}

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
  var _ready = false;

  void _requireReady() {
    if (!_ready) throw const NotificationsUnavailableException();
  }

  /// Throws, leaving the service unavailable, if the device time zone can't
  /// be read at startup: scheduling then would use UTC.
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await _applyDeviceTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    _ready = true;
  }

  /// Sets [tz.local] to the device zone. Throws if the zone can't be read or
  /// isn't in the bundled database.
  Future<void> _applyDeviceTimeZone() async {
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
  }

  /// Re-reads the device time zone, which may have changed while the app was
  /// alive. If it can't be read, [tz.local] stays as it is.
  Future<void> refreshTimeZone() async {
    try {
      await _applyDeviceTimeZone();
    } on Object catch (error) {
      debugPrint('Could not refresh the time zone: $error');
    }
  }

  /// Shows the system prompt the first time. Returns whether notifications
  /// are allowed.
  Future<bool> requestPermission() async {
    _requireReady();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  /// Schedules a notification at the local time [at]. It may arrive a few
  /// minutes late, which spares the app the exact-alarm permission.
  Future<void> schedule({required int id, required DateTime at}) async {
    _requireReady();
    final when = tz.TZDateTime(
      tz.local,
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute,
    );
    // The plugin throws for a past time, which happens when tz.local
    // disagrees with the device; such a day is simply skipped.
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Hora de revisar!',
        body: 'Seus flashcards estão esperando por você.',
      );
    } on ArgumentError catch (error) {
      throw NotificationScheduleException('$error');
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
