# Etapa 6: lembrete. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** um lembrete diário opcional, com uma notificação por dia num horário sorteado entre 9h e 20h, ligado e desligado numa tela de Configurações nova.

**Arquitetura:**
- **Sorteio dos horários:** a função pura `ReminderPlan.plan`, em `lib/domain/reminder_plan.dart`, decide quais dias agendar e em que horário.
- **`NotificationService`:** embrulha o `flutter_local_notifications` e o fuso horário.
- **`ReminderRepository`:**
  - guarda as chaves `reminder_*` na tabela `settings`;
  - agenda os próximos 30 dias;
  - completa a agenda a cada abertura do app.
- **Tela de configurações:** `SettingsViewModel` e `SettingsScreen`, abertas pela ⚙ da lista de decks.

**Tecnologias:** `flutter_local_notifications` 22.3, `timezone` 0.11 e `flutter_timezone` 5.1.

**Spec:** [docs/design.md](../design.md), parte 3 ("Lembrete diário" e "Permissões") e parte 2 ("5. Configurações"). Requisito RF-19.

**Branch:** `etapa-6-lembrete`

## Restrições globais

- **Regra:** uma notificação por dia, num minuto sorteado em **[9:00, 20:00)**. Ela pode chegar alguns minutos atrasada (`AndroidScheduleMode.inexactAllowWhileIdle`). **Não** se usa alarme exato nem a permissão `SCHEDULE_EXACT_ALARM`.
- **Agendamento:** cada dia é uma notificação avulsa, com id `AAAAMMDD`. Sempre ficam agendados os dias até hoje + 29.
- **Hoje** só entra se ainda houver pelo menos 30 minutos antes das 20h. Nesse caso, o horário é sorteado entre "agora + 30 min" e 20h.
- **Sem repetir dias:** um dia que já tem horário nunca é sorteado de novo. A chave `reminder_scheduled_until` guarda o último dia agendado.
- **Chaves em `settings`:** `reminder_enabled` (`"1"`/`"0"`, padrão `"0"`) e `reminder_scheduled_until` (`"AAAA-MM-DD"`).
- **Textos:**
  - notificação: título *"Hora de revisar!"* e corpo *"Seus flashcards estão esperando por você."*;
  - canal `lembrete_diario`, chamado "Lembrete diário";
  - na tela, o interruptor "Lembrete diário" tem o subtítulo "Um por dia, em horário aleatório entre 9h e 20h".
- **Permissão:** `POST_NOTIFICATIONS` é pedida ao ligar o lembrete. Se for negada, o interruptor volta para desligado e aparece *"Sem permissão para notificações. Ative em Configurações › Apps › My Flashcards › Notificações."*
- **Abrir o app** completa a agenda. Uma falha nisso não impede o app de abrir.
- `flutter analyze` sem problemas e `flutter test` passando ao fim de cada tarefa.

> **Recomendação da revisão da etapa 5 (2026-10-18):** tocar na notificação não deve reiniciar a navegação (por exemplo com `popUntil`). Isso fecharia um editor aberto sem passar pelo `discard()`, perdendo as alterações sem perguntar e deixando a gravação em andamento em `editor_tmp/`. Abrir o app normalmente basta.

## Pontos de atenção na revisão

1. **Ligar o lembrete à noite (depois das 19:30).** Nenhuma notificação para hoje; a agenda começa amanhã. Testado na tarefa 1.
2. **Abrir o app várias vezes no mesmo dia.** Nunca chegam duas notificações no mesmo dia, e os dias já agendados não são sorteados de novo. Testado na tarefa 3.
3. **Permissão de notificações negada.** O interruptor volta para desligado, com a mensagem. Testado nas tarefas 4 e 5.
4. **Mais de 30 dias sem abrir o app.** Ao abrir, a agenda recomeça, incluindo hoje se ainda der tempo. Testado na tarefa 1.
5. **Virada de mês e de ano.** Os ids e as datas continuam certos (por exemplo, 20261231 → 20270101). Testado na tarefa 1.

---

