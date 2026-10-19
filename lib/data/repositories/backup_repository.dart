import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/backup_manifest.dart';
import '../../utils/dates.dart';
import '../../utils/result.dart';
import '../services/backup_file_service.dart';
import '../services/database_service.dart';
import '../services/media_file_service.dart';
import '../services/zip_service.dart';

class BackupRepository {
  BackupRepository({
    required this._database,
    required this._mediaFiles,
    required this._zip,
    required this._files,
    required this._workDir,
    required this._rollbackRoot,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _manifestName = 'manifest.json';

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final ZipService _zip;
  final BackupFileService _files;
  final Directory _workDir;

  /// Where the data kept aside during an import lives. It is never cleaned
  /// automatically: after a failed restore it may hold the only copy.
  final Directory _rollbackRoot;
  final DateTime Function() _now;

  Directory get _importDir => Directory(p.join(_workDir.path, 'import'));

  /// Builds the backup and returns the path of the .zip.
  Future<Result<String>> exportBackup() => guard(() async {
    final exportDir = await _freshDir('export');
    final now = _now();
    final zipPath = p.join(
      _workDir.path,
      'my-flashcards-backup-${formatDate(now)}.zip',
    );
    try {
      final dbCopy = p.join(exportDir.path, DatabaseService.fileName);
      await _database.copyTo(dbCopy);
      final manifest = BackupManifest(
        app: BackupManifest.appId,
        formatVersion: BackupManifest.currentFormatVersion,
        schemaVersion: DatabaseService.schemaVersion,
        exportedAt: now,
        decks: await _count('decks'),
        cards: await _count('cards'),
      );
      final manifestPath = p.join(exportDir.path, _manifestName);
      await File(manifestPath).writeAsString(jsonEncode(manifest.toJson()));
      final media = await _mediaFiles.mediaDir.exists()
          ? _mediaFiles.mediaDir.listSync().whereType<File>()
          : const <File>[];
      await _zip.createZip(zipPath, {
        _manifestName: manifestPath,
        DatabaseService.fileName: dbCopy,
        for (final file in media) 'media/${p.basename(file.path)}': file.path,
      });
    } on Exception {
      await _deleteIfExists(zipPath);
      rethrow;
    } finally {
      await exportDir.delete(recursive: true);
    }
    return zipPath;
  });

  Future<Result<void>> shareBackup(String zipPath) =>
      guard(() => _files.share(zipPath));

  /// Lets the user choose a backup and returns the path of a local copy of
  /// it, or null when the user cancels.
  Future<Result<String?>> pickBackupFile() => guard(() async {
    await _workDir.create(recursive: true);
    final destination = p.join(_workDir.path, 'import_source.zip');
    return await _files.pickZip(destination) ? destination : null;
  });

  /// Extracts and checks the backup. Returns its manifest, so the user can
  /// confirm before anything changes.
  Future<Result<BackupManifest>> prepareImport(String zipPath) =>
      guard(() async {
        final importDir = await _freshDir('import');
        _checkEntryNames(await _zip.listEntries(zipPath));
        await _zip.extract(zipPath, importDir.path);

        final manifestFile = File(p.join(importDir.path, _manifestName));
        final manifest = BackupManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()),
        );
        if (manifest.app != BackupManifest.appId ||
            manifest.formatVersion != BackupManifest.currentFormatVersion ||
            manifest.schemaVersion > DatabaseService.schemaVersion) {
          throw const FormatException('Backup de outro app ou mais novo.');
        }
        final importedDb = p.join(importDir.path, DatabaseService.fileName);
        await _database.checkReadable(importedDb);
        for (final name in await _database.mediaNamesIn(importedDb)) {
          if (!MediaFileService.isPlainFileName(name)) {
            throw FormatException('Nome de mídia inesperado no backup: $name');
          }
        }
        return manifest;
      });

