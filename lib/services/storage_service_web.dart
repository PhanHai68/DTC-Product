import '../models/stored_file.dart';

/// Trên web không có hệ thống file cục bộ kiểu Documents/DTCProduct nên
/// không có gì để quét — trả về danh sách rỗng thay vì báo lỗi.
class StorageScanResult {
  const StorageScanResult({required this.files, required this.cacheBytes});

  final List<StoredFile> files;
  final int cacheBytes;
}

Future<StorageScanResult> scanStorage() async =>
    const StorageScanResult(files: [], cacheBytes: 0);

Future<int> clearAppCache() async => 0;

Future<bool> deleteStoredFile(String filePath) async => false;

Future<String?> renameStoredFile(String filePath, String newBaseName) async => null;

Future<void> shareStoredFile(StoredFile file) async {}

Future<void> openStoredFileExternally(String filePath) async {}
