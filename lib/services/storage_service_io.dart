import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/stored_file.dart';

const Map<String, String> _featureLabels = {
  'GhiChu': 'Ghi chú & Nhắc hẹn',
  'LuuMau': 'Lưu mẫu',
  'Projects': 'Project Timeline',
};

Future<Directory> _savedFilesRoot() async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(documents.path, 'DTCProduct'));
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

String _featureLabelFor(String rootPath, String filePath) {
  final relative = p.relative(filePath, from: rootPath);
  final firstSegment = p.split(relative).first;
  return _featureLabels[firstSegment] ?? 'Khác';
}

class StorageScanResult {
  const StorageScanResult({required this.files, required this.cacheBytes});

  final List<StoredFile> files;
  final int cacheBytes;
}

Future<StorageScanResult> scanStorage() async {
  final root = await _savedFilesRoot();
  final files = <StoredFile>[];

  if (await root.exists()) {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      final extension = p.extension(entity.path);
      files.add(
        StoredFile(
          filePath: entity.path,
          fileName: p.basename(entity.path),
          extension: extension,
          category: StoredFileCategory.fromExtension(extension),
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          featureLabel: _featureLabelFor(root.path, entity.path),
        ),
      );
    }
  }
  files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  final cacheBytes = await _directorySize(await getTemporaryDirectory());
  return StorageScanResult(files: files, cacheBytes: cacheBytes);
}

Future<int> _directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  await for (final entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += await entity.length();
      } catch (_) {
        // File có thể đã bị xóa song song (ví dụ OS tự dọn cache) — bỏ qua.
      }
    }
  }
  return total;
}

/// Xóa toàn bộ nội dung thư mục cache tạm (getTemporaryDirectory), trả về số
/// byte đã giải phóng. Thư mục Documents/DTCProduct (ghi chú, dự án, lưu
/// mẫu...) không nằm trong phạm vi này nên không bao giờ bị ảnh hưởng.
Future<int> clearAppCache() async {
  final tempDir = await getTemporaryDirectory();
  if (!await tempDir.exists()) return 0;
  final freed = await _directorySize(tempDir);
  await for (final entity in tempDir.list(followLinks: false)) {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      // Bỏ qua file đang được hệ thống/plugin khác giữ, không làm crash.
    }
  }
  return freed;
}

Future<bool> _isInsideSavedFilesRoot(String filePath) async {
  final root = await _savedFilesRoot();
  final normalizedRoot = p.normalize(root.path);
  final normalizedFile = p.normalize(filePath);
  return p.isWithin(normalizedRoot, normalizedFile);
}

Future<bool> deleteStoredFile(String filePath) async {
  if (!await _isInsideSavedFilesRoot(filePath)) return false;
  final file = File(filePath);
  if (!await file.exists()) return false;
  await file.delete();
  return true;
}

Future<String?> renameStoredFile(String filePath, String newBaseName) async {
  if (!await _isInsideSavedFilesRoot(filePath)) return null;
  final file = File(filePath);
  if (!await file.exists()) return null;
  final trimmed = newBaseName.trim();
  if (trimmed.isEmpty) return null;
  final extension = p.extension(filePath);
  final targetPath = p.join(p.dirname(filePath), '$trimmed$extension');
  if (targetPath == filePath) return filePath;
  if (await File(targetPath).exists()) return null;
  final renamed = await file.rename(targetPath);
  return renamed.path;
}

Future<void> shareStoredFile(StoredFile file) {
  return SharePlus.instance.share(
    ShareParams(files: [XFile(file.filePath, mimeType: file.category.mimeType)]),
  );
}

Future<void> openStoredFileExternally(String filePath) {
  return OpenFile.open(filePath);
}
