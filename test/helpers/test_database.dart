import 'package:my_flashcards/data/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, empty in-memory database with the app schema.
Future<DatabaseService> openTestDatabase() async {
  sqfliteFfiInit();
  final database = DatabaseService(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
  await database.open();
  return database;
}
