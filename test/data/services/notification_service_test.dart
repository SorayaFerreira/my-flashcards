import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/notification_service.dart';

void main() {
  test('sem initialize(), schedule e requestPermission recusam', () {
    final service = NotificationService(
      plugin: FlutterLocalNotificationsPlugin(),
    );

    expect(
      () => service.schedule(id: 1, at: DateTime(2026, 10, 19, 10)),
      throwsA(isA<NotificationsUnavailableException>()),
    );
    expect(
      service.requestPermission,
      throwsA(isA<NotificationsUnavailableException>()),
    );
  });
}
