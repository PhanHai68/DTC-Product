import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'drive_doc_cache.dart';

DriveDocCache createDriveDocCache() => FileDriveDocCache();

/// Lưu `<id>__<version>.bin` trong thư mục hỗ trợ của app.
class FileDriveDocCache implements DriveDocCache {
  FileDriveDocCache({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;
  Directory? _dir;

  Future<Directory> _cacheDir() async {
    final dir = _dir ??= Directory('${(await _baseDir()).path}/drive_docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> _filesOf(String id) async {
    final dir = await _cacheDir();
    return dir.listSync().whereType<File>().where((f) {
      final name = f.uri.pathSegments.last;
      return name.startsWith('${id}__') && name.endsWith('.bin');
    }).toList();
  }

  @override
  Future<Uint8List?> read(String id, String version) async {
    final file = File('${(await _cacheDir()).path}/${id}__$version.bin');
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<Uint8List?> readAny(String id) async {
    final files = await _filesOf(id);
    return files.isEmpty ? null : files.first.readAsBytes();
  }

  @override
  Future<void> write(String id, String version, Uint8List bytes) async {
    final dir = await _cacheDir();
    final target = File('${dir.path}/${id}__$version.bin');
    // Ghi file tạm rồi đổi tên để không để lại file dở dang khi app bị tắt.
    final temp = File('${target.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    for (final old in await _filesOf(id)) {
      await old.delete();
    }
    await temp.rename(target.path);
  }
}