### Tarefa 1: `ReminderPlan`, o sorteio dos horários

**Arquivos:**
- Criar: `lib/utils/dates.dart`
- Criar: `lib/domain/reminder_plan.dart`
- Testar: `test/domain/reminder_plan_test.dart`

**Interfaces:**
- Produz:
  - `class PlannedReminder`, com o construtor `const PlannedReminder({required int id, required DateTime at})`, e `==`;
  - `abstract final class ReminderPlan`, com:
    - as constantes `firstMinute = 540`, `lastMinute = 1200`, `days = 30` e `minimumLead = Duration(minutes: 30)`;
    - o método `static List<PlannedReminder> plan({required DateTime now, required DateTime? scheduledUntil, required Random random})`;
  - em `lib/utils/dates.dart`, usadas também pelo backup na etapa 7: `DateTime dateOnly(DateTime time)`, `DateTime addDays(DateTime day, int days)`, `String formatDate(DateTime day)` (`AAAA-MM-DD`) e `DateTime parseDate(String text)`.

- [ ] **Passo 1: criar o branch e adicionar os pacotes**

```bash
git switch main && git switch -c etapa-6-lembrete
flutter pub add flutter_local_notifications timezone flutter_timezone
```

- [ ] **Passo 2: escrever o teste**

`test/domain/reminder_plan_test.dart`:
```dart
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

    expect(reminders.map((r) => minuteOfDay(r.at)).toSet().length,
        greaterThan(10));
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
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/domain/reminder_plan_test.dart
```

Esperado: FALHA de compilação (`reminder_plan.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/utils/dates.dart`:
```dart
DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// `AAAA-MM-DD`, as stored in settings and used in backup file names.
String formatDate(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

DateTime parseDate(String text) => DateTime.parse(text);
```

`lib/domain/reminder_plan.dart`:
```dart
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
      start = _earliestMinuteToday(now) < lastMinute ? today : addDays(today, 1);
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
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/domain/reminder_plan_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add pubspec.yaml pubspec.lock lib/utils/dates.dart lib/domain/reminder_plan.dart test/domain/reminder_plan_test.dart
git commit -m "feat: sorteia um horário por dia para os lembretes"
```

---

### Tarefa 2: configuração Android das notificações e `NotificationService`

**Arquivos:**
- Modificar: `android/app/build.gradle.kts`
- Modificar: `android/app/src/main/AndroidManifest.xml`
- Criar: `android/app/src/main/res/drawable/ic_notification.xml`
- Criar: `android/app/src/main/res/raw/keep.xml`
- Criar: `lib/data/services/notification_service.dart`

**Interfaces:**
- Produz: `class NotificationService`, com:
  - o construtor `NotificationService({FlutterLocalNotificationsPlugin? plugin})`;
  - o método `Future<void> initialize()`, que configura o fuso horário e o plugin;
  - o método `Future<bool> requestPermission()`;
  - o método `Future<void> schedule({required int id, required DateTime at})`, em que `at` é um horário local;
  - o método `Future<void> cancelAll()`.

  Este service só embrulha o plugin. Ele é conferido no celular (tarefa 6); nos testes automáticos, entra no lugar dele o falso da tarefa 3.

- [ ] **Passo 1: ligar o desugaring no Gradle**

Em `android/app/build.gradle.kts`, dentro de `compileOptions { ... }`, acrescente a primeira linha abaixo:
```kotlin
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
```

E acrescente ao **fim** do arquivo:
```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Passo 2: declarar o boot e os receivers no manifesto**

Em `android/app/src/main/AndroidManifest.xml`, logo depois da abertura `<manifest ...>`, acrescente:
```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

E, dentro de `<application ...>`, antes de fechar `</application>`, acrescente:
```xml
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

- [ ] **Passo 3: criar o ícone pequeno da notificação**

É a silhueta do "F" do logo, só com os dois traços principais e mais grossos, para ficar legível em 24 dp.

`android/app/src/main/res/drawable/ic_notification.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="512"
    android:viewportHeight="512">
    <path
        android:pathData="M134 458C140 338 138 187 136 62C208 67 283 64 362 63"
        android:strokeColor="#FFFFFFFF"
        android:strokeWidth="48"
        android:strokeLineCap="round"
        android:strokeLineJoin="round" />
    <path
        android:pathData="M138 244C183 260 226 260 275 250"
        android:strokeColor="#FFFFFFFF"
        android:strokeWidth="48"
        android:strokeLineCap="round" />
</vector>
```

`android/app/src/main/res/raw/keep.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
```

> O `keep.xml` impede que o R8 apague o ícone no build de release. Sem ele, a notificação pode falhar em silêncio.

- [ ] **Passo 4: implementar o service**

`lib/data/services/notification_service.dart`:
```dart
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
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission() ??
      false;

  /// Schedules a notification at the local time [at]. It may arrive a few
  /// minutes late, which spares the app the exact-alarm permission.
  Future<void> schedule({required int id, required DateTime at}) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime(
            tz.local, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Hora de revisar!',
        body: 'Seus flashcards estão esperando por você.',
      );

  Future<void> cancelAll() => _plugin.cancelAll();
}
```

- [ ] **Passo 5: compilar o APK e rodar a análise**

```bash
flutter analyze && flutter build apk --debug
```

Esperado: `No issues found!` e `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. Se o build reclamar de desugaring, confira o passo 1.

