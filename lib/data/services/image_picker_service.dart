import 'package:image_picker/image_picker.dart';

import '../../domain/models/image_origin.dart';

class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxDimension = 1280.0;
  static const quality = 80;

  final ImagePicker _picker;

  /// Opens the system camera or photo picker. Returns the path of the image,
  /// already resized and compressed, or null when the user cancels.
  Future<String?> pickImage(ImageOrigin origin) async {
    final file = await _picker.pickImage(
      source: switch (origin) {
        ImageOrigin.camera => ImageSource.camera,
        ImageOrigin.gallery => ImageSource.gallery,
      },
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}
