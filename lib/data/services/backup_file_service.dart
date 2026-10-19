import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class BackupFileService {
  /// Lets the user choose a .zip and copies it to [destinationPath]. The
  /// copy works for files from any provider, such as Google Drive. Returns
  /// false when the user cancels. A partly written copy is deleted if the
  /// copy fails.
  Future<bool> pickZip(String destinationPath) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null) return false;
    final destination = File(destinationPath);
    final sink = destination.openWrite();
    try {
      await sink.addStream(picked.readAsByteStream());
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    return true;
  }

  /// Opens the Android share menu with the file.
  Future<void> share(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'application/zip')]),
    );
  }
}
