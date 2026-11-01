import 'package:image_picker/image_picker.dart';

abstract class ImagePickerService {
  Future<XFile?> pickImage();
}

class DeviceImagePickerService implements ImagePickerService {
  final ImagePicker _picker;

  DeviceImagePickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> pickImage() => _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 85,
  );
}
