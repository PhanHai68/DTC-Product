import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ảnh lưu tại `<Documents>/DTCProduct/FaultBank/photos/<tên file>`.
/// Chỉ tên file nằm trong database; đường dẫn đầy đủ tính lại mỗi lần vì
/// thư mục của app trên iOS có thể đổi sau khi cập nhật app.
class FaultFileStorage {
  const FaultFileStorage({this.rootOverride});

  /// Dùng trong test để ghi vào thư mục tạm.
  final Directory? rootOverride;

  bool get isSupported => true;

  Future<Directory> _photosDir() async {
    final root = rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(root.path, 'DTCProduct', 'FaultBank', 'photos'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> savePhoto(String fileName, Uint8List bytes) async {
    final dir = await _photosDir();
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes, flush: true);
  }

  Future<String?> photoPath(String fileName) async {
    final file = File(p.join((await _photosDir()).path, fileName));
    return await file.exists() ? file.path : null;
  }

  /// Nội dung ảnh, null nếu file không còn.
  Future<Uint8List?> readPhoto(String fileName) async {
    final file = File(p.join((await _photosDir()).path, fileName));
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> deletePhoto(String fileName) async {
    final file = File(p.join((await _photosDir()).path, fileName));
    if (await file.exists()) await file.delete();
  }
}
