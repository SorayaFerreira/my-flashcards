import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/repositories/media_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/image_picker_service.dart';
import 'data/services/media_file_service.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({
    required this.decks,
    required this.cards,
    required this.media,
  });

  final DeckRepository decks;
  final CardRepository cards;
  final MediaRepository media;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    final mediaFiles = await MediaFileService.create();
    // By default the plugin only uses the Android photo picker on API 36+.
    final picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
    return AppDependencies(
      decks: DeckRepository(database: database, mediaFiles: mediaFiles),
      cards: CardRepository(database: database, mediaFiles: mediaFiles),
      media: MediaRepository(
        files: mediaFiles,
        imagePicker: ImagePickerService(),
      ),
    );
  }
}
