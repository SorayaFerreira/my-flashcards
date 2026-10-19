import 'dart:io';

import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'data/repositories/backup_repository.dart';
import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/repositories/media_repository.dart';
import 'data/repositories/reminder_repository.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/audio_recorder_service.dart';
import 'data/services/backup_file_service.dart';
import 'data/services/database_service.dart';
import 'data/services/image_picker_service.dart';
import 'data/services/media_file_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/zip_service.dart';
import 'utils/result.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({
    required this.decks,
    required this.cards,
    required this.backups,
    required this.media,
    required this.reminders,
  });

  final DeckRepository decks;
  final CardRepository cards;
  final BackupRepository backups;
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
    final temporary = await getTemporaryDirectory();
    final support = await getApplicationSupportDirectory();
    final notifications = NotificationService();
    // Without notifications the rest of the app still works.
    await guard(notifications.initialize);
    // By default the plugin only uses the Android photo picker on API 36+.
    final picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
    return AppDependencies(
      decks: DeckRepository(database: database, mediaFiles: mediaFiles),
      cards: CardRepository(database: database, mediaFiles: mediaFiles),
      backups: BackupRepository(
        database: database,
        mediaFiles: mediaFiles,
        zip: ZipService(),
        files: BackupFileService(),
        workDir: Directory(p.join(temporary.path, 'backup')),
        // Not in the cache: Android may clear it, and it can hold user data.
        rollbackRoot: Directory(p.join(support.path, 'backup_rollback')),
      ),
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