  /// Replaces all app data with the prepared backup. The current data is
  /// kept aside and put back if any step fails.
  Future<Result<void>> applyImport() => guard(() async {
    final rollbackDir = await _newRollbackDir();
    final dbFiles = [
      for (final suffix in ['', '-wal', '-shm', '-journal'])
        '${_database.path}$suffix',
    ];

    await _database.close();
    try {
      for (final path in dbFiles) {
        await _moveIfExists(path, p.join(rollbackDir.path, p.basename(path)));
      }
      await _moveIfExists(
        _mediaFiles.mediaDir.path,
        p.join(rollbackDir.path, 'media'),
      );
      await _move(
        p.join(_importDir.path, DatabaseService.fileName),
        _database.path,
      );
      await _moveIfExists(
        p.join(_importDir.path, 'media'),
        _mediaFiles.mediaDir.path,
      );
      await _mediaFiles.ensureDirectories();
      await _database.open();
    } on Exception {
      await _restore(rollbackDir, dbFiles);
      await _deleteIfEmpty(rollbackDir);
      rethrow;
    }
    await rollbackDir.delete(recursive: true);
    await _importDir.delete(recursive: true);
  });

  Future<void> cancelImport() async {
    await guard(() async {
      if (await _importDir.exists()) await _importDir.delete(recursive: true);
    });
  }

  /// Deletes the .zip files of earlier exports and leftover work folders.
  /// The rollback folder is never touched: it may hold the user's data.
  Future<void> cleanOldExports() async {
    await guard(() async {
      if (!await _workDir.exists()) return;
      for (final entity in _workDir.listSync()) {
        final name = p.basename(entity.path);
        if (entity is File && name.endsWith('.zip')) {
          await entity.delete();
        } else if (entity is Directory &&
            (name == 'export' || name == 'import')) {
          await entity.delete(recursive: true);
        }
      }
    });
  }

  Future<void> _restore(Directory rollbackDir, List<String> dbFiles) async {
    try {
      await _database.close();
      for (final path in dbFiles) {
        await _deleteIfExists(path);
      }
      if (await _mediaFiles.mediaDir.exists()) {
        await _mediaFiles.mediaDir.delete(recursive: true);
      }
      for (final path in dbFiles) {
        await _moveIfExists(p.join(rollbackDir.path, p.basename(path)), path);
      }
      await _moveIfExists(
        p.join(rollbackDir.path, 'media'),
        _mediaFiles.mediaDir.path,
      );
      await _mediaFiles.ensureDirectories();
      await _database.open();
    } on Exception catch (error) {
      debugPrint('Não foi possível restaurar os dados: $error');
    }
  }

  Future<int> _count(String table) async {
    final rows = await _database.db.rawQuery('SELECT COUNT(*) FROM $table');
    return rows.single.values.single! as int;
  }

  /// A folder no earlier import has used; existing ones are never reused.
  Future<Directory> _newRollbackDir() async {
    final base = 'rollback-${_now().millisecondsSinceEpoch}';
    var dir = Directory(p.join(_rollbackRoot.path, base));
    for (var i = 1; await dir.exists(); i++) {
      dir = Directory(p.join(_rollbackRoot.path, '$base-$i'));
    }
    return dir.create(recursive: true);
  }

  Future<Directory> _freshDir(String name) async {
    final dir = Directory(p.join(_workDir.path, name));
    if (await dir.exists()) await dir.delete(recursive: true);
    return dir.create(recursive: true);
  }
}

/// Only the three kinds of entries this app writes are accepted, which also
/// rules out paths that would escape the extraction folder.
void _checkEntryNames(List<String> names) {
  for (final name in names) {
    final parts = p.posix.split(name);
    final allowed =
        name == 'manifest.json' ||
        name == DatabaseService.fileName ||
        (parts.isNotEmpty && parts.first == 'media' && parts.length <= 2);
    final safe =
        !p.posix.isAbsolute(name) &&
        !name.contains(r'\') &&
        !parts.contains('..');
    if (!allowed || !safe) {
      throw FormatException('Entrada inesperada no backup: $name');
    }
  }
  if (!names.contains('manifest.json') ||
      !names.contains(DatabaseService.fileName)) {
    throw const FormatException('Backup incompleto.');
  }
}

/// Non-recursive on purpose: a folder that still holds anything is kept.
Future<void> _deleteIfEmpty(Directory dir) async {
  try {
    await dir.delete();
  } on FileSystemException {
    // Not empty (or already gone): leave it.
  }
}

Future<void> _move(String from, String to) async {
  if (await FileSystemEntity.isDirectory(from)) {
    await Directory(from).rename(to);
  } else {
    await File(from).rename(to);
  }
}

Future<void> _moveIfExists(String from, String to) async {
  if (await FileSystemEntity.type(from) != FileSystemEntityType.notFound) {
    await _move(from, to);
  }
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
