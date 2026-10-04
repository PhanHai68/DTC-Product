import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Cách tìm kiếm toàn văn đang dùng. SQLite trên Android thường chỉ có FTS4,
/// iOS có FTS5 — nên dò lúc tạo database và nhớ lại trong bảng `meta`.
enum FaultSearchMode { fts5, fts4, like }

/// Database cục bộ `fault_bank.db` của Ngân hàng lỗi (offline hoàn toàn).
class FaultBankDatabase {
  FaultBankDatabase._();
  static final FaultBankDatabase instance = FaultBankDatabase._();

  FaultBankDatabase.forTesting(Database database) : _database = database;

  static const currentVersion = 1;
  static const searchTable = 'fault_search';

  Database? _database;
  FaultSearchMode? _searchMode;

  /// Mở database và nạp luôn chế độ tìm kiếm vào bộ nhớ — để [searchMode]
  /// không phải truy vấn khi đang ở trong transaction (sẽ bị khóa chờ).
  Future<Database> get database async {
    final db = _database ??= await openLocalDatabase(
      fileName: 'fault_bank.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    if (_searchMode == null) {
      final rows = await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['search_mode'],
      );
      final value = rows.isEmpty ? null : rows.first['value'] as String?;
      _searchMode = FaultSearchMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => FaultSearchMode.like,
      );
    }
    return db;
  }

  /// Chế độ tìm kiếm đã chọn khi tạo database. Gọi [database] trước khi mở
  /// transaction (repository luôn làm vậy) thì hàm này không truy vấn.
  Future<FaultSearchMode> searchMode() async {
    final cached = _searchMode;
    if (cached != null) return cached;
    await database;
    return _searchMode!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE profile(
        id INTEGER PRIMARY KEY CHECK(id = 1),
        engineer_name TEXT NOT NULL,
        engineer_code TEXT NOT NULL,
        default_email TEXT,
        monthly_reminder_day INTEGER
          CHECK(monthly_reminder_day IS NULL
            OR (monthly_reminder_day >= 1 AND monthly_reminder_day <= 28)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE machine_models(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        manufacturer TEXT,
        equipment_group TEXT,
        name_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // `seq` chỉ dùng nội bộ làm rowid cho bảng FTS; khóa thật là `id`.
    await db.execute('''
      CREATE TABLE fault_records(
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT NOT NULL UNIQUE,
        machine_model_id TEXT NOT NULL REFERENCES machine_models(id),
        serial_number TEXT,
        error_code TEXT,
        fault_group TEXT,
        symptom TEXT NOT NULL,
        cause TEXT NOT NULL,
        parts TEXT,
        tools TEXT,
        duration_minutes INTEGER CHECK(duration_minutes IS NULL OR duration_minutes >= 0),
        safety_warning TEXT,
        author_code TEXT NOT NULL,
        author_name TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'mine' CHECK(source IN ('mine', 'imported')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0, 1)),
        search_text TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_fault_records_model ON fault_records(machine_model_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fault_records_updated ON fault_records(updated_at)',
    );
    await db.execute('''
      CREATE TABLE solution_steps(
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL REFERENCES fault_records(id),
        step_order INTEGER NOT NULL,
        content TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_solution_steps_record ON solution_steps(record_id)',
    );
    await db.execute('''
      CREATE TABLE attachments(
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL REFERENCES fault_records(id),
        step_id TEXT,
        file_name TEXT NOT NULL,
        caption TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attachments_record ON attachments(record_id)',
    );
    // Giai đoạn 2/3 — tạo sẵn, chưa dùng.
    await db.execute('''
      CREATE TABLE export_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        period_from TEXT,
        period_to TEXT,
        file_name TEXT NOT NULL,
        record_count INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE import_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        file_name TEXT NOT NULL,
        source_engineer_code TEXT,
        inserted_count INTEGER NOT NULL DEFAULT 0,
        updated_count INTEGER NOT NULL DEFAULT 0,
        skipped_count INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');

    final mode = await _createSearchTable(db);
    await db.insert('meta', {'key': 'search_mode', 'value': mode.name});
  }

  /// Thử FTS5, rồi FTS4; không có cả hai thì tìm bằng LIKE trên
  /// `fault_records.search_text` (cột đã bỏ dấu).
  static Future<FaultSearchMode> _createSearchTable(Database db) async {
    for (final mode in [FaultSearchMode.fts5, FaultSearchMode.fts4]) {
      try {
        await db.execute(
          'CREATE VIRTUAL TABLE $searchTable USING ${mode.name}(search_text)',
        );
        return mode;
      } on DatabaseException {
        // Bản SQLite trên máy không có module này — thử cách tiếp theo.
      }
    }
    return FaultSearchMode.like;
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {}

  /// Tạo schema trên database test. [forceLikeSearch] bỏ qua FTS để test
  /// nhánh LIKE (giống máy không có FTS).
  Future<void> createSchemaForTesting(
    Database db, {
    bool forceLikeSearch = false,
  }) async {
    if (!forceLikeSearch) return _create(db, currentVersion);
    await _create(db, currentVersion);
    await db.execute('DROP TABLE IF EXISTS $searchTable');
    await db.update('meta', {
      'value': FaultSearchMode.like.name,
    }, where: "key = 'search_mode'");
    _searchMode = null;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _searchMode = null;
  }
}
