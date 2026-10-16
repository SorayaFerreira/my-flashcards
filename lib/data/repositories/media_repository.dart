import '../../domain/models/image_origin.dart';
import '../../utils/result.dart';
import '../services/image_picker_service.dart';
import '../services/media_file_service.dart';

class MediaRepository {
  MediaRepository({required this._files, required this._imagePicker});

  final MediaFileService _files;
  final ImagePickerService _imagePicker;

  /// Lets the user take or choose a picture and keeps it as a draft. Returns
  /// the draft's file name, or null when the user cancels.
  Future<Result<String?>> pickImage(ImageOrigin origin) => guard(() async {
    final path = await _imagePicker.pickImage(origin);
    if (path == null) return null;
    return _files.moveIntoDrafts(path, 'img');
  });

  String draftPath(String name) => _files.draftFile(name).path;

  String mediaPath(String name) => _files.mediaFile(name).path;

  Future<Result<void>> commitDrafts(Iterable<String> names) =>
      guard(() => _files.commitDrafts(names));

  // The clean-up steps below never fail: at worst a stray file stays behind,
  // and guard() already logs the error.

  Future<void> revertCommit(Iterable<String> names) async {
    await guard(() => _files.revertCommit(names));
  }

  Future<void> discardDrafts(Iterable<String> names) async {
    await guard(() => _files.deleteDrafts(names));
  }

  Future<void> clearDrafts() async {
    await guard(_files.clearDrafts);
  }
}
