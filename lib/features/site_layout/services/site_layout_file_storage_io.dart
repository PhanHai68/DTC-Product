import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _projectDirectory(String projectId) async {
  final root = await getApplicationDocumentsDirectory();
  return Directory(p.join(root.path, 'DTCProduct', 'SiteLayout', projectId));
}

Future<String> saveSiteLayoutPhoto({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  bool thumbnail = false,
}) async {
  final root = await _projectDirectory(projectId);
  final folder = Directory(
    p.join(root.path, 'photos', thumbnail ? 'thumbnails' : 'original'),
  );
  await folder.create(recursive: true);
  final file = File(p.join(folder.path, p.basename(fileName)));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> saveSiteLayoutExport({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final root = await _projectDirectory(projectId);
  final type = mimeType == 'application/pdf' ? 'pdf' : 'png';
  final folder = Directory(p.join(root.path, 'exports', type));
  await folder.create(recursive: true);
  final file = File(p.join(folder.path, p.basename(fileName)));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readSiteLayoutFile(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> deleteSiteLayoutFile(String path) async {
  final root = await getApplicationDocumentsDirectory();
  final allowed = p
      .normalize(p.join(root.path, 'DTCProduct', 'SiteLayout'))
      .toLowerCase();
  final target = p.normalize(File(path).absolute.path).toLowerCase();
  if (!p.isWithin(allowed, target)) {
    throw StateError('Không thể xóa tệp nằm ngoài thư mục SiteLayout.');
  }
  final file = File(path);
  if (await file.exists()) await file.delete();
}
