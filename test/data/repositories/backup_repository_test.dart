import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  Future<void> setUpWith(
    DatabaseService db, {
    Future<void> Function(String, String)? move,
  }) async {
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
      move: move,
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

  String manifestJson({
    String app = 'my_flashcards',
    int formatVersion = 1,
    int schemaVersion = 1,
  }) => jsonEncode(
    BackupManifest(
      app: app,
      formatVersion: formatVersion,
      schemaVersion: schemaVersion,
      exportedAt: DateTime(2026),
      decks: 0,
      cards: 0,
    ).toJson(),
  );

  var builtCount = 0;

  /// A real, valid database file with one deck and one card.
  Future<String> makeDb([Map<String, Object?> card = const {}]) async {
    final path = p.join(root.path, 'valido_${builtCount++}.db');
    final built = DatabaseService(factory: databaseFactoryFfi, path: path);
    await built.open();
    await built.db.execute('PRAGMA user_version = 1');
    final deckId = await built.db.insert('decks', {
      'name': 'x',
      'created_at': 0,
    });
    await built.db.insert('cards', {
      'deck_id': deckId,
      'created_at': 0,
      ...card,
    });
    await built.close();
    return path;
  }

  /// A zip whose only possible defect is what the test changes: it has a
  /// valid database and manifest unless told otherwise.
  Future<String> zipOf({
    String? manifest,
    Map<String, Object?> card = const {},
    Map<String, String> extra = const {},
  }) async {
    final id = builtCount++;
    final manifestFile = File(p.join(root.path, 'manifesto_$id.json'));
    await manifestFile.writeAsString(manifest ?? manifestJson());
    final zipPath = p.join(root.path, 'montado_$id.zip');
    final entries = <String, String>{};
    for (final MapEntry(key: name, value: content) in extra.entries) {
      final source = File(p.join(root.path, 'extra_${id}_${entries.length}'));
      await source.writeAsString(content);
      entries[name] = source.path;
    }
    await zip.createZip(zipPath, {
      'manifest.json': manifestFile.path,
      'flashcards.db': await makeDb(card),
      ...entries,
    });
    return zipPath;
  }

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

  Future<void> expectOriginalsIntact() async {
    expect(await deckNames(), ['Atual']);
    expect(await mediaFiles.mediaFile('img_atual.jpg').readAsString(), 'foto');
    expect(await mediaFiles.mediaFile('img_backup.jpg').exists(), isFalse);
    expect(await mediaFiles.mediaDir.exists(), isTrue);
    await database.db.insert('decks', {'name': 'Novo', 'created_at': 0});
    expect(await deckNames(), ['Atual', 'Novo']);
    expect(rollbackFolders(), isEmpty);
  }

  Future<void> Function(String, String) failOnce(
    bool Function(String from, String to) matches,
  ) {
    var failed = false;
    return (from, to) async {
      if (!failed && matches(from, to)) {
        failed = true;
        throw const FileSystemException('falha simulada');
      }
      if (await FileSystemEntity.isDirectory(from)) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }
    };
  }

  Future<void> failingSwap(
    bool Function(String from, String to) matches,
  ) async {
    await seedDeck('Backup', image: 'img_backup.jpg');
    final zipPath = okValue(await repository.exportBackup());
    await database.db.delete('decks');
    await mediaFiles.mediaFile('img_backup.jpg').delete();
    await seedDeck('Atual', image: 'img_atual.jpg');
    await setUpWith(database, move: failOnce(matches));
    okValue(await repository.prepareImport(zipPath));

    expect(await repository.applyImport(), isA<Error<void>>());

    await expectOriginalsIntact();
  }

  String dbPath() => p.join(root.path, 'db', DatabaseService.fileName);

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

  test('recusa entradas fora do que o app grava', () async {
    for (final name in ['../fora.txt', '/abs.txt', 'outro.txt']) {
      final zipPath = await zipOf(extra: {name: 'ataque'});

      expect(
        await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>(),
        reason: name,
      );
    }
    expect(
      await File(p.join(root.path, 'backup', 'fora.txt')).exists(),
      isFalse,
    );
    expect(await File(p.join(root.path, 'fora.txt')).exists(), isFalse);
    expect(await File('/abs.txt').exists(), isFalse);
  });

  test('applyImport sem prepareImport recusa e não move nada', () async {
    var moves = 0;
    await setUpWith(
      DatabaseService(
        factory: databaseFactoryFfi,
        path: p.join(root.path, 'db2', DatabaseService.fileName),
      ),
      move: (from, to) async => moves++,
    );
    final importDir = Directory(p.join(root.path, 'backup', 'import'));
    await importDir.create(recursive: true);
    await File(p.join(importDir.path, 'manifest.json'))
        .writeAsString(manifestJson());
    await File(p.join(importDir.path, 'flashcards.db'))
        .writeAsBytes(await File(await makeDb()).readAsBytes());

    expect(await repository.applyImport(), isA<Error<void>>());
    expect(moves, 0);
  });

  test('apagar a cópia do arquivo escolhido depois de importar', () async {
    final zipPath = okValue(await repository.exportBackup());
    files.nextPick = zipPath;
    final copy = okValue(await repository.pickBackupFile())!;
    expect(await File(copy).exists(), isTrue);

    okValue(await repository.prepareImport(copy));
    okValue(await repository.applyImport());

    expect(await File(copy).exists(), isFalse);
  });

  test('o backup aceita um .nomedia na pasta de mídia', () async {
    await mediaFiles.mediaFile('.nomedia').writeAsString('');
    await seedDeck('Inglês', image: 'img_1.jpg');

    final zipPath = okValue(await repository.exportBackup());

    okValue(await repository.prepareImport(zipPath));
  });

  test('recusa um zip de outro app', () async {
    expect(okValue(await repository.prepareImport(await zipOf())), isNotNull);
    final zipPath = await zipOf(manifest: manifestJson(app: 'outro_app'));

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('recusa um backup de uma versão mais nova do app', () async {
    final zipPath = await zipOf(manifest: manifestJson(schemaVersion: 99));

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

  test('falha na reabertura devolve os dados originais', () async {
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
    await mediaFiles.mediaFile('img_backup.jpg').delete();
    await seedDeck('Atual', image: 'img_atual.jpg');
    okValue(await repository.prepareImport(zipPath));

    expect(await repository.applyImport(), isA<Error<void>>());

    await expectOriginalsIntact();
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

  test('recusa um banco cujas colunas de mídia têm nomes perigosos', () async {
    const names = ['../fora.jpg', 'a/b.jpg', r'a\b.jpg', '..', '.oculto'];
    final cases = [
      for (final name in names) ('front_image', name),
      for (final column in ['front_audio', 'back_image', 'back_audio'])
        (column, '../x.m4a'),
    ];
    okValue(
      await repository.prepareImport(
        await zipOf(card: {'back_audio': 'ok.m4a'}),
      ),
    );
    for (final (column, name) in cases) {
      final zipPath = await zipOf(card: {column: name});

      expect(
        await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>(),
        reason: '$column = $name',
      );
    }
  });

  test('aceita um backup cujo banco usa nomes simples de mídia', () async {
    await seedDeck('Inglês', image: 'img_1.jpg');
    final zipPath = okValue(await repository.exportBackup());

    okValue(await repository.prepareImport(zipPath));
  });

  test('(a) falha ao mover o banco original', () async {
    await failingSwap((from, to) => from == dbPath());
  });

  test('(b) falha ao mover a mídia original depois do banco', () async {
    await failingSwap((from, to) => from == mediaFiles.mediaDir.path);
  });

  test('(c) falha ao colocar o banco importado', () async {
    await failingSwap((from, to) => to == dbPath() && from.contains('import'));
  });

  test('(d) falha ao colocar a mídia importada', () async {
    await failingSwap(
      (from, to) => to == mediaFiles.mediaDir.path && from.contains('import'),
    );
  });

  test('recusa entradas media, media/., media/.. e aninhadas', () async {
    // Control: the same zip with a plain media file is accepted, so the bad
    // entry is the only defect in the cases below.
    okValue(
      await repository.prepareImport(
        await zipOf(extra: {'media/ok.jpg': 'foto'}),
      ),
    );
    for (final entry in ['media', 'media/.', 'media/..', 'media/a/b.jpg']) {
      final zipPath = await zipOf(extra: {entry: 'x'});

      expect(
        await repository.prepareImport(zipPath),
        isA<Error<BackupManifest>>(),
        reason: entry,
      );
      expect(
        await Directory(p.join(root.path, 'backup', 'import')).exists(),
        isFalse,
      );
    }
  });

  test('um erro na limpeza depois da troca ainda devolve Ok', () async {
    await seedDeck('Inglês');
    final zipPath = okValue(await repository.exportBackup());
    okValue(await repository.prepareImport(zipPath));
    final work = p.join(root.path, 'backup');
    Process.runSync('chmod', ['555', work]);
    try {
      okValue(await repository.applyImport());
    } finally {
      Process.runSync('chmod', ['755', work]);
    }

    expect(await deckNames(), ['Inglês']);
    expect(await database.db.query('decks'), isNotEmpty);
  });

  test('applyImport sem prepareImport devolve Error', () async {
    await seedDeck('Atual');

    expect(await repository.applyImport(), isA<Error<void>>());
    expect(await deckNames(), ['Atual']);
  });

  test('applyImport duas vezes seguidas: a segunda devolve Error', () async {
    await seedDeck('Inglês');
    final zipPath = okValue(await repository.exportBackup());
    okValue(await repository.prepareImport(zipPath));
    okValue(await repository.applyImport());

    expect(await repository.applyImport(), isA<Error<void>>());
  });

  test('um backup recusado não deixa a pasta import', () async {
    final zipPath = await handMadeZip({
      'manifest.json': manifestJson(app: 'outro_app'),
      'flashcards.db': 'x',
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
    expect(
      await Directory(p.join(root.path, 'backup', 'import')).exists(),
      isFalse,
    );
    expect(await repository.applyImport(), isA<Error<void>>());
  });

  test('recusa outro formatVersion', () async {
    final zipPath = await zipOf(manifest: manifestJson(formatVersion: 2));

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('recusa um zip de fotos sem manifesto', () async {
    final zipPath = await handMadeZip({'media/x.jpg': 'foto'});

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test('o manifesto conta os decks do arquivo exportado', () async {
    await seedDeck('Um');
    await seedDeck('Dois');
    final zipPath = okValue(await repository.exportBackup());

    final manifest = okValue(await repository.prepareImport(zipPath));

    expect(manifest.decks, 2);
    expect(manifest.cards, 2);
  });

  test('recusa mídia que não é texto no banco', () async {
    final dbFile = p.join(root.path, 'blob.db');
    final bad = DatabaseService(factory: databaseFactoryFfi, path: dbFile);
    await bad.open();
    await bad.db.execute('PRAGMA user_version = 1');
    final deckId = await bad.db.insert('decks', {'name': 'x', 'created_at': 0});
    await bad.db.insert('cards', {
      'deck_id': deckId,
      'front_image': Uint8List.fromList([1, 2, 3]),
      'created_at': 0,
    });
    await bad.close();
    final manifest = File(p.join(root.path, 'm.json'))
      ..writeAsStringSync(manifestJson());
    final zipPath = p.join(root.path, 'blob.zip');
    await zip.createZip(zipPath, {
      'manifest.json': manifest.path,
      'flashcards.db': dbFile,
    });

    expect(
      await repository.prepareImport(zipPath),
      isA<Error<BackupManifest>>(),
    );
  });

  test(
    'se o banco original não volta, o sidecar dele fica no rollback',
    () async {
      await seedDeck('Backup', image: 'img_backup.jpg');
      final zipPath = okValue(await repository.exportBackup());
      await database.db.delete('decks');
      await mediaFiles.mediaFile('img_backup.jpg').delete();
      await seedDeck('Atual', image: 'img_atual.jpg');
      await File('${dbPath()}-shm').writeAsString('sidecar do original');
      var first = true;
      await setUpWith(
        database,
        move: (from, to) async {
          final placingMedia =
              to == mediaFiles.mediaDir.path && from.contains('import');
          final restoringDb = to == dbPath() && from.contains('rollback');
          if ((placingMedia && first) || restoringDb) {
            first = false;
            throw const FileSystemException('falha simulada');
          }
          if (await FileSystemEntity.isDirectory(from)) {
            await Directory(from).rename(to);
          } else {
            await File(from).rename(to);
          }
        },
      );
      okValue(await repository.prepareImport(zipPath));

      expect(await repository.applyImport(), isA<Error<void>>());

      final kept = rollbackRoot().listSync().single as Directory;
      expect(File(p.join(kept.path, 'flashcards.db')).existsSync(), isTrue);
      expect(File(p.join(kept.path, 'flashcards.db-shm')).existsSync(), isTrue);
      expect(File('${dbPath()}-shm').existsSync(), isFalse);
    },
  );
}
