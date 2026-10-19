import 'package:my_flashcards/data/services/notification_service.dart';

/// Keeps scheduled notifications in [scheduled], by id. Like the real
/// plugin, scheduling an id again replaces the old one.
class FakeNotificationService implements NotificationService {
  bool allowed = true;
  final scheduled = <int, DateTime>{};
  var cancelAllCalls = 0;
  var permissionRequests = 0;
  var timeZoneRefreshes = 0;

  /// Ids whose scheduling throws what the real service throws when the
  /// plugin refuses a time.
  final failScheduleFor = <int>{};

  /// Makes every `schedule` call throw this.
  Exception? failScheduleWith;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshTimeZone() async => timeZoneRefreshes++;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> schedule({required int id, required DateTime at}) async {
    if (failScheduleWith case final error?) throw error;
    if (failScheduleFor.contains(id)) {
      throw const NotificationScheduleException('Must be a date in the future');
    }
    scheduled[id] = at;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}
