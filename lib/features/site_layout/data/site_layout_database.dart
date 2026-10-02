import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

class SiteLayoutDatabase {
  SiteLayoutDatabase._();
  SiteLayoutDatabase.forTesting(Database database) : _database = database;

  static final SiteLayoutDatabase instance = SiteLayoutDatabase._();
  static const currentVersion = 4;

  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'site_layout.db',
      version: currentVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    await _database!.execute('PRAGMA foreign_keys = ON');
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE site_layout_projects(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        customer TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        surveyor TEXT NOT NULL DEFAULT '',
        surveyDate TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        siteWidthMm REAL NOT NULL CHECK(siteWidthMm > 0),
        siteLengthMm REAL NOT NULL CHECK(siteLengthMm > 0),
        ceilingHeightMm REAL,
        lowestBeamHeightMm REAL,
        dimensionTextScale REAL NOT NULL DEFAULT 1.5,
        dimensionUnit TEXT NOT NULL DEFAULT 'meter',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE site_layouts(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        name TEXT NOT NULL,
        isPreferred INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY(projectId) REFERENCES site_layout_projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_site_layouts_project ON site_layouts(projectId, sortOrder)',
    );
    await db.execute('''
      CREATE TABLE site_layout_objects(
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        type TEXT NOT NULL,
        xMm REAL NOT NULL,
        yMm REAL NOT NULL,
        widthMm REAL NOT NULL CHECK(widthMm > 0),
        lengthMm REAL NOT NULL CHECK(lengthMm > 0),
        rotationDeg REAL NOT NULL DEFAULT 0,
        isLocked INTEGER NOT NULL DEFAULT 0,
        zIndex INTEGER NOT NULL DEFAULT 0,
        label TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(layoutId) REFERENCES site_layouts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_site_objects_layout ON site_layout_objects(layoutId)',
    );
    await db.execute('''
      CREATE TABLE site_machine_placements(
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        sourceType TEXT NOT NULL,
        sourceId TEXT NOT NULL,
        category TEXT NOT NULL,
        model TEXT NOT NULL,
        displayName TEXT NOT NULL,
        imagePath TEXT,
        xMm REAL NOT NULL,
        yMm REAL NOT NULL,
        rotationDeg REAL NOT NULL DEFAULT 0,
        isLocked INTEGER NOT NULL DEFAULT 0,
        zIndex INTEGER NOT NULL DEFAULT 0,
        lengthMm REAL NOT NULL CHECK(lengthMm > 0),
        widthMm REAL NOT NULL CHECK(widthMm > 0),
        heightMm REAL NOT NULL CHECK(heightMm > 0),
        clearanceFrontMm REAL NOT NULL DEFAULT 0,
        clearanceRearMm REAL NOT NULL DEFAULT 0,
        clearanceLeftMm REAL NOT NULL DEFAULT 0,
        clearanceRightMm REAL NOT NULL DEFAULT 0,
        clearanceTopMm REAL NOT NULL DEFAULT 0,
        clearanceVerified INTEGER NOT NULL DEFAULT 0,
        floorToBaseMm REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(layoutId) REFERENCES site_layouts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_site_machines_layout ON site_machine_placements(layoutId)',
    );
    await db.execute('''
      CREATE TABLE site_measurements(
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        x1Mm REAL NOT NULL,
        y1Mm REAL NOT NULL,
        x2Mm REAL NOT NULL,
        y2Mm REAL NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(layoutId) REFERENCES site_layouts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE site_annotations(
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        xMm REAL NOT NULL,
        yMm REAL NOT NULL,
        text TEXT NOT NULL,
        markerNumber INTEGER,
        FOREIGN KEY(layoutId) REFERENCES site_layouts(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE site_photos(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        originalPath TEXT NOT NULL,
        thumbnailPath TEXT,
        caption TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        capturedAt TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(projectId) REFERENCES site_layout_projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_site_photos_project ON site_photos(projectId)',
    );
    await db.execute('''
      CREATE TABLE site_photo_markers(
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        photoId TEXT NOT NULL,
        markerNumber INTEGER NOT NULL,
        xMm REAL NOT NULL,
        yMm REAL NOT NULL,
        UNIQUE(layoutId, markerNumber),
        FOREIGN KEY(layoutId) REFERENCES site_layouts(id) ON DELETE CASCADE,
        FOREIGN KEY(photoId) REFERENCES site_photos(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(
        'ALTER TABLE site_layout_objects ADD COLUMN isLocked INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE site_layout_objects ADD COLUMN zIndex INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE site_machine_placements ADD COLUMN isLocked INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE site_machine_placements ADD COLUMN zIndex INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await db.execute(
        'ALTER TABLE site_layout_projects ADD COLUMN dimensionTextScale REAL NOT NULL DEFAULT 1.5',
      );
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await db.execute(
        "ALTER TABLE site_layout_projects ADD COLUMN dimensionUnit TEXT NOT NULL DEFAULT 'meter'",
      );
    }
  }

  Future<void> createSchemaForTesting(Database db) =>
      _create(db, currentVersion);

  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _upgrade(db, oldVersion, newVersion);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
