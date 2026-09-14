import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const _databaseName = 'packing.db';
const _databaseAssetPath = 'assets/database/packing.db';

/// Nạp database SQLite có sẵn vào bộ nhớ bền vững của trình duyệt, sau đó mở
/// ở chế độ chỉ đọc. Database vẫn là nguồn được tạo từ Excel, không phải dữ
/// liệu được hard-code lại cho riêng web.
Future<Database> openPackingDatabase() async {
  final data = await rootBundle.load(_databaseAssetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final factory = databaseFactoryFfiWeb;

  await factory.writeDatabaseBytes(_databaseName, bytes);
  return factory.openDatabase(
    _databaseName,
    options: OpenDatabaseOptions(readOnly: true),
  );
}
