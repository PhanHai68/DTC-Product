import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/site_layout_models.dart';
import 'site_layout_file_storage.dart';

class SitePhotoService {
  SitePhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<List<SitePhoto>> pick({
    required String projectId,
    required ImageSource source,
  }) async {
    final pickedFiles = source == ImageSource.camera
        ? <XFile>[
            if (await _picker.pickImage(source: source) case final XFile file)
              file,
          ]
        : await _picker.pickMultiImage();
    final photos = <SitePhoto>[];
    for (var index = 0; index < pickedFiles.length; index++) {
      final picked = pickedFiles[index];
      final originalBytes = await picked.readAsBytes();
      final id = newSiteLayoutId('photo');
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final originalPath = await saveSiteLayoutPhoto(
        projectId: projectId,
        fileName: '${id}_original.$extension',
        bytes: originalBytes,
      );
      final thumbnailBytes = _thumbnail(originalBytes);
      final thumbnailPath = thumbnailBytes == null
          ? null
          : await saveSiteLayoutPhoto(
              projectId: projectId,
              fileName: '${id}_thumb.jpg',
              bytes: thumbnailBytes,
              thumbnail: true,
            );
      final now = DateTime.now();
      photos.add(
        SitePhoto(
          id: id,
          projectId: projectId,
          originalPath: originalPath,
          thumbnailPath: thumbnailPath,
          caption: picked.name,
          capturedAt: now,
          createdAt: now,
        ),
      );
    }
    return photos;
  }

  Uint8List? _thumbnail(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: 480)
        : img.copyResize(decoded, height: 480);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  static Future<Uint8List?> reportBytes(SitePhoto photo) async {
    final bytes = await readSiteLayoutFile(photo.originalPath);
    if (bytes == null) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    img.Image resized = decoded;
    if (decoded.width > 1600 || decoded.height > 1600) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: 1600)
          : img.copyResize(decoded, height: 1600);
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }
}
