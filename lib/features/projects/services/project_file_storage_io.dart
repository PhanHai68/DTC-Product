import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> persistProjectFile({
  required String projectId,
  required String sourcePath,
  required String fileName,
  List<int>? bytes,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    path.join(root.path, 'DTCProduct', 'Projects', projectId, 'Attachments'),
  );
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final target = path.join(directory.path, fileName);
  if (bytes != null) {
    return (await File(target).writeAsBytes(bytes, flush: true)).path;
  }
  return (await File(sourcePath).copy(target)).path;
}

Future<Uint8List?> readProjectFile(String storedPath) async {
  final file = File(storedPath);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<String> saveProjectReport({
  required String projectId,
  required List<int> bytes,
  required String fileName,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    path.join(root.path, 'DTCProduct', 'Projects', projectId, 'Reports'),
  );
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return (await File(
    path.join(directory.path, fileName),
  ).writeAsBytes(bytes, flush: true)).path;
}
