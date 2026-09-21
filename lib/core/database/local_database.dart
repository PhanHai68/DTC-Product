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
      version: 3,
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
    await _createNotesTables(db);
  }

  Future<void> _createNotesTables(Database db) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        reminderDateTime TEXT,
        reminderBeforeMinutes INTEGER NOT NULL DEFAULT 0,
        notificationId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        isCompleted INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE maintenance_records ADD COLUMN serviceType TEXT DEFAULT "Bảo hành"',
      );
    }
    if (oldVersion < 3) {
      await _createNotesTables(db);
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