- [ ] **Passo 6: commit**

```bash
git add android lib/data/services/notification_service.dart
git commit -m "feat: configura notificações agendadas no Android"
```

---

### Tarefa 3: `ReminderRepository`

**Arquivos:**
- Criar: `lib/data/repositories/reminder_repository.dart`
- Criar: `test/fakes/fake_notification_service.dart`
- Testar: `test/data/repositories/reminder_repository_test.dart`

**Interfaces:**
- Consome: `NotificationService` (tarefa 2), `ReminderPlan` e `formatDate`/`parseDate` de `lib/utils/dates.dart` (tarefa 1), e `DatabaseService`.
- Produz:
  - `class ReminderRepository`, com:
    - o construtor `ReminderRepository({required DatabaseService database, required NotificationService notifications, Random? random, DateTime Function()? now})`;
    - as constantes `enabledKey` e `scheduledUntilKey`;
    - os métodos:

      | Método | O que faz |
      |---|---|
      | `Future<Result<bool>> isEnabled()` | Diz se o lembrete está ligado |
      | `Future<Result<bool>> enable()` | Pede a permissão e agenda. Devolve `Ok(false)` se a permissão for negada |
      | `Future<Result<void>> disable()` | Cancela tudo e desliga |
      | `Future<Result<void>> topUp()` | Completa a agenda, se o lembrete estiver ligado |
      | `Future<Result<void>> resetAfterImport()` | Recomeça a agenda depois de importar um backup |

  - Nos testes: `FakeNotificationService`, com `bool allowed`, `Map<int, DateTime> scheduled`, `int cancelAllCalls` e `int permissionRequests`.

- [ ] **Passo 1: escrever o service falso**

`test/fakes/fake_notification_service.dart`:
```dart
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
```

- [ ] **Passo 2: escrever o teste**

