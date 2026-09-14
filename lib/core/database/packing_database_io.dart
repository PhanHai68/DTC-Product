import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _databaseName = 'packing.db';
const _databaseAssetPath = 'assets/database/packing.db';

/// Copy lại database đóng gói từ asset để các nền tảng native luôn dùng đúng
/// dữ liệu mới nhất được xuất từ Excel.
Future<Database> openPackingDatabase() async {
  final DatabaseFactory factory;
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  } else {
    factory = databaseFactorySqflitePlugin;
  }

  final databasePath = p.join(await factory.getDatabasesPath(), _databaseName);
  final data = await rootBundle.load(_databaseAssetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  final file = File(databasePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);

  return factory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(readOnly: true),
  );
}
