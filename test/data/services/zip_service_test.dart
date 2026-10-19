import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/zip_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  final zip = ZipService();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zip_service_test_');
    addTearDown(() => root.delete(recursive: true));
  });

  Future<String> write(String name, String content) async {
    final file = File(p.join(root.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  test('cria, lista e extrai mantendo os nomes das entradas', () async {
    final zipPath = p.join(root.path, 'teste.zip');
    await zip.createZip(zipPath, {
      'manifest.json': await write('a.json', '{}'),
      'media/img_1.jpg': await write('b.jpg', 'foto'),
    });

    expect(
      await zip.listEntries(zipPath),
      containsAll(['manifest.json', 'media/img_1.jpg']),
    );

    final out = p.join(root.path, 'saida');
    await zip.extract(zipPath, out);
    expect(
      await File(p.join(out, 'media', 'img_1.jpg')).readAsString(),
      'foto',
    );
  });

  test('listEntries de um arquivo que não é zip lança', () async {
    final notZip = await write('falso.zip', 'isto não é um zip');

    expect(zip.listEntries(notZip), throwsA(isA<Exception>()));
  });

  test('guarda a mídia sem compressão e comprime o resto', () async {
    final text = 'a' * 5000;
    final zipPath = p.join(root.path, 'store.zip');
    await zip.createZip(zipPath, {
      'manifest.json': await write('m.json', text),
      'media/img_1.jpg': await write('i.jpg', text),
    });

    final input = InputFileStream(zipPath);
    addTearDown(input.closeSync);
    final files = {
      for (final f in ZipDecoder().decodeStream(input).files) f.name: f,
    };

    expect(files['media/img_1.jpg']!.compression, CompressionType.none);
    expect(files['manifest.json']!.compression, CompressionType.deflate);
  });
}
