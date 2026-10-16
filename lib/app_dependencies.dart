import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/repositories/card_repository.dart';
import 'data/repositories/deck_repository.dart';
import 'data/services/database_service.dart';

/// The repositories shared by the whole app, created once at startup.
class AppDependencies {
  AppDependencies({required this.decks, required this.cards});

  final DeckRepository decks;
  final CardRepository cards;

  static Future<AppDependencies> create() async {
    final factory = databaseFactorySqflitePlugin;
    final database = DatabaseService(
      factory: factory,
      path: p.join(await factory.getDatabasesPath(), DatabaseService.fileName),
    );
    await database.open();
    return AppDependencies(
      decks: DeckRepository(database: database),
      cards: CardRepository(database: database),
    );
  }
}
