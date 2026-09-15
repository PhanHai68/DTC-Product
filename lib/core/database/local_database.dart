import 'package:sqflite/sqflite.dart';

import '../../models/maintenance_record.dart';
import 'local_database_factory.dart'
    if (dart.library.io) 'local_database_factory_io.dart'
    if (dart.library.js_interop) 'local_database_factory_web.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('user_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    return openLocalDatabase(
      fileName: filePath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE maintenance_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        machineModel TEXT NOT NULL,
        installDate TEXT NOT NULL,
        maintenanceCycleMonths INTEGER NOT NULL,
        nextMaintenanceDate TEXT NOT NULL,
        serviceType TEXT DEFAULT 'Bảo hành',
        notes TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE maintenance_records ADD COLUMN serviceType TEXT DEFAULT "Bảo hành"',
      );
    }
  }

  Future<int> insertMaintenanceRecord(MaintenanceRecord record) async {
    final db = await instance.database;
    return await db.insert('maintenance_records', record.toMap());
  }

  Future<int> updateMaintenanceRecord(MaintenanceRecord record) async {
    final db = await instance.database;
    return await db.update(
      'maintenance_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteMaintenanceRecord(int id) async {
    final db = await instance.database;
    return await db.delete(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MaintenanceRecord>> getAllMaintenanceRecords() async {
    final db = await instance.database;
    final result = await db.query(
      'maintenance_records',
      orderBy: 'nextMaintenanceDate ASC',
    );
    return result.map((map) => MaintenanceRecord.fromMap(map)).toList();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
