import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:path/path.dart' as p;

import '../../helpers/temp_media.dart';

void main() {
  late MediaFileService files;

  setUp(() async => files = await createTempMediaFiles());

  test('newFileName usa prefixo, horário, 4 caracteres e extensão', () {
    final named = MediaFileService(
      mediaDir: files.mediaDir,
      draftDir: files.draftDir,
      random: Random(1),
      now: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );

    expect(
      named.newFileName('img', 'jpg'),
      matches(RegExp(r'^img_1760000000000_[a-z0-9]{4}\.jpg$')),
    );
  });

  test(
    'moveIntoDrafts move o arquivo e mantém a extensão em minúsculas',
    () async {
      final source = File(p.join(files.mediaDir.parent.path, 'IMG_0001.JPG'));
      await source.writeAsString('foto');

      final name = await files.moveIntoDrafts(source.path, 'img');

      expect(name, startsWith('img_'));
      expect(name, endsWith('.jpg'));
      expect(await files.draftFile(name).readAsString(), 'foto');
      expect(await source.exists(), isFalse);
    },
  );

  test('commitDrafts move para media e revertCommit traz de volta', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);

    await files.commitDrafts(['img_1.jpg']);
    expect(await files.mediaFile('img_1.jpg').exists(), isTrue);
    expect(await files.draftFile('img_1.jpg').exists(), isFalse);

    await files.revertCommit(['img_1.jpg']);
    expect(await files.draftFile('img_1.jpg').exists(), isTrue);
    expect(await files.mediaFile('img_1.jpg').exists(), isFalse);
  });

  test('deleteMedia apaga e ignora arquivos que não existem', () async {
    await writeMedia(files, 'img_1.jpg');

    await files.deleteMedia(['img_1.jpg', 'nao_existe.jpg']);

    expect(await files.mediaFile('img_1.jpg').exists(), isFalse);
  });

  test('deleteDrafts apaga só da pasta de rascunhos', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);
    await writeMedia(files, 'img_1.jpg');

    await files.deleteDrafts(['img_1.jpg']);

    expect(await files.draftFile('img_1.jpg').exists(), isFalse);
    expect(await files.mediaFile('img_1.jpg').exists(), isTrue);
  });

  test('clearDrafts esvazia a pasta de rascunhos', () async {
    await writeMedia(files, 'a.jpg', draft: true);
    await writeMedia(files, 'b.m4a', draft: true);

    await files.clearDrafts();

    expect(await files.draftDir.exists(), isTrue);
    expect(files.draftDir.listSync(), isEmpty);
  });

  test(
    'clearPickerLeftovers apaga só o que o image_picker deixa no cache',
    () async {
      const uuid = '0c9f1d2e-3a4b-4c5d-8e6f-7a8b9c0d1e2f';
      final root = files.draftDir.parent.path;
      Future<void> file(String path) async {
        await File(p.join(root, path)).create(recursive: true);
      }

      await file('$uuid/foto.jpg');
      await file('scaled_x.jpg');
      await file('${uuid}123.jpg');
      await file('${uuid}0.jpg');
      await file('share_plus/a.txt');
      await file('notes.txt');
      await file('outra_pasta/a.jpg');
      await file('${uuid}abc.jpg');
      await writeMedia(files, 'rascunho.jpg', draft: true);

      await files.clearPickerLeftovers();

      bool exists(String path) =>
          FileSystemEntity.typeSync(p.join(root, path)) !=
          FileSystemEntityType.notFound;
      expect(exists(uuid), isFalse);
      expect(exists('scaled_x.jpg'), isFalse);
      expect(exists('${uuid}123.jpg'), isFalse);
      expect(exists('${uuid}0.jpg'), isFalse);
      expect(exists('share_plus/a.txt'), isTrue);
      expect(exists('notes.txt'), isTrue);
      expect(exists('outra_pasta/a.jpg'), isTrue);
      expect(exists('${uuid}abc.jpg'), isTrue);
      expect(exists('drafts/rascunho.jpg'), isTrue);
      expect(files.mediaDir.existsSync(), isTrue);
    },
  );

  test(
    'deleteMedia e deleteDrafts ignoram nomes que não são simples',
    () async {
      final outsideMedia = File(p.join(files.mediaDir.parent.path, 'x'));
      final outsideDrafts = File(p.join(files.draftDir.parent.path, 'y'));
      await outsideMedia.writeAsString('a');
      await outsideDrafts.writeAsString('b');

      await files.deleteMedia(['../x', '..', '.', '.oculto', r'a\b', 'a/b']);
      await files.deleteDrafts(['../y']);

      expect(await outsideMedia.exists(), isTrue);
      expect(await outsideDrafts.exists(), isTrue);
    },
  );
}
