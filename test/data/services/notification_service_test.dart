import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('com os canais da plataforma simulados', () {
    const notificationsChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const timezoneChannel = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> pluginCalls;
    late String zone;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      pluginCalls = [];
      zone = 'America/Sao_Paulo';
      messenger.setMockMethodCallHandler(timezoneChannel, (call) async => zone);
      messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
        pluginCalls.add(call);
        return call.method == 'initialize' ? true : null;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(timezoneChannel, null);
      messenger.setMockMethodCallHandler(notificationsChannel, null);
    });

    Future<NotificationService> initialized() async {
      final service = NotificationService();
      await service.initialize();
      return service;
    }

    List<MethodCall> scheduleCalls() =>
        pluginCalls.where((c) => c.method == 'zonedSchedule').toList();

    test('initialize usa o fuso do aparelho e libera o serviço', () async {
      final service = await initialized();

      expect(tz.local.name, 'America/Sao_Paulo');
      expect(pluginCalls.map((c) => c.method), contains('initialize'));
      await service.cancelAll();
      expect(pluginCalls.last.method, 'cancelAll');
    });

    test('horário que já passou não chega ao plugin', () async {
      final service = await initialized();

      await service.schedule(id: 1, at: DateTime(2020, 1, 1, 10));

      expect(scheduleCalls(), isEmpty);
    });

    test('horário futuro chega ao plugin com o id', () async {
      final service = await initialized();
      final at = DateTime.now().add(const Duration(days: 2));

      await service.schedule(id: 7, at: at);

      expect(scheduleCalls(), hasLength(1));
      expect(scheduleCalls().single.arguments['id'], 7);
    });

    test('refreshTimeZone segue o fuso novo do aparelho', () async {
      final service = await initialized();
      zone = 'Asia/Tokyo';

      await service.refreshTimeZone();

      expect(tz.local.name, 'Asia/Tokyo');
    });

    test('refreshTimeZone que falha mantém o fuso anterior', () async {
      final service = await initialized();
      zone = 'Nao/Existe';

      await service.refreshTimeZone();

      expect(tz.local.name, 'America/Sao_Paulo');
    });
  });
}
