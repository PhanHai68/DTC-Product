import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/stored_file.dart';
import '../services/storage_service.dart'
    if (dart.library.io) '../services/storage_service_io.dart'
    if (dart.library.js_interop) '../services/storage_service_web.dart';

enum StorageFilter { all, pdf, image, model3d, other }

class StorageProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<StoredFile> _allFiles = [];
  List<StoredFile> get allFiles => _allFiles;
  int _cacheBytes = 0;

  StorageFilter _filter = StorageFilter.all;
  StorageFilter get filter => _filter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StorageUsageSummary get summary => StorageUsageSummary(
    pdfBytes: _bytesForCategory(StoredFileCategory.pdf),
    imageBytes: _bytesForCategory(StoredFileCategory.image),
    model3dBytes: _bytesForCategory(StoredFileCategory.model3d),
    otherBytes: _bytesForCategory(StoredFileCategory.other),
    cacheBytes: _cacheBytes,
    fileCount: _allFiles.length,
  );

  int _bytesForCategory(StoredFileCategory category) => _allFiles
      .where((file) => file.category == category)
      .fold(0, (sum, file) => sum + file.sizeBytes);

  List<StoredFile> get files {
    Iterable<StoredFile> result = _allFiles;
    switch (_filter) {
      case StorageFilter.all:
        break;
      case StorageFilter.pdf:
        result = result.where((f) => f.category == StoredFileCategory.pdf);
      case StorageFilter.image:
        result = result.where((f) => f.category == StoredFileCategory.image);
      case StorageFilter.model3d:
        result = result.where((f) => f.category == StoredFileCategory.model3d);
      case StorageFilter.other:
        result = result.where((f) => f.category == StoredFileCategory.other);
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((f) => f.fileName.toLowerCase().contains(query));
    }
    return result.toList();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await scanStorage();
      _allFiles = result.files;
      _cacheBytes = result.cacheBytes;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(StorageFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<bool> deleteFile(StoredFile file) async {
    final success = await deleteStoredFile(file.filePath);
    if (success) {
      _allFiles = _allFiles.where((f) => f.filePath != file.filePath).toList();
      notifyListeners();
    }
    return success;
  }

  /// Xóa nhiều file cùng lúc, trả về số file đã xóa thành công.
  Future<int> deleteFiles(Iterable<StoredFile> files) async {
    var deletedCount = 0;
    final deletedPaths = <String>{};
    for (final file in files) {
      if (await deleteStoredFile(file.filePath)) {
        deletedCount++;
        deletedPaths.add(file.filePath);
      }
    }
    if (deletedPaths.isNotEmpty) {
      _allFiles = _allFiles.where((f) => !deletedPaths.contains(f.filePath)).toList();
      notifyListeners();
    }
    return deletedCount;
  }

  Future<bool> renameFile(StoredFile file, String newBaseName) async {
    final newPath = await renameStoredFile(file.filePath, newBaseName);
    if (newPath == null) return false;
    final index = _allFiles.indexWhere((f) => f.filePath == file.filePath);
    if (index != -1) {
      _allFiles[index] = StoredFile(
        filePath: newPath,
        fileName: p.basename(newPath),
        extension: file.extension,
        category: file.category,
        sizeBytes: file.sizeBytes,
        modifiedAt: file.modifiedAt,
        featureLabel: file.featureLabel,
      );
      notifyListeners();
    }
    return true;
  }

  Future<int> clearCache() async {
    final freed = await clearAppCache();
    _cacheBytes = 0;
    notifyListeners();
    return freed;
  }

  Future<void> shareFile(StoredFile file) => shareStoredFile(file);

  Future<void> openFileExternally(StoredFile file) =>
      openStoredFileExternally(file.filePath);
}
