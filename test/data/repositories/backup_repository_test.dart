import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/backup_repository.dart';
import 'package:my_flashcards/data/services/database_service.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:my_flashcards/data/services/zip_service.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';
import 'package:my_flashcards/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../helpers/result.dart';

/// Fails the second time it opens, which is the reopening during an import.
class _FailingReopenDatabase extends DatabaseService {
  _FailingReopenDatabase({required super.factory, required super.path});

  var opens = 0;

  @override
  Future<void> open() async {
    opens++;
    if (opens == 2) throw const FileSystemException('falha simulada');
    await super.open();
  }
}

void main() {
  late Directory root;
  late DatabaseService database;
  late MediaFileService mediaFiles;
  late FakeBackupFileService files;
  late BackupRepository repository;
  final zip = ZipService();

  Future<void> setUpWith(DatabaseService db) async {
    database = db;
    await database.open();
    repository = BackupRepository(
      database: database,
      mediaFiles: mediaFiles,
      zip: zip,
      files: files,
      workDir: Directory(p.join(root.path, 'backup')),
      rollbackRoot: Directory(p.join(root.path, 'support', 'backup_rollback')),
      now: () => DateTime(2026, 10, 12, 20, 15),
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('backup_test_');
    await Directory(p.join(root.path, 'db')).create();
    mediaFiles = MediaFileService(
      mediaDir: Directory(p.join(root.path, 'media')),
      draftDir: Directory(p.join(root.path, 'drafts')),
    );
    await mediaFiles.ensureDirectories();
    files = FakeBackupFileService();
    await setUpWith(
      DatabaseService(
        factory: databaseFactoryFfi,
        path: p.join(root.path, 'db', DatabaseService.fileName),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  Future<void> seedDeck(String name, {String? image}) async {
    final deckId = await database.db.insert('decks', {
      'name': name,
      'created_at': 0,
    });
    await database.db.insert('cards', {
      'deck_id': deckId,
      'front_text': 'frente',
      'front_image': image,
      'back_text': 'verso',
      'created_at': 0,
    });
    if (image != null) await mediaFiles.mediaFile(image).writeAsString('foto');
  }

  Future<List<String>> deckNames() async => [
    for (final row in await database.db.query('decks', orderBy: 'name'))
      row['name']! as String,
  ];

  /// Builds a zip by hand, for backups this app would never produce.
  Future<String> handMadeZip(Map<String, String> contents) async {
    final dir = await Directory(p.join(root.path, 'feito_a_mao')).create();
    final entries = <String, String>{};
    var i = 0;
    for (final MapEntry(key: name, value: content) in contents.entries) {
      final source = File(p.join(dir.path, 'arquivo_${i++}'));
      await source.writeAsString(content);
      entries[name] = source.path;
    }
    final zipPath = p.join(root.path, 'feito_a_mao.zip');
    await zip.createZip(zipPath, entries);
    return zipPath;
  }

  String manifestJson({String app = 'my_flashcards', int schemaVersion = 1}) =>
      jsonEncode(
        BackupManifest(
          app: app,
          formatVersion: 1,
          schemaVersion: schemaVersion,
          exportedAt: DateTime(2026),
          decks: 0,
          cards: 0,
        ).toJson(),
      );

  test('exporta um zip com manifesto, banco e mídias', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');

    final zipPath = okValue(await repository.exportBackup());

    expect(p.basename(zipPath), 'my-flashcards-backup-2026-10-12.zip');
    expect(
      await zip.listEntries(zipPath),
      containsAll(['manifest.json', 'flashcards.db', 'media/img_1.jpg']),
    );
    final manifest = okValue(await repository.prepareImport(zipPath));
    expect(manifest.decks, 1);
    expect(manifest.cards, 1);
    expect(manifest.exportedAt, DateTime(2026, 10, 12, 20, 15));
  });

  test('exporta mesmo sem nenhum deck', () async {
    final zipPath = okValue(await repository.exportBackup());

    expect(await File(zipPath).exists(), isTrue);
  });

  test('importar devolve exatamente os dados exportados', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');
    final zipPath = okValue(await repository.exportBackup());
    await database.db.delete('decks');
    await mediaFiles.mediaFile('img_1.jpg').delete();
    await seedDeck('Deck novo', image: 'img_2.jpg');

    okValue(await repository.prepareImport(zipPath));
    okValue(await repository.applyImport());

    expect(await deckNames(), ['Inglês']);
    expect(await mediaFiles.mediaFile('img_1.jpg').readAsString(), 'foto');
    expect(await mediaFiles.mediaFile('img_2.jpg').exists(), isFalse);
    expect(await database.db.query('cards'), hasLength(1));
  });

  test('recusa um arquivo que não é zip', () async {
    final notZip = File(p.join(root.path, 'foto.zip'));
    await notZip.writeAsString('não sou um zip');

    expect(
      await repository.prepareImport(notZip.path),
      isA<Error<BackupManifest>>(),
    );
  });

  test('recusa um zip que tenta escrever fora da pasta', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(),
      'flashcards.db': 'x',
      '../fora.txt': 'ataque',
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
    expect(
      await File(p.join(root.path, 'backup', 'fora.txt')).exists(),
      isFalse,
    );
    expect(await File(p.join(root.path, 'fora.txt')).exists(), isFalse);
  });

  test('recusa um zip de outro app', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(app: 'outro_app'),
      'flashcards.db': 'x',
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('recusa um backup de uma versão mais nova do app', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(schemaVersion: 99),
      'flashcards.db': 'x',
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('recusa um backup com banco corrompido', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(),
      'flashcards.db': 'não sou um banco',
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('falha no meio da troca devolve os dados originais', () async {
    await seedDeck('Backup', image: 'img_backup.jpg');
    final zipPath = okValue(await repository.exportBackup());
    await database.close();

    await setUpWith(
      _FailingReopenDatabase(
        factory: databaseFactoryFfi,
        path: p.join(root.path, 'db', DatabaseService.fileName),
      ),
    );
    await database.db.delete('decks');
    await seedDeck('Atual', image: 'img_atual.jpg');
    okValue(await repository.prepareImport(zipPath));

    expect(await repository.applyImport(), isA<Error<void>>());

    expect(await deckNames(), ['Atual']);
    expect(await mediaFiles.mediaFile('img_atual.jpg').readAsString(), 'foto');
  });

  test('cancelImport apaga a pasta extraída', () async {
    final zipPath = okValue(await repository.exportBackup());
    okValue(await repository.prepareImport(zipPath));

    await repository.cancelImport();

    expect(
      await Directory(p.join(root.path, 'backup', 'import')).exists(),
      isFalse,
    );
  });

  test('pickBackupFile copia o arquivo escolhido, ou devolve null', () async {
    expect(okValue(await repository.pickBackupFile()), isNull);

    final source = File(p.join(root.path, 'escolhido.zip'));
    await source.writeAsString('conteúdo');
    files.nextPick = source.path;

    final copy = okValue(await repository.pickBackupFile());
    expect(await File(copy!).readAsString(), 'conteúdo');
  });

  test('shareBackup entrega o zip ao menu de compartilhar', () async {
    okValue(await repository.shareBackup('/algum/backup.zip'));

    expect(files.shared, ['/algum/backup.zip']);
  });

  test('cleanOldExports apaga os zips antigos', () async {
    final zipPath = okValue(await repository.exportBackup());

    await repository.cleanOldExports();

    expect(await File(zipPath).exists(), isFalse);
  });

  Directory rollbackRoot() =>
      Directory(p.join(root.path, 'support', 'backup_rollback'));

  Future<File> plantOldRollback() async {
    final old = Directory(p.join(rollbackRoot().path, 'rollback-123'));
    await old.create(recursive: true);
    return File(p.join(old.path, 'flashcards.db')).writeAsString('meus dados');
  }

  List<String> rollbackFolders() => rollbackRoot().existsSync()
      ? [for (final e in rollbackRoot().listSync()) p.basename(e.path)]
      : [];

  test('um rollback antigo sobrevive a uma importação bem-sucedida', () async {
    await seedDeck('Inglês');
    final zipPath = okValue(await repository.exportBackup());
    final old = await plantOldRollback();

    okValue(await repository.prepareImport(zipPath));
    okValue(await repository.applyImport());

    expect(await old.readAsString(), 'meus dados');
    expect(rollbackFolders(), ['rollback-123']);
  });

  test('um rollback antigo sobrevive a uma importação que falha', () async {
    await seedDeck('Backup');
    final zipPath = okValue(await repository.exportBackup());
    await database.close();
    await setUpWith(
      _FailingReopenDatabase(
        factory: databaseFactoryFfi,
        path: p.join(root.path, 'db', DatabaseService.fileName),
      ),
    );
    final old = await plantOldRollback();
    okValue(await repository.prepareImport(zipPath));

    expect(await repository.applyImport(), isA<Error<void>>());

    expect(await old.readAsString(), 'meus dados');
    expect(rollbackFolders(), ['rollback-123']);
  });

  test('duas importações no mesmo instante não reutilizam a pasta', () async {
    await seedDeck('Inglês');
    final zipPath = okValue(await repository.exportBackup());
    final clash = Directory(
      p.join(
        rollbackRoot().path,
        'rollback-${DateTime(2026, 10, 12, 20, 15).millisecondsSinceEpoch}',
      ),
    );
    await clash.create(recursive: true);
    await File(p.join(clash.path, 'x')).writeAsString('dados');

    okValue(await repository.prepareImport(zipPath));
    okValue(await repository.applyImport());

    expect(await File(p.join(clash.path, 'x')).readAsString(), 'dados');
    expect(rollbackFolders(), [p.basename(clash.path)]);
  });

  test('cleanOldExports não toca na pasta de rollback', () async {
    final old = await plantOldRollback();
    await repository.exportBackup();

    await repository.cleanOldExports();

    expect(await old.exists(), isTrue);
  });

  test('recusa um backup cujo banco aponta para mídia fora da pasta', () async {
    for (final name in [
      '../fora.jpg',
      'a/b.jpg',
      r'a\b.jpg',
      '..',
      '.oculto',
    ]) {
      final dbPath = p.join(root.path, 'ruim.db');
      final bad = DatabaseService(factory: databaseFactoryFfi, path: dbPath);
      await bad.open();
      await bad.db.execute('PRAGMA user_version = 1');
      final deckId = await bad.db.insert('decks', {
        'name': 'x',
        'created_at': 0,
      });
      await bad.db.insert('cards', {
        'deck_id': deckId,
        'front_image': name,
        'created_at': 0,
      });
      await bad.close();
      final zipPath = p.join(root.path, 'ruim.zip');
      final manifest = File(p.join(root.path, 'manifest_ruim.json'))
        ..writeAsStringSync(manifestJson());
      await zip.createZip(zipPath, {
        'manifest.json': manifest.path,
        'flashcards.db': dbPath,
      });

      expect(
        await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>(),
        reason: name,
      );

      await File(dbPath).delete();
      await File(zipPath).delete();
    }
  });

  test('aceita um backup cujo banco usa nomes simples de mídia', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');
    final zipPath = okValue(await repository.exportBackup());

    okValue(await repository.prepareImport(zipPath));
  });
}
