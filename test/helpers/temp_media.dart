import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:path/path.dart' as p;

/// A [MediaFileService] over a temporary folder deleted after the test.
Future<MediaFileService> createTempMediaFiles() async {
  final root = await Directory.systemTemp.createTemp('my_flashcards_test_');
  addTearDown(() => root.delete(recursive: true));
  final files = MediaFileService(
    mediaDir: Directory(p.join(root.path, 'media')),
    draftDir: Directory(p.join(root.path, 'drafts')),
  );
  await files.ensureDirectories();
  return files;
}

/// Writes a small file named [name] in the media folder, or in the drafts.
Future<String> writeMedia(
  MediaFileService files,
  String name, {
  bool draft = false,
}) async {
  final file = draft ? files.draftFile(name) : files.mediaFile(name);
  await file.writeAsString('conteúdo de teste');
  return name;
}
