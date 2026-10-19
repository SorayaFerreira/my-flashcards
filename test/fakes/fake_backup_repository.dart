import 'package:my_flashcards/data/repositories/backup_repository.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';
import 'package:my_flashcards/utils/result.dart';

class FakeBackupRepository implements BackupRepository {
  Exception? exportError;
  String? pickedPath = '/tmp/escolhido.zip';
  Exception? prepareError;
  Exception? applyError;
  BackupManifest manifest = BackupManifest(
    app: BackupManifest.appId,
    formatVersion: 1,
    schemaVersion: 1,
    exportedAt: DateTime(2026, 10, 11, 20, 15),
    decks: 3,
    cards: 87,
  );

  final shared = <String>[];
  var applyCalls = 0;
  var cancelCalls = 0;
  var cleanCalls = 0;
  var exportCalls = 0;

  @override
  Future<Result<String>> exportBackup() async {
    exportCalls++;
    final error = exportError;
    if (error != null) return Result.error(error);
    return const Result.ok('/tmp/my-flashcards-backup-2026-10-12.zip');
  }

  @override
  Future<Result<void>> shareBackup(String zipPath) async {
    shared.add(zipPath);
    return const Result.ok(null);
  }

  @override
  Future<Result<String?>> pickBackupFile() async => Result.ok(pickedPath);

  @override
  Future<Result<BackupManifest>> prepareImport(String zipPath) async {
    final error = prepareError;
    if (error != null) return Result.error(error);
    return Result.ok(manifest);
  }

  @override
  Future<Result<void>> applyImport() async {
    applyCalls++;
    final error = applyError;
    if (error != null) return Result.error(error);
    return const Result.ok(null);
  }

  @override
  Future<void> cancelImport() async => cancelCalls++;

  @override
  Future<void> cleanOldExports() async => cleanCalls++;
}
