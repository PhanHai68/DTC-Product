import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _exportsDirectory() async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(p.join(root.path, 'DTCProduct', 'GhiChu', 'Exports'));
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

Future<String> saveNoteFile({
  required List<int> bytes,
  required String fileName,
}) async {
  final directory = await _exportsDirectory();
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> cacheNoteFileForOpen({
  required List<int> bytes,
  required String fileName,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File(p.join(tempDir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
