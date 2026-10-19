import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// Zip work runs in a separate isolate so big backups don't freeze the UI.
class ZipService {
  /// Creates [zipPath] with one entry per key of [entries], each holding the
  /// content of the file at its value.
  Future<void> createZip(String zipPath, Map<String, String> entries) =>
      Isolate.run(() => _createZip(zipPath, entries));

  Future<List<String>> listEntries(String zipPath) =>
      Isolate.run(() => _listEntries(zipPath));

  Future<void> extract(String zipPath, String outputDir) =>
      Isolate.run(() => _extract(zipPath, outputDir));
}

void _createZip(String zipPath, Map<String, String> entries) {
  final encoder = ZipFileEncoder()..create(zipPath);
  final streams = <InputFileStream>[];
  try {
    for (final MapEntry(key: name, value: source) in entries.entries) {
      if (name.startsWith('media/')) {
        // Photos and audio are already compressed, so they are stored as is.
        // This archive version only honours CompressionType on the entry.
        final file = File(source);
        final stream = InputFileStream(source);
        streams.add(stream);
        encoder.addArchiveFile(
          ArchiveFile.stream(name, stream)
            ..compression = CompressionType.none
            ..lastModTime =
                file.lastModifiedSync().millisecondsSinceEpoch ~/ 1000
            ..mode = file.statSync().mode,
        );
      } else {
        encoder.addFileSync(File(source), name);
      }
    }
  } finally {
    encoder.closeSync();
    for (final stream in streams) {
      stream.closeSync();
    }
  }
}

/// Decodes the zip in [input]; throws if it is not a zip.
Archive _decode(InputFileStream input) {
  final archive = ZipDecoder().decodeStream(input);
  // The decoder reads a non-zip file as an empty archive instead of failing.
  if (archive.files.isEmpty) {
    throw const FormatException('Arquivo zip inválido ou vazio.');
  }
  return archive;
}

List<String> _listEntries(String zipPath) {
  final input = InputFileStream(zipPath);
  try {
    return [for (final file in _decode(input).files) file.name];
  } finally {
    input.closeSync();
  }
}

void _extract(String zipPath, String outputDir) {
  final input = InputFileStream(zipPath);
  try {
    extractArchiveToDiskSync(_decode(input), outputDir);
  } finally {
    input.closeSync();
  }
}
