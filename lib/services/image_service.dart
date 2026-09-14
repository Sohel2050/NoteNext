import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// নোটে ছবি যোগ করার সার্ভিস। image_picker দিয়ে নেওয়া ছবি অ্যাপের
/// ডকুমেন্টস ডিরেক্টরির `note_images/` ফোল্ডারে কপি করে রাখা হয়,
/// যাতে temp ক্যাশ ফাইল পরে মুছে গেলেও নোটের ছবি হারিয়ে না যায়।
class ImageService {
  ImageService._internal();
  static final ImageService instance = ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<Directory> _imageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/note_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _copyToAppDir(file);
  }

  Future<String?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return null;
    return _copyToAppDir(file);
  }

  Future<List<String>> pickMultipleFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    final paths = <String>[];
    for (final f in files) {
      final path = await _copyToAppDir(f);
      if (path != null) paths.add(path);
    }
    return paths;
  }

  Future<String> _copyToAppDir(XFile file) async {
    final dir = await _imageDir();
    final ext = file.path.split('.').last;
    final newPath = '${dir.path}/${_uuid.v4()}.$ext';
    final bytes = await file.readAsBytes();
    final newFile = File(newPath);
    await newFile.writeAsBytes(bytes);
    return newPath;
  }

  Future<void> deleteImage(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
