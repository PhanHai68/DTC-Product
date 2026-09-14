// Truy cập database offline của module Cân Đóng Gói.
//
// Việc mở file database được tách theo nền tảng: mobile/desktop dùng file
// SQLite cục bộ, còn trình duyệt dùng SQLite/Wasm và lưu trong IndexedDB.
import 'package:sqflite/sqflite.dart';

import 'packing_database_platform.dart'
    if (dart.library.io) 'packing_database_io.dart'
    if (dart.library.js_interop) 'packing_database_web.dart';

class PackingDatabase {
  PackingDatabase._();

  static final PackingDatabase instance = PackingDatabase._();
  static Database? _database;

  Future<Database> get database async {
    _database ??= await openPackingDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
