import 'package:my_flashcards/data/services/notification_service.dart';

/// Keeps scheduled notifications in [scheduled], by id. Like the real
/// plugin, scheduling an id again replaces the old one.
class FakeNotificationService implements NotificationService {
  bool allowed = true;
  final scheduled = <int, DateTime>{};
  var cancelAllCalls = 0;
  var permissionRequests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> schedule({required int id, required DateTime at}) async =>
      scheduled[id] = at;

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}
