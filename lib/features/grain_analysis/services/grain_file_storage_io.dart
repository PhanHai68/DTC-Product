import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ảnh gốc (đủ độ phân giải, NFR-06) lưu tại
/// `<Documents>/DTCProduct/GrainAnalysis/images/<tên file>`. Database chỉ
/// giữ tên file; đường dẫn tính lại mỗi lần vì thư mục app trên iOS có thể
/// đổi sau khi cập nhật.
class GrainFileStorage {
  const GrainFileStorage({this.rootOverride});

  /// Dùng trong test để ghi vào thư mục tạm.
  final Directory? rootOverride;

  bool get isSupported => true;

  Future<Directory> _imagesDir() async {
    final root = rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(root.path, 'DTCProduct', 'GrainAnalysis', 'images'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> saveImage(String fileName, Uint8List bytes) async {
    final dir = await _imagesDir();
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes, flush: true);
  }

  Future<String?> imagePath(String fileName) async {
    final file = File(p.join((await _imagesDir()).path, fileName));
    return await file.exists() ? file.path : null;
  }

  Future<void> deleteImage(String fileName) async {
    final file = File(p.join((await _imagesDir()).path, fileName));
    if (await file.exists()) await file.delete();
  }
}
