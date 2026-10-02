import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

class SalesGoalDatabase {
  SalesGoalDatabase._();
  static final SalesGoalDatabase instance = SalesGoalDatabase._();

  SalesGoalDatabase.forTesting(Database database) : _database = database;

  static const currentVersion = 1;
  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'sales_goal.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sales_targets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periodType TEXT NOT NULL,
        year INTEGER NOT NULL,
        periodNumber INTEGER NOT NULL,
        targetAmount INTEGER NOT NULL CHECK(targetAmount >= 0),
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        UNIQUE(periodType, year, periodNumber)
      )
    ''');
    await db.execute('''
      CREATE TABLE sales_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleDate TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        customerOrProject TEXT NOT NULL DEFAULT '',
        productOrMachine TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sales_entries_date ON sales_entries(saleDate)',
    );
    await db.execute('''
      CREATE TABLE sales_opportunities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerOrProject TEXT NOT NULL,
        productOrMachine TEXT NOT NULL DEFAULT '',
        estimatedValue INTEGER NOT NULL CHECK(estimatedValue > 0),
        probability INTEGER NOT NULL CHECK(probability >= 0 AND probability <= 100),
        expectedCloseDate TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sales_opportunities_status_date '
      'ON sales_opportunities(status, expectedCloseDate)',
    );
    await db.execute('''
      CREATE TABLE sales_focus_tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        focusDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sales_focus_tasks_date ON sales_focus_tasks(focusDate)',
    );
    await db.execute('''
      CREATE TABLE sales_milestones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        milestone INTEGER NOT NULL,
        achievedAt TEXT NOT NULL,
        UNIQUE(year, month, milestone)
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
