import 'dart:io';

import 'package:my_flashcards/data/services/backup_file_service.dart';

class FakeBackupFileService implements BackupFileService {
  /// The path of a real file to "pick", or null to cancel.
  String? nextPick;
  final shared = <String>[];

  @override
  Future<bool> pickZip(String destinationPath) async {
    final source = nextPick;
    if (source == null) return false;
    await File(source).copy(destinationPath);
    return true;
  }

  @override
  Future<void> share(String path) async => shared.add(path);
}
