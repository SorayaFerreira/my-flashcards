import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's private media folder, plus the scratch folder where the editor
/// keeps new files until the card is saved.
class MediaFileService {
  MediaFileService({
    required this.mediaDir,
    required this.draftDir,
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  final Directory mediaDir;
  final Directory draftDir;
  final Random _random;
  final DateTime Function() _now;

  static Future<MediaFileService> create() async {
    final documents = await getApplicationDocumentsDirectory();
    final temporary = await getTemporaryDirectory();
    final files = MediaFileService(
      mediaDir: Directory(p.join(documents.path, 'media')),
      draftDir: Directory(p.join(temporary.path, 'editor_tmp')),
    );
    await files.ensureDirectories();
    return files;
  }

  Future<void> ensureDirectories() async {
    await mediaDir.create(recursive: true);
    await draftDir.create(recursive: true);
  }

  /// A new file name such as `img_1760000000000_a3f9.jpg`.
  String newFileName(String prefix, String extension) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = String.fromCharCodes([
      for (var i = 0; i < 4; i++)
        chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
    return '${prefix}_${_now().millisecondsSinceEpoch}_$suffix.$extension';
  }

  File mediaFile(String name) => File(p.join(mediaDir.path, name));

  File draftFile(String name) => File(p.join(draftDir.path, name));

  /// Moves [sourcePath] into the draft folder under a new name and returns
  /// that name.
  Future<String> moveIntoDrafts(String sourcePath, String prefix) async {
    final extension = p
        .extension(sourcePath)
        .replaceFirst('.', '')
        .toLowerCase();
    final name = newFileName(prefix, extension.isEmpty ? 'bin' : extension);
    await _move(File(sourcePath), draftFile(name).path);
    return name;
  }

  Future<void> commitDrafts(Iterable<String> names) async {
    for (final name in names) {
      await _move(draftFile(name), mediaFile(name).path);
    }
  }

  Future<void> revertCommit(Iterable<String> names) async {
    for (final name in names) {
      final file = mediaFile(name);
      if (await file.exists()) await _move(file, draftFile(name).path);
    }
  }

  Future<void> deleteDrafts(Iterable<String> names) =>
      _deleteAll(names.map(draftFile));

  Future<void> deleteMedia(Iterable<String> names) =>
      _deleteAll(names.map(mediaFile));

  Future<void> clearDrafts() async {
    if (await draftDir.exists()) await draftDir.delete(recursive: true);
    await draftDir.create(recursive: true);
  }
}

Future<void> _move(File file, String destination) async {
  try {
    await file.rename(destination);
  } on FileSystemException {
    // rename can't cross file systems; copying can.
    await file.copy(destination);
    await file.delete();
  }
}

Future<void> _deleteAll(Iterable<File> files) async {
  for (final file in files) {
    if (await file.exists()) await file.delete();
  }
}
