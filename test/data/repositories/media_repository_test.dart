import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/data/services/image_picker_service.dart';
import 'package:my_flashcards/data/services/media_file_service.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';
import 'package:path/path.dart' as p;

import '../../helpers/result.dart';
import '../../helpers/temp_media.dart';

/// Returns whatever path the test puts in [nextPath], or throws [error].
class _FakeImagePicker implements ImagePickerService {
  String? nextPath;
  Exception? error;
  final origins = <ImageOrigin>[];

  @override
  Future<String?> pickImage(ImageOrigin origin) async {
    origins.add(origin);
    if (error != null) throw error!;
    return nextPath;
  }
}

void main() {
  late MediaFileService files;
  late _FakeImagePicker picker;
  late MediaRepository repository;

  setUp(() async {
    files = await createTempMediaFiles();
    picker = _FakeImagePicker();
    repository = MediaRepository(files: files, imagePicker: picker);
  });

  test('pickImage traz a foto escolhida para os rascunhos', () async {
    final picked = File(p.join(files.mediaDir.parent.path, 'scaled_1.jpg'));
    await picked.writeAsString('foto');
    picker.nextPath = picked.path;

    final name = okValue(await repository.pickImage(ImageOrigin.camera));

    expect(picker.origins, [ImageOrigin.camera]);
    expect(name, startsWith('img_'));
    expect(await File(repository.draftPath(name!)).readAsString(), 'foto');
    expect(await picked.exists(), isFalse);
  });

  test('pickImage cancelado devolve null', () async {
    expect(okValue(await repository.pickImage(ImageOrigin.gallery)), isNull);
  });

  test('pickImage com erro do seletor devolve Error', () async {
    picker.error = Exception('câmera ocupada');

    expect(
      await repository.pickImage(ImageOrigin.camera),
      isA<Error<String?>>(),
    );
  });

  test('commitDrafts e revertCommit movem entre as pastas', () async {
    await writeMedia(files, 'img_1.jpg', draft: true);

    okValue(await repository.commitDrafts(['img_1.jpg']));
    expect(await File(repository.mediaPath('img_1.jpg')).exists(), isTrue);

    await repository.revertCommit(['img_1.jpg']);
    expect(await File(repository.draftPath('img_1.jpg')).exists(), isTrue);
  });

  test('commitDrafts de um rascunho inexistente devolve Error', () async {
    expect(await repository.commitDrafts(['sumiu.jpg']), isA<Error<void>>());
  });

  test('discardDrafts e clearDrafts apagam rascunhos', () async {
    await writeMedia(files, 'a.jpg', draft: true);
    await writeMedia(files, 'b.jpg', draft: true);

    await repository.discardDrafts(['a.jpg']);
    expect(await files.draftFile('a.jpg').exists(), isFalse);

    await repository.clearDrafts();
    expect(files.draftDir.listSync(), isEmpty);
  });
}
