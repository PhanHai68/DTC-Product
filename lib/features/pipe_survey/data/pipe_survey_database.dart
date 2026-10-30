import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Khảo sát tuyến ống khí nén đã lưu. Toàn bộ khảo sát nằm trong cột `json`;
/// các cột còn lại để liệt kê / tìm nhanh.
class PipeSurveyDatabase {
  PipeSurveyDatabase._();
  PipeSurveyDatabase.forTesting(Database database) : _database = database;

  static final PipeSurveyDatabase instance = PipeSurveyDatabase._();
  static const fileName = 'pipe_survey.db';
  static const currentVersion = 1;

  Database? _database;

  Future<Database> get database async {
    return _database ??= await openLocalDatabase(
      fileName: fileName,
      version: currentVersion,
      onCreate: _create,
      onUpgrade: (db, oldVersion, newVersion) async {},
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pipe_surveys(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        customer TEXT NOT NULL DEFAULT '',
        json TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pipe_surveys_updated ON pipe_surveys(updatedAt)',
    );
  }

  Future<void> createSchemaForTesting(Database db) =>
      _create(db, currentVersion);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
