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

const _manifestName = 'manifest.json';

class BackupRepository {
  BackupRepository({
    required this._database,
    required this._mediaFiles,
    required this._zip,
    required this._files,
    required this._workDir,
    required this._rollbackRoot,
    DateTime Function()? now,
    @visibleForTesting Future<void> Function(String from, String to)? move,
  }) : _now = now ?? DateTime.now,
       _move = move ?? _moveEntity;

  final DatabaseService _database;
  final MediaFileService _mediaFiles;
  final ZipService _zip;
  final BackupFileService _files;
  final Directory _workDir;

  /// Where the data kept aside during an import lives. It is never cleaned
  /// automatically: after a failed restore it may hold the only copy.
  final Directory _rollbackRoot;
  final DateTime Function() _now;

  /// Moves a file or folder; replaceable so tests can make a step fail.
  final Future<void> Function(String from, String to) _move;

  var _prepared = false;

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
      final counts = await _database.countsIn(dbCopy);
      final manifest = BackupManifest(
        app: BackupManifest.appId,
        formatVersion: BackupManifest.currentFormatVersion,
        schemaVersion: DatabaseService.schemaVersion,
        exportedAt: now,
        decks: counts.decks,
        cards: counts.cards,
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
        _prepared = false;
        try {
          final importDir = await _freshDir('import');
          _checkEntryNames(await _zip.listEntries(zipPath));
          await _zip.extract(zipPath, importDir.path);
          final manifest = await _validateExtracted(importDir);
          _prepared = true;
          return manifest;
        } catch (_) {
          await _deleteTree(_importDir);
          rethrow;
        }
      });

  Future<BackupManifest> _validateExtracted(Directory importDir) async {
    final manifestPath = p.join(importDir.path, _manifestName);
    final importedDb = p.join(importDir.path, DatabaseService.fileName);
    final mediaPath = p.join(importDir.path, 'media');
    final mediaType = await FileSystemEntity.type(
      mediaPath,
      followLinks: false,
    );
    if (await FileSystemEntity.type(manifestPath, followLinks: false) !=
            FileSystemEntityType.file ||
        await FileSystemEntity.type(importedDb, followLinks: false) !=
            FileSystemEntityType.file ||
        (mediaType != FileSystemEntityType.notFound &&
            mediaType != FileSystemEntityType.directory)) {
      throw const FormatException('Backup com arquivos inesperados.');
    }
    final manifest = BackupManifest.fromJson(
      jsonDecode(await File(manifestPath).readAsString()),
    );
    if (manifest.app != BackupManifest.appId ||
        manifest.formatVersion != BackupManifest.currentFormatVersion ||
        manifest.schemaVersion > DatabaseService.schemaVersion) {
      throw const FormatException('Backup de outro app ou mais novo.');
    }
    await _database.checkReadable(importedDb);
    for (final name in await _database.mediaNamesIn(importedDb)) {
      if (!MediaFileService.isPlainFileName(name)) {
        throw FormatException('Nome de mídia inesperado no backup: $name');
      }
    }
    return manifest;
  }

  /// Replaces all app data with the prepared backup.
  ///
  /// Every completed move is journaled: [moved] holds (live path, rollback
  /// path) for the originals put aside, [placed] holds (import path, live
  /// path) for the imported items put in their place. If a step fails, only
  /// what was journaled is undone, in reverse order, so a live path this
  /// import did not fill is never deleted.
  Future<Result<void>> applyImport() => guard(() async {
    if (!_prepared) throw const FormatException('Nenhum backup preparado.');
    _prepared = false;
    final rollbackDir = await _newRollbackDir();
    final moved = <(String, String)>[];
    final placed = <(String, String)>[];
    final dbPath = _database.path;
    final importedDb = p.join(_importDir.path, DatabaseService.fileName);
    final importedMedia = p.join(_importDir.path, 'media');

    Future<void> setAside(String live, String name) async {
      if (await FileSystemEntity.type(live, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return;
      }
      final aside = p.join(rollbackDir.path, name);
      await _move(live, aside);
      moved.add((live, aside));
    }

    Future<void> place(String from, String to) async {
      await _move(from, to);
      placed.add((from, to));
    }

    try {
      await _database.close();
      for (final suffix in _dbSuffixes) {
        await setAside('$dbPath$suffix', p.basename('$dbPath$suffix'));
      }
      await setAside(_mediaFiles.mediaDir.path, 'media');
      await place(importedDb, dbPath);
      if (await FileSystemEntity.type(importedMedia, followLinks: false) !=
          FileSystemEntityType.notFound) {
        await place(importedMedia, _mediaFiles.mediaDir.path);
      }
      await _mediaFiles.ensureDirectories();
      await _database.open();
    } catch (_) {
      await _undo(rollbackDir, moved, placed);
      rethrow;
    }
    // Committed: the new data is in place and open. Cleaning up is best
    // effort, and cleanOldExports retries import/ on the next start.
    await _deleteTree(rollbackDir);
    await _deleteTree(_importDir);
  });

  static const _dbSuffixes = ['', '-wal', '-shm', '-journal'];

  /// Puts back exactly what the journals say was moved. A failing step is
  /// logged and the rest still runs; the rollback folder is only removed
  /// (never recursively) when every step worked.
  Future<void> _undo(
    Directory rollbackDir,
    List<(String, String)> moved,
    List<(String, String)> placed,
  ) async {
    var clean = true;
    Future<void> step(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        clean = false;
        debugPrint('Não foi possível restaurar os dados: $error');
      }
    }

    await step(_database.close);
    for (final (from, to) in placed.reversed) {
      await step(() => _move(to, from));
    }
    // The originals' sidecars were all moved before the imported database was
    // placed, so any sidecar at the live path now belongs to the imported one.
    if (placed.any((item) => item.$2 == _database.path)) {
      for (final suffix in _dbSuffixes.skip(1)) {
        await step(() => _deleteIfExists('${_database.path}$suffix'));
      }
    }
    for (final (live, aside) in moved.reversed) {
      await step(() => _move(aside, live));
    }
    await step(_mediaFiles.ensureDirectories);
    await step(_database.open);
    if (clean) await _deleteIfEmpty(rollbackDir);
  }

  Future<void> cancelImport() async {
    _prepared = false;
    await _deleteTree(_importDir);
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

/// Only the entries this app writes are accepted: the manifest, the
/// database, the `media/` folder and plain files directly inside it. That also
/// rules out paths that would escape the extraction folder.
void _checkEntryNames(List<String> names) {
  for (final name in names) {
    final parts = p.posix.split(name);
    final allowed =
        name == _manifestName ||
        name == DatabaseService.fileName ||
        name == 'media/' ||
        (!name.endsWith('/') &&
            parts.length == 2 &&
            parts[0] == 'media' &&
            MediaFileService.isPlainFileName(parts[1]));
    if (!allowed) throw FormatException('Entrada inesperada no backup: $name');
  }
  if (!names.contains(_manifestName) ||
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

Future<void> _moveEntity(String from, String to) async {
  if (await FileSystemEntity.isDirectory(from)) {
    await Directory(from).rename(to);
  } else {
    await File(from).rename(to);
  }
}

Future<void> _deleteTree(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } on FileSystemException catch (error) {
    debugPrint('Não foi possível apagar ${dir.path}: $error');
  }
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
