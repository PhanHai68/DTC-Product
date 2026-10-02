import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

class FactoryLocationDatabase {
  FactoryLocationDatabase._();
  static final FactoryLocationDatabase instance = FactoryLocationDatabase._();

  FactoryLocationDatabase.forTesting(Database database) : _database = database;

  static const currentVersion = 1;
  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'factory_location.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE factory_locations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL CHECK(latitude >= -90 AND latitude <= 90),
        longitude REAL NOT NULL CHECK(longitude >= -180 AND longitude <= 180),
        accuracy REAL,
        note TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> createSchemaForTesting(Database db) => _create(db, 1);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