`test/data/repositories/reminder_repository_test.dart`:
```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/reminder_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';

import '../../fakes/fake_notification_service.dart';
import '../../helpers/result.dart';
import '../../helpers/test_database.dart';

void main() {
  late DatabaseService database;
  late FakeNotificationService notifications;
  late ReminderRepository repository;
  late DateTime now;

  setUp(() async {
    database = await openTestDatabase();
    notifications = FakeNotificationService();
    now = DateTime(2026, 10, 12, 10, 0);
    repository = ReminderRepository(
      database: database,
      notifications: notifications,
      random: Random(1),
      now: () => now,
    );
  });
  tearDown(() => database.close());

  Future<String?> setting(String key) async {
    final rows = await database.db
        .query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  test('começa desligado', () async {
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('ligar pede permissão e agenda 30 dias', () async {
    expect(okValue(await repository.enable()), isTrue);

    expect(notifications.permissionRequests, 1);
    expect(notifications.scheduled, hasLength(30));
    expect(notifications.scheduled.keys, contains(20261012));
    expect(okValue(await repository.isEnabled()), isTrue);
    expect(await setting(ReminderRepository.scheduledUntilKey), '2026-11-10');
  });

  test('permissão negada não liga nem agenda', () async {
    notifications.allowed = false;

    expect(okValue(await repository.enable()), isFalse);

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('abrir o app de novo no mesmo dia não sorteia nada', () async {
    await repository.enable();
    final before = Map.of(notifications.scheduled);

    okValue(await repository.topUp());
    okValue(await repository.topUp());

    expect(notifications.scheduled, before);
  });

  test('abrir no dia seguinte agenda só o dia novo do fim', () async {
    await repository.enable();
    final before = Map.of(notifications.scheduled);
    now = now.add(const Duration(days: 1));

    okValue(await repository.topUp());

    expect(notifications.scheduled.length, before.length + 1);
    expect(notifications.scheduled[20261111], isNotNull);
    for (final MapEntry(:key, :value) in before.entries) {
      expect(notifications.scheduled[key], value);
    }
  });

  test('topUp com o lembrete desligado não faz nada', () async {
    okValue(await repository.topUp());

    expect(notifications.scheduled, isEmpty);
  });

  test('desligar cancela tudo e esquece a agenda', () async {
    await repository.enable();

    okValue(await repository.disable());

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
    expect(await setting(ReminderRepository.scheduledUntilKey), isNull);
  });

  test('depois de importar um backup ligado, recomeça a agenda do zero',
      () async {
    await database.db.insert('settings', {
      'key': ReminderRepository.enabledKey,
      'value': '1',
    });
    await database.db.insert('settings', {
      'key': ReminderRepository.scheduledUntilKey,
      'value': '2026-12-31',
    });

    okValue(await repository.resetAfterImport());

    expect(notifications.cancelAllCalls, 1);
    expect(notifications.scheduled, hasLength(30));
    expect(await setting(ReminderRepository.scheduledUntilKey), '2026-11-10');
  });

  test('importar com o lembrete ligado, mas sem permissão, desliga',
      () async {
    await database.db.insert('settings', {
      'key': ReminderRepository.enabledKey,
      'value': '1',
    });
    notifications.allowed = false;

    okValue(await repository.resetAfterImport());

    expect(notifications.scheduled, isEmpty);
    expect(okValue(await repository.isEnabled()), isFalse);
  });

  test('importar um backup desligado só cancela', () async {
    okValue(await repository.resetAfterImport());

    expect(notifications.cancelAllCalls, 1);
    expect(notifications.permissionRequests, 0);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/data/repositories/reminder_repository_test.dart
```

