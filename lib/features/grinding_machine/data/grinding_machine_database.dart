import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Database riêng cho module "Máy nghiền" (Grinding Machine) — tách khỏi
/// database của các feature khác, theo đúng khuôn mẫu
/// `MaintenanceReportDatabase`/`ProjectDatabase`. Dữ liệu trong các bảng này
/// LUÔN được nạp từ file Excel/JSON nguồn (xem `GrindingMachineImporter`),
/// KHÔNG được ghi tay thông số kỹ thuật vào đây.
class GrindingMachineDatabase {
  GrindingMachineDatabase._();
  static final GrindingMachineDatabase instance = GrindingMachineDatabase._();

  /// Nguồn duy nhất cho version DB hiện tại — dùng lại ở [database] VÀ ở
  /// nơi cần hiển thị/so sánh (VD Backup Screen, Phase 11) thay vì hard-code
  /// số `5` thêm 1 chỗ nữa.
  static const currentVersion = 5;

  /// Bọc quanh 1 Database đã mở sẵn (VD sqflite_common_ffi in-memory) — chỉ
  /// dùng cho test.
  GrindingMachineDatabase.forTesting(Database database) : _database = database;

  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'grinding_machines.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE grinding_series(
        seriesCode TEXT PRIMARY KEY,
        displayCode TEXT NOT NULL DEFAULT '',
        nameVi TEXT NOT NULL DEFAULT '',
        nameEn TEXT NOT NULL DEFAULT '',
        technology TEXT NOT NULL DEFAULT '',
        pdfPages TEXT NOT NULL DEFAULT '',
        applicationVi TEXT NOT NULL DEFAULT '',
        workingPrincipleVi TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE grinding_machines(
        machineId TEXT PRIMARY KEY,
        seriesCode TEXT NOT NULL,
        model TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        pdfPage INTEGER,
        capacityMinKgH REAL,
        capacityMaxKgH REAL,
        inputSizeMaxMm REAL,
        inputSizeNote TEXT,
        finenessMin REAL,
        finenessMax REAL,
        finenessUnit TEXT,
        mainMotorKwMin REAL,
        mainMotorKwMax REAL,
        speedRpmMin REAL,
        speedRpmMax REAL,
        lengthMm REAL,
        widthMm REAL,
        heightMm REAL,
        weightKg REAL,
        sourceDocument TEXT,
        editNote TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_machines_series ON grinding_machines(seriesCode)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_machines_model ON grinding_machines(model)',
    );

    await db.execute('''
      CREATE TABLE grinding_extra_specs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        machineId TEXT NOT NULL,
        specKey TEXT NOT NULL,
        specValueNumber REAL,
        specValueText TEXT,
        unit TEXT,
        sourcePdfPage INTEGER,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_extra_specs_machine ON grinding_extra_specs(machineId)',
    );

    await db.execute('''
      CREATE TABLE grinding_selection_tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seriesCode TEXT NOT NULL,
        tag TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_selection_tags_series ON grinding_selection_tags(seriesCode)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_selection_tags_tag ON grinding_selection_tags(tag)',
    );

