import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _featureDirectory(String child) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(root.path, 'DTCProduct', 'LuuMau', child));
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

Future<String> persistSamplePhoto({
  required String sourcePath,
  required String fileName,
  List<int>? bytes,
}) async {
  final directory = await _featureDirectory('Photos');
  final target = p.join(directory.path, fileName);
  if (bytes != null) {
    return (await File(target).writeAsBytes(bytes, flush: true)).path;
  }
  return (await File(sourcePath).copy(target)).path;
}

Future<Uint8List?> readSamplePhoto(String storedPath) async {
  final file = File(storedPath);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<String> saveSamplePdf({
  required List<int> bytes,
  required String fileName,
}) async {
  final directory = await _featureDirectory('Exports');
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
