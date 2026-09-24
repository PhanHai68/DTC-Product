import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class GrindingImportFile {
  const GrindingImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class GrindingDatabaseFilePicker {
  const GrindingDatabaseFilePicker();

  Future<GrindingImportFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'json'],
      withData: true,
      dialogTitle: 'Chọn database Máy nghiền',
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return GrindingImportFile(
      file.name,
      file.bytes ?? await file.xFile.readAsBytes(),
    );
  }
}
