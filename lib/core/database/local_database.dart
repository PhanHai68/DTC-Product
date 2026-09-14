import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/maintenance_record.dart';

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
    final DatabaseFactory factory;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactorySqflitePlugin;
    }

    final dbPath = await factory.getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
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
      await db.execute('ALTER TABLE maintenance_records ADD COLUMN serviceType TEXT DEFAULT "Bảo hành"');
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
}