    await db.execute('''
      CREATE TABLE grinding_materials(
        materialId TEXT PRIMARY KEY,
        nameVi TEXT NOT NULL DEFAULT '',
        nameEn TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        hardness TEXT,
        fibrous INTEGER,
        oily INTEGER,
        stickyOrPaste INTEGER,
        wet INTEGER,
        heatSensitive INTEGER,
        brittle INTEGER,
        crystalline INTEGER,
        sourceCandidateSeries TEXT,
        sourceBasis TEXT,
        status TEXT NOT NULL DEFAULT 'Needs validation',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE grinding_material_series_map(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        materialId TEXT NOT NULL,
        seriesCode TEXT NOT NULL,
        scoreAdjustment REAL NOT NULL DEFAULT 0,
        basisType TEXT,
        reasonVi TEXT,
        sourceBasis TEXT,
        status TEXT NOT NULL DEFAULT 'Needs validation'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_material_series_map_material ON grinding_material_series_map(materialId)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_material_series_map_series ON grinding_material_series_map(seriesCode)',
    );

    await db.execute('''
      CREATE TABLE grinding_ai_config(
        key TEXT PRIMARY KEY,
        value TEXT,
        unit TEXT,
        category TEXT,
        description TEXT,
        editable INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Key-value nhỏ lưu databaseVersion/sourceDocument của lần import gần
    // nhất — dùng để biết khi nào cần import lại sau khi thay Excel/JSON.
    await db.execute('''
      CREATE TABLE grinding_db_meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _createProjectTables(db);
    await _createProposalTables(db);
  }

  /// Bảng cho workflow "Engineering Project" (Phase 7) — domain RIÊNG với
  /// catalog máy nghiền ở trên, KHÔNG bị xóa/ghi đè khi `importSnapshot`
  /// replace-all catalog (xem GrindingMachineRepository.importSnapshot: chỉ
  /// delete 7 bảng catalog, không đụng 2 bảng này).
  Future<void> _createProjectTables(Database db) async {
    // Đã gồm sẵn cột follow-up (Phase 10, mục 15) ngay từ đầu — cài mới từ
    // v5 KHÔNG cần ALTER TABLE, chỉ database đang ở v2-v4 thật (đã có bảng
    // này TRƯỚC khi 2 cột này tồn tại) mới cần `_addProjectFollowUpColumns`.
    await db.execute('''
      CREATE TABLE grinding_selection_projects(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectName TEXT NOT NULL,
        customerName TEXT,
        contactName TEXT,
        contactInfo TEXT,
        materialId TEXT,
        materialName TEXT,
        requiredCapacityKgH REAL,
        requiredFinenessValue REAL,
        requiredFinenessUnit TEXT,
        feedSizeMm REAL,
        maxMotorKw REAL,
        application TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        nextFollowUpAt TEXT,
        followUpNote TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE grinding_selection_project_machines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectId INTEGER NOT NULL,
        machineId TEXT NOT NULL,
        role TEXT NOT NULL,
        addedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_selection_project_machines_project '
      'ON grinding_selection_project_machines(projectId)',
    );
  }

  /// Bảng cho "Technical Proposal / Quotation" (Phase 8) — domain RIÊNG với
  /// cả catalog máy LẪN Engineering Project (chỉ tham chiếu qua
  /// `projectId`). `technicalSnapshotJson` chỉ được ghi 1 LẦN tại thời điểm
  /// Finalize — không bị đụng bởi `importSnapshot` replace-all catalog phía
  /// trên, đúng yêu cầu "Final Proposal không đổi khi database máy update".
  Future<void> _createProposalTables(Database db) async {
    // Đã gồm sẵn cột revision chain (Phase 9, mục 3-4) ngay từ đầu — cài mới
    // từ v4 KHÔNG cần ALTER TABLE, chỉ database đang ở v3 thật (đã có bảng
    // này TRƯỚC khi các cột này tồn tại) mới cần `_addProposalRevisionColumns`.
    // `proposalNumber` KHÔNG còn UNIQUE (khác Phase 8) vì mọi revision trong
    // 1 chain (R0, R1, R2...) dùng CHUNG 1 proposalNumber (mục 3) — tính duy
    // nhất thật sự nằm ở UNIQUE(rootProposalId, revision) bên dưới.
    await db.execute('''
      CREATE TABLE grinding_proposals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectId INTEGER NOT NULL,
        proposalNumber TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        currency TEXT NOT NULL DEFAULT 'VND',
        machineId TEXT,
        machineUnitPrice REAL,
        machineQuantity REAL,
        discount REAL,
        vatPercent REAL,
        notes TEXT,
        technicalSnapshotJson TEXT,
        rootProposalId INTEGER,
        revision INTEGER NOT NULL DEFAULT 0,
        validityDays INTEGER,
        deliveryTime TEXT,
        warranty TEXT,
        paymentTerms TEXT,
        sentAt TEXT,
        acceptedAt TEXT,
        rejectedAt TEXT,
        responseNote TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        finalizedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_proposals_project ON grinding_proposals(projectId)',
    );
    await _createProposalChainIndex(db);

    await db.execute('''
      CREATE TABLE grinding_proposal_line_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proposalId INTEGER NOT NULL,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity REAL,
        unitPrice REAL,
        note TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_proposal_line_items_proposal '
      'ON grinding_proposal_line_items(proposalId)',
    );
  }

  /// Chặn 2 revision trùng số trong cùng chain (Phase 9, mục 32) — Repository
  /// vẫn tự tính `MAX(revision)+1` trong transaction, index này chỉ là lưới
  /// an toàn cuối nếu có race.
  Future<void> _createProposalChainIndex(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX idx_grinding_proposals_chain_revision '
      'ON grinding_proposals(rootProposalId, revision)',
    );
  }

  /// Database ĐÃ ở v3 thật (bảng `grinding_proposals` tồn tại từ TRƯỚC khi
  /// các cột revision chain được thêm, VÀ có UNIQUE constraint cũ trên
  /// `proposalNumber`) — ALTER TABLE ADD COLUMN không bỏ được UNIQUE constraint
  /// đã có sẵn trên cột, nên phải rebuild bảng theo đúng quy trình chuẩn của
  /// SQLite: tạo bảng mới đúng schema v4 (không UNIQUE proposalNumber), copy
  /// toàn bộ dữ liệu cũ sang kèm backfill `rootProposalId = id` (mỗi proposal
  /// Phase 8 cũ là R0 độc lập của chính nó — mục 30), xoá bảng cũ, đổi tên.
  Future<void> _addProposalRevisionColumns(Database db) async {
    await db.execute(
      'ALTER TABLE grinding_proposals RENAME TO grinding_proposals_old',
    );
    await db.execute('''
      CREATE TABLE grinding_proposals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectId INTEGER NOT NULL,
        proposalNumber TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        currency TEXT NOT NULL DEFAULT 'VND',
        machineId TEXT,
        machineUnitPrice REAL,
        machineQuantity REAL,
        discount REAL,
        vatPercent REAL,
        notes TEXT,
        technicalSnapshotJson TEXT,
        rootProposalId INTEGER,
        revision INTEGER NOT NULL DEFAULT 0,
        validityDays INTEGER,
        deliveryTime TEXT,
        warranty TEXT,
        paymentTerms TEXT,
        sentAt TEXT,
        acceptedAt TEXT,
        rejectedAt TEXT,
        responseNote TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        finalizedAt TEXT
      )
    ''');
    await db.execute('''
      INSERT INTO grinding_proposals (
        id, projectId, proposalNumber, status, currency, machineId,
        machineUnitPrice, machineQuantity, discount, vatPercent, notes,
        technicalSnapshotJson, rootProposalId, revision, createdAt, updatedAt,
        finalizedAt
      )
      SELECT
        id, projectId, proposalNumber, status, currency, machineId,
        machineUnitPrice, machineQuantity, discount, vatPercent, notes,
        technicalSnapshotJson, id, revision, createdAt, updatedAt, finalizedAt
      FROM grinding_proposals_old
    ''');
    await db.execute('DROP TABLE grinding_proposals_old');
    await db.execute(
      'CREATE INDEX idx_grinding_proposals_project ON grinding_proposals(projectId)',
    );
    await _createProposalChainIndex(db);
  }

  /// Database ĐÃ ở v2-v4 thật (bảng `grinding_selection_projects` tồn tại từ
  /// TRƯỚC khi 2 cột follow-up được thêm) — ALTER TABLE ADD COLUMN đơn giản,
  /// không có UNIQUE constraint nào cần rebuild (khác trường hợp
  /// `proposalNumber` ở Phase 9).
  Future<void> _addProjectFollowUpColumns(Database db) async {
    await db.execute(
      'ALTER TABLE grinding_selection_projects ADD COLUMN nextFollowUpAt TEXT',
    );
    await db.execute(
      'ALTER TABLE grinding_selection_projects ADD COLUMN followUpNote TEXT',
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Bảng chưa từng tồn tại -> tạo thẳng với schema v5 đầy đủ, không cần
      // ALTER TABLE nữa.
      await _createProjectTables(db);
    } else if (oldVersion < 5) {
      // Bảng đã tồn tại từ 1 lần cài v2-v4 thật (thiếu cột follow-up).
      await _addProjectFollowUpColumns(db);
    }
    if (oldVersion < 3) {
      // Bảng chưa từng tồn tại -> tạo thẳng với schema v4 đầy đủ, không cần
      // ALTER TABLE nữa.
      await _createProposalTables(db);
    } else if (oldVersion < 4) {
      // Bảng đã tồn tại từ 1 lần cài v3 thật (thiếu cột revision chain).
      await _addProposalRevisionColumns(db);
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Tạo schema hiện tại trên 1 database cô lập dùng cho test.
  Future<void> createSchemaForTesting(Database db) => _create(db, 1);

  /// Chạy migration trên 1 database cô lập dùng cho test.
  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _upgrade(db, oldVersion, newVersion);
}
