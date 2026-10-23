import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Database cục bộ `technical_dictionary.db`: chỉ chứa dữ liệu riêng của
/// người dùng (trạng thái học, ghi chú). Bản thân từ điển nằm trong asset.
class TechnicalDictionaryDatabase {
  TechnicalDictionaryDatabase._();
  static final TechnicalDictionaryDatabase instance =
      TechnicalDictionaryDatabase._();

  TechnicalDictionaryDatabase.forTesting(Database database)
    : _database = database;

  static const currentVersion = 1;
  static const progressTable = 'term_progress';
  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'technical_dictionary.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    // `term_key` là thuật ngữ tiếng Anh viết thường (TechnicalTerm.key).
    await db.execute('''
      CREATE TABLE $progressTable(
        term_key TEXT PRIMARY KEY,
        status TEXT CHECK(status IS NULL OR status IN ('learning', 'learned')),
        note TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
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
