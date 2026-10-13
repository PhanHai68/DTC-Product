import 'drive_doc_cache.dart';

// Web: chỉ đệm trong phiên — trình duyệt giới hạn dung lượng lưu trữ cục bộ.
DriveDocCache createDriveDocCache() => MemoryDriveDocCache();