Esperado: FALHA de compilação (`reminder_repository.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/data/repositories/reminder_repository.dart`:
```dart
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../domain/reminder_plan.dart';
import '../../utils/dates.dart';
import '../../utils/result.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ReminderRepository {
  ReminderRepository({
    required DatabaseService database,
    required NotificationService notifications,
    Random? random,
    DateTime Function()? now,
  })  : _database = database,
        _notifications = notifications,
        _random = random ?? Random(),
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
  /// the app opens.
  Future<Result<void>> topUp() => guard(() async {
        if (!await _isEnabled()) return;
        final until = await _read(scheduledUntilKey);
        await _schedule(scheduledUntil: until == null ? null : parseDate(until));
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
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/data/repositories/reminder_repository_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/data/repositories/reminder_repository.dart test/fakes/fake_notification_service.dart test/data/repositories/reminder_repository_test.dart
git commit -m "feat: cria o ReminderRepository que agenda e completa os lembretes"
```

---

### Tarefa 4: `SettingsViewModel`

**Arquivos:**
- Criar: `lib/ui/settings/view_models/settings_view_model.dart`
- Criar: `test/fakes/fake_reminder_repository.dart`
- Testar: `test/ui/settings/settings_view_model_test.dart`

**Interfaces:**
- Consome: `ReminderRepository.isEnabled`, `enable` e `disable`.
- Produz:
  - `class SettingsViewModel extends ChangeNotifier`, com:
    - o construtor `SettingsViewModel({required ReminderRepository reminderRepository})`;
    - os getters `bool reminderEnabled`, `bool isBusy` e `String? message`;
    - os métodos `Future<void> load()` e `Future<bool> setReminderEnabled(bool enabled)`;
    - as constantes `permissionDeniedMessage` e `reminderErrorMessage`.
    - **A etapa 7 acrescenta o backup.**
  - Nos testes: `FakeReminderRepository`, com `bool enabled`, `bool permissionAllowed`, `Exception? failWith`, `int topUpCalls` e `int resetCalls`.

- [ ] **Passo 1: escrever o repositório falso**

`test/fakes/fake_reminder_repository.dart`:
```dart
import 'package:my_flashcards/data/repositories/reminder_repository.dart';
import 'package:my_flashcards/utils/result.dart';

class FakeReminderRepository implements ReminderRepository {
  bool enabled = false;
  bool permissionAllowed = true;
  Exception? failWith;
  var topUpCalls = 0;
  var resetCalls = 0;

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    return Result.ok(compute());
  }

  @override
  Future<Result<bool>> isEnabled() => _answer(() => enabled);

  @override
  Future<Result<bool>> enable() => _answer(() {
        if (!permissionAllowed) return false;
        enabled = true;
        return true;
      });

  @override
  Future<Result<void>> disable() => _answer(() => enabled = false);

  @override
  Future<Result<void>> topUp() => _answer(() => topUpCalls++);

  @override
  Future<Result<void>> resetAfterImport() => _answer(() => resetCalls++);
}
```

- [ ] **Passo 2: escrever o teste**

`test/ui/settings/settings_view_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/settings/view_models/settings_view_model.dart';

import '../../fakes/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository reminders;
  late SettingsViewModel viewModel;

  setUp(() {
    reminders = FakeReminderRepository();
    viewModel = SettingsViewModel(reminderRepository: reminders);
  });

  test('load lê se o lembrete está ligado', () async {
    reminders.enabled = true;

    await viewModel.load();

    expect(viewModel.reminderEnabled, isTrue);
  });

  test('ligar o lembrete', () async {
    expect(await viewModel.setReminderEnabled(true), isTrue);

    expect(viewModel.reminderEnabled, isTrue);
    expect(viewModel.message, isNull);
    expect(viewModel.isBusy, isFalse);
  });

  test('permissão negada mantém desligado e explica o que fazer', () async {
    reminders.permissionAllowed = false;

    expect(await viewModel.setReminderEnabled(true), isFalse);

    expect(viewModel.reminderEnabled, isFalse);
    expect(viewModel.message, SettingsViewModel.permissionDeniedMessage);
  });

  test('desligar o lembrete', () async {
    reminders.enabled = true;
    await viewModel.load();

    expect(await viewModel.setReminderEnabled(false), isTrue);

    expect(viewModel.reminderEnabled, isFalse);
  });

  test('falha mantém o estado anterior e mostra a mensagem', () async {
    reminders.failWith = Exception('disco');

    expect(await viewModel.setReminderEnabled(true), isFalse);

    expect(viewModel.reminderEnabled, isFalse);
    expect(viewModel.message, SettingsViewModel.reminderErrorMessage);
  });
}
```

- [ ] **Passo 3: rodar e ver falhar**

```bash
flutter test test/ui/settings/settings_view_model_test.dart
```

Esperado: FALHA de compilação (`settings_view_model.dart` não existe).

- [ ] **Passo 4: implementar**

`lib/ui/settings/view_models/settings_view_model.dart`:
```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/reminder_repository.dart';
import '../../../utils/result.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required ReminderRepository reminderRepository})
      : _reminderRepository = reminderRepository;

  static const permissionDeniedMessage =
      'Sem permissão para notificações. Ative em Configurações › Apps › '
      'My Flashcards › Notificações.';
  static const reminderErrorMessage = 'Não foi possível mudar o lembrete.';

  final ReminderRepository _reminderRepository;

  bool _reminderEnabled = false;
  bool _isBusy = false;
  String? _message;

  bool get reminderEnabled => _reminderEnabled;
  bool get isBusy => _isBusy;

  /// The message for the last action that failed.
  String? get message => _message;

  Future<void> load() async {
    if (await _reminderRepository.isEnabled() case Ok(:final value)) {
      _reminderEnabled = value;
    }
    notifyListeners();
  }

  Future<bool> setReminderEnabled(bool enabled) async {
    _isBusy = true;
    _message = null;
    notifyListeners();

    if (enabled) {
      switch (await _reminderRepository.enable()) {
        case Ok(value: true):
          _reminderEnabled = true;
        case Ok():
          _message = permissionDeniedMessage;
        case Error():
          _message = reminderErrorMessage;
      }
    } else {
      switch (await _reminderRepository.disable()) {
        case Ok():
          _reminderEnabled = false;
        case Error():
          _message = reminderErrorMessage;
      }
    }

    _isBusy = false;
    notifyListeners();
    return _message == null;
  }
}
```

- [ ] **Passo 5: rodar e ver passar**

```bash
flutter test test/ui/settings/settings_view_model_test.dart
```

Esperado: `All tests passed!`

- [ ] **Passo 6: commit**

```bash
git add lib/ui/settings/view_models test/fakes/fake_reminder_repository.dart test/ui/settings/settings_view_model_test.dart
git commit -m "feat: cria o SettingsViewModel para ligar e desligar o lembrete"
```

---

### Tarefa 5: tela de configurações, ⚙ na lista de decks e ligação no app

**Arquivos:**
- Criar: `lib/app_version.dart`
- Criar: `lib/ui/settings/widgets/settings_screen.dart`
- Modificar:
  - `lib/ui/deck_list/widgets/deck_list_screen.dart`;
  - `lib/routes.dart`, `lib/app.dart`, `lib/app_dependencies.dart` e `lib/main.dart`.
- Testar:
  - criar `test/app_version_test.dart` e `test/ui/settings/settings_screen_test.dart`;
  - modificar `test/ui/deck_list/deck_list_screen_test.dart` e `test/app_test.dart`.

**Interfaces:**
- Consome: `SettingsViewModel` (tarefa 4), `ReminderRepository` e `NotificationService`.
- Produz:
  - a constante `const appVersion = '0.1.0'`, que acompanha o `version:` do `pubspec.yaml`;
  - `class SettingsScreen extends StatefulWidget`, com o construtor `const SettingsScreen({super.key, required SettingsViewModel viewModel})`;
  - em `DeckListScreen`, o parâmetro novo `required Future<void> Function() onOpenSettings`. Quando ele termina, a lista recarrega;
  - em `AppRoutes`, o método `Route<void> settings()`;
  - em `AppDependencies`, o campo novo `final ReminderRepository reminders`.

- [ ] **Passo 1: escrever os testes**

`test/app_version_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app_version.dart';

void main() {
  test('appVersion é a mesma do pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);

    expect(appVersion, version);
  });
}
```

`test/ui/settings/settings_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app_version.dart';
import 'package:my_flashcards/ui/settings/view_models/settings_view_model.dart';
import 'package:my_flashcards/ui/settings/widgets/settings_screen.dart';

import '../../fakes/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository reminders;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        viewModel: SettingsViewModel(reminderRepository: reminders),
      ),
    ));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  setUp(() => reminders = FakeReminderRepository());

  testWidgets('mostra o lembrete desligado, a explicação e a versão',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Lembrete diário'), findsOneWidget);
    expect(
      find.text('Um por dia, em horário aleatório entre 9h e 20h'),
      findsOneWidget,
    );
    expect(find.text('Versão $appVersion'), findsOneWidget);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('tocar no interruptor liga o lembrete', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lembrete diário'));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isTrue);
    expect(reminders.enabled, isTrue);
  });

  testWidgets('permissão negada volta para desligado com a mensagem',
      (tester) async {
    reminders.permissionAllowed = false;
    await pumpScreen(tester);

    await tester.tap(find.text('Lembrete diário'));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(find.text(SettingsViewModel.permissionDeniedMessage),
        findsOneWidget);
  });
}
```

Em `test/ui/deck_list/deck_list_screen_test.dart`:

1. Troque `pumpScreen` por:
```dart
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDeckRepository repository, {
    Future<void> Function(Deck deck)? onOpenDeck,
    Future<void> Function()? onOpenSettings,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: DeckListScreen(
        viewModel: DeckListViewModel(deckRepository: repository),
        onOpenDeck: onOpenDeck ?? (_) async {},
        onOpenSettings: onOpenSettings ?? () async {},
      ),
    ));
    await tester.pumpAndSettle();
  }
```

2. Acrescente ao fim do `main()`:
```dart
  testWidgets('⚙ abre as configurações e recarrega ao voltar',
      (tester) async {
    final repository = FakeDeckRepository();
    var opened = 0;
    await pumpScreen(
      tester,
      repository,
      onOpenSettings: () async {
        opened++;
        await repository.createDeck('Vindo do backup');
      },
    );

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Vindo do backup'), findsOneWidget);
  });
```

Em `test/app_test.dart`:

1. Acrescente o import `import 'fakes/fake_reminder_repository.dart';`.

2. No helper `dependencies`, acrescente `reminders: FakeReminderRepository(),` ao `AppDependencies(...)`.

3. Acrescente ao fim do `main()`:
```dart
  testWidgets('⚙ abre as configurações', (tester) async {
    await tester.pumpWidget(App(dependencies: dependencies()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();

    expect(find.text('Lembrete diário'), findsOneWidget);
  });
```

- [ ] **Passo 2: rodar e ver falhar**

```bash
flutter test
```

Esperado: FALHA de compilação (`app_version.dart`, `SettingsScreen` e `onOpenSettings` não existem).

- [ ] **Passo 3: criar a versão e a tela de configurações**

`lib/app_version.dart`:
```dart
/// Keep in sync with `version:` in pubspec.yaml; a test checks it.
const appVersion = '0.1.0';
```

`lib/ui/settings/widgets/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../app_version.dart';
import '../view_models/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage() {
    final message = _viewModel.message;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setReminder(bool enabled) async {
    if (!await _viewModel.setReminderEnabled(enabled)) _showMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('LEMBRETE'),
            SwitchListTile(
              title: const Text('Lembrete diário'),
              subtitle:
                  const Text('Um por dia, em horário aleatório entre 9h e 20h'),
              value: _viewModel.reminderEnabled,
              onChanged: _viewModel.isBusy ? null : _setReminder,
            ),
            const Divider(),
            const ListTile(title: Text('Versão $appVersion')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
```

- [ ] **Passo 4: acrescentar a ⚙ à lista de decks**

Em `lib/ui/deck_list/widgets/deck_list_screen.dart`:

1. Troque o construtor e os campos de `DeckListScreen` por:
```dart
  const DeckListScreen({
    super.key,
    required this.viewModel,
    required this.onOpenDeck,
    required this.onOpenSettings,
  });

  final DeckListViewModel viewModel;

  /// Opens a deck. The list reloads when it completes, because the user may
  /// have added or removed cards meanwhile.
  final Future<void> Function(Deck deck) onOpenDeck;

  /// Opens the settings. The list reloads afterwards, since importing a
  /// backup there replaces every deck.
  final Future<void> Function() onOpenSettings;
```

2. Em `_DeckListScreenState`, acrescente:
```dart
  Future<void> _openSettings() async {
    await widget.onOpenSettings();
    if (mounted) await _viewModel.load();
  }
```

3. Troque a `AppBar` por:
```dart
      appBar: AppBar(
        title: const Text('My Flashcards'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
```

- [ ] **Passo 5: rota, `App`, dependências e `main`**

Em `lib/routes.dart`, acrescente os imports:
```dart
import 'ui/settings/view_models/settings_view_model.dart';
import 'ui/settings/widgets/settings_screen.dart';
```
E o método:
```dart
  Route<void> settings() {
    final viewModel =
        SettingsViewModel(reminderRepository: _dependencies.reminders);
    return MaterialPageRoute(
      builder: (_) => SettingsScreen(viewModel: viewModel),
    );
  }
```

Em `lib/app.dart`, no `DeckListScreen` dentro do `Builder`, acrescente:
```dart
          onOpenSettings: () => Navigator.of(context).push(_routes.settings()),
```

`lib/app_dependencies.dart` (substitui o arquivo inteiro):
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/repositories/media_repository.dart';
import 'data/repositories/reminder_repository.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/audio_recorder_service.dart';
import 'data/services/database_service.dart';
import 'data/services/image_picker_service.dart';
import 'data/services/media_file_service.dart';
import 'data/services/notification_service.dart';
import 'utils/result.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({
    required this.decks,
    required this.cards,
    required this.media,
    required this.reminders,
  });

  final DeckRepository decks;
  final CardRepository cards;
  final MediaRepository media;
  final ReminderRepository reminders;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    final mediaFiles = await MediaFileService.create();
    final notifications = NotificationService();
    // Without notifications the rest of the app still works.
    await guard(notifications.initialize);
    return AppDependencies(
      decks: DeckRepository(database: database, mediaFiles: mediaFiles),
      cards: CardRepository(database: database, mediaFiles: mediaFiles),
      media: MediaRepository(
        files: mediaFiles,
        imagePicker: ImagePickerService(),
        recorder: AudioRecorderService(),
        player: AudioPlayerService(),
      ),
      reminders: ReminderRepository(
        database: database,
        notifications: notifications,
      ),
    );
  }
}
```

`lib/main.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  await dependencies.media.clearDrafts();
  await dependencies.reminders.topUp();
  runApp(App(dependencies: dependencies));
}
```

- [ ] **Passo 6: rodar todos os testes e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 7: commit**

```bash
git add lib test
git commit -m "feat: tela de configurações com o lembrete diário"
```

---

### Tarefa 6: conferir no celular e fechar a etapa

**Arquivos:** nenhum.

- [ ] **Passo 1: rodar no celular**

```bash
flutter run
```

- [ ] **Passo 2: checklist manual**

- [ ] A **⚙** na lista de decks abre "Configurações", com o lembrete desligado e "Versão 0.1.0"
- [ ] Ligar o lembrete mostra o pedido de permissão de notificações do Android
- [ ] Negar a permissão faz o interruptor voltar para desligado, com a mensagem
- [ ] Ligar de novo e permitir deixa o interruptor ligado
- [ ] Os alarmes aparecem agendados, com horários diferentes entre 9h e 20h:
  ```bash
  adb shell dumpsys alarm | grep -A2 com.sorayaferreira.myflashcards | head -40
  ```
- [ ] **A notificação aparece de verdade:**
  1. pegue no `dumpsys` o horário do próximo alarme;
  2. em **Configurações › Sistema › Data e hora**, desligue "Definir automaticamente" e adiante o relógio para 1 minuto depois desse horário;
  3. espere a notificação *"Hora de revisar!"* com o ícone do "F" (pode levar alguns minutos);
  4. **religue a data e hora automáticas.**
- [ ] Tocar na notificação abre o app na lista de decks (com o app já aberto, ela só traz o app para a frente)
- [ ] Reiniciar o celular mantém os alarmes (confira com o `dumpsys`)
- [ ] Desligar o lembrete faz os alarmes do app sumirem do `dumpsys`
- [ ] Abrir e fechar o app várias vezes no mesmo dia não muda os horários já agendados

- [ ] **Passo 3: juntar ao `main`**

```bash
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-6-lembrete -m "Etapa 6: lembrete" && git branch -d etapa-6-lembrete
```
