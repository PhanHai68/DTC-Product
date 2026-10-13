import 'dart:typed_data';

import 'drive_doc_cache_factory.dart'
    if (dart.library.io) 'drive_doc_cache_factory_io.dart'
    if (dart.library.js_interop) 'drive_doc_cache_factory_web.dart';

/// Bộ đệm PDF đã tải từ Drive để mở lại khi không có mạng.
/// Mỗi file chỉ giữ một phiên bản (theo `DriveItem.version`).
abstract class DriveDocCache {
  factory DriveDocCache() => createDriveDocCache();

  /// Bản đúng phiên bản [version], hoặc null nếu chưa có / đã cũ.
  Future<Uint8List?> read(String id, String version);

  /// Bản bất kỳ đã lưu — dùng khi mất mạng, chấp nhận bản cũ.
  Future<Uint8List?> readAny(String id);

  Future<void> write(String id, String version, Uint8List bytes);
}

/// Giữ trong bộ nhớ, mất khi đóng app. Dùng cho web và test.
class MemoryDriveDocCache implements DriveDocCache {
  final _entries = <String, (String, Uint8List)>{};

  @override
  Future<Uint8List?> read(String id, String version) async {
    final entry = _entries[id];
    return entry != null && entry.$1 == version ? entry.$2 : null;
  }

  @override
  Future<Uint8List?> readAny(String id) async => _entries[id]?.$2;

  @override
  Future<void> write(String id, String version, Uint8List bytes) async {
    _entries[id] = (version, bytes);
  }
}
