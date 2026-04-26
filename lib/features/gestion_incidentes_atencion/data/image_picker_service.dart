import 'package:image_picker/image_picker.dart';

class IncidentImagePickerService {
  final ImagePicker _picker;

  IncidentImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  Future<XFile?> takePhoto() {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
  }

  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
  }
}
