import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class GrindingImportFile {
  const GrindingImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class GrindingDatabaseFilePicker {
  const GrindingDatabaseFilePicker();

  Future<GrindingImportFile?> pick() async {
    final typeGroup = XTypeGroup(
      label: 'Database',
      extensions: ['xlsx', 'json'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    return GrindingImportFile(file.name, await file.readAsBytes());
  }
}
