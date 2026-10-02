import 'package:sqflite/sqflite.dart';

import '../data/site_layout_database.dart';
import '../models/site_layout_models.dart';

class SiteLayoutRepository {
  SiteLayoutRepository({SiteLayoutDatabase? database})
    : _database = database ?? SiteLayoutDatabase.instance;

  final SiteLayoutDatabase _database;

  Future<List<SiteLayoutProject>> getProjects() async {
    final db = await _database.database;
    final rows = await db.query(
      'site_layout_projects',
      orderBy: 'updatedAt DESC',
    );
    return rows.map(SiteLayoutProject.fromMap).toList();
  }

  Future<SiteLayoutProject?> getProject(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'site_layout_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : SiteLayoutProject.fromMap(rows.first);
  }

  Future<SiteLayoutProject> createProject({
    required String name,
    required String customer,
    required String location,
    required String surveyor,
    required DateTime surveyDate,
    required double siteWidthMm,
    required double siteLengthMm,
    SiteDimensionUnit dimensionUnit = SiteDimensionUnit.meter,
    double? ceilingHeightMm,
    double? lowestBeamHeightMm,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final project = SiteLayoutProject(
      id: newSiteLayoutId('project'),
      name: name.trim(),
      customer: customer.trim(),
      location: location.trim(),
      surveyor: surveyor.trim(),
      surveyDate: surveyDate,
      notes: notes.trim(),
      siteWidthMm: siteWidthMm,
      siteLengthMm: siteLengthMm,
      dimensionUnit: dimensionUnit,
      ceilingHeightMm: ceilingHeightMm,
      lowestBeamHeightMm: lowestBeamHeightMm,
      createdAt: now,
      updatedAt: now,
    );
    final layout = SiteLayoutVariant(
      id: newSiteLayoutId('layout'),
      projectId: project.id,
      name: 'Phương án A',
      isPreferred: true,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('site_layout_projects', project.toMap());
      await txn.insert('site_layouts', layout.toMap());
    });
    return project;
  }

  Future<void> updateProject(SiteLayoutProject project) async {
    final db = await _database.database;
    await db.update(
      'site_layout_projects',
      project.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> deleteProject(String projectId) async {
    final db = await _database.database;
    await db.delete(
      'site_layout_projects',
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<List<SiteLayoutVariant>> getLayouts(String projectId) async {
    final db = await _database.database;
    final rows = await db.query(
      'site_layouts',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'sortOrder ASC, createdAt ASC',
    );
    return rows.map(SiteLayoutVariant.fromMap).toList();
  }

  Future<SiteLayoutVariant> createLayout(
    String projectId, {
    String? name,
  }) async {
    final layouts = await getLayouts(projectId);
    final now = DateTime.now();
    final layout = SiteLayoutVariant(
      id: newSiteLayoutId('layout'),
      projectId: projectId,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Phương án ${String.fromCharCode(65 + layouts.length)}',
      isPreferred: layouts.isEmpty,
      sortOrder: layouts.length,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _database.database;
    await db.insert('site_layouts', layout.toMap());
    await _touchProject(db, projectId);
    return layout;
  }

  Future<SiteLayoutVariant> duplicateLayout(
    SiteLayoutVariant source, {
    String? name,
  }) async {
    final layouts = await getLayouts(source.projectId);
    final now = DateTime.now();
    final duplicate = SiteLayoutVariant(
      id: newSiteLayoutId('layout'),
      projectId: source.projectId,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : '${source.name} - Bản sao',
      sortOrder: layouts.length,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('site_layouts', duplicate.toMap());
      await _copyRows(
        txn,
        table: 'site_layout_objects',
        sourceLayoutId: source.id,
        targetLayoutId: duplicate.id,
      );
      await _copyRows(
        txn,
        table: 'site_machine_placements',
        sourceLayoutId: source.id,
        targetLayoutId: duplicate.id,
      );
      await _copyRows(
        txn,
        table: 'site_measurements',
        sourceLayoutId: source.id,
        targetLayoutId: duplicate.id,
      );
      await _copyRows(
        txn,
        table: 'site_annotations',
        sourceLayoutId: source.id,
        targetLayoutId: duplicate.id,
      );
      await _copyRows(
        txn,
        table: 'site_photo_markers',
        sourceLayoutId: source.id,
        targetLayoutId: duplicate.id,
      );
      await _touchProject(txn, source.projectId);
    });
    return duplicate;
  }

  Future<void> _copyRows(
    DatabaseExecutor db, {
    required String table,
    required String sourceLayoutId,
    required String targetLayoutId,
  }) async {
    final rows = await db.query(
      table,
      where: 'layoutId = ?',
      whereArgs: [sourceLayoutId],
    );
    for (final row in rows) {
      final copy = Map<String, Object?>.from(row)
        ..['id'] = newSiteLayoutId(table)
        ..['layoutId'] = targetLayoutId;
      await db.insert(table, copy);
    }
  }

  Future<void> setPreferredLayout(String projectId, String layoutId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update(
        'site_layouts',
        {'isPreferred': 0},
        where: 'projectId = ?',
        whereArgs: [projectId],
      );
      await txn.update(
        'site_layouts',
        {'isPreferred': 1, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ? AND projectId = ?',
        whereArgs: [layoutId, projectId],
      );
      await _touchProject(txn, projectId);
    });
  }

  Future<void> deleteLayout(SiteLayoutVariant layout) async {
    final layouts = await getLayouts(layout.projectId);
    if (layouts.length <= 1) {
      throw StateError('Dự án phải có ít nhất một phương án.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('site_layouts', where: 'id = ?', whereArgs: [layout.id]);
      if (layout.isPreferred) {
        final replacement = layouts.firstWhere((item) => item.id != layout.id);
        await txn.update(
          'site_layouts',
          {'isPreferred': 1},
          where: 'id = ?',
          whereArgs: [replacement.id],
        );
      }
      await _touchProject(txn, layout.projectId);
    });
  }

  Future<SiteLayoutBundle?> getBundle(String projectId, String layoutId) async {
    final project = await getProject(projectId);
    if (project == null) return null;
    final db = await _database.database;
    final layoutRows = await db.query(
      'site_layouts',
      where: 'id = ? AND projectId = ?',
      whereArgs: [layoutId, projectId],
      limit: 1,
    );
    if (layoutRows.isEmpty) return null;
    final results = await Future.wait([
      db.query(
        'site_layout_objects',
        where: 'layoutId = ?',
        whereArgs: [layoutId],
      ),
      db.query(
        'site_machine_placements',
        where: 'layoutId = ?',
        whereArgs: [layoutId],
      ),
      db.query(
        'site_measurements',
        where: 'layoutId = ?',
        whereArgs: [layoutId],
      ),
      db.query(
        'site_annotations',
        where: 'layoutId = ?',
        whereArgs: [layoutId],
      ),
      db.query('site_photos', where: 'projectId = ?', whereArgs: [projectId]),
      db.query(
        'site_photo_markers',
        where: 'layoutId = ?',
        whereArgs: [layoutId],
      ),
    ]);
    return SiteLayoutBundle(
      project: project,
      layout: SiteLayoutVariant.fromMap(layoutRows.first),
      objects: results[0].map(SiteLayoutObject.fromMap).toList(),
      machines: results[1].map(MachinePlacement.fromMap).toList(),
      measurements: results[2].map(LayoutMeasurement.fromMap).toList(),
      annotations: results[3].map(LayoutAnnotation.fromMap).toList(),
      photos: results[4].map(SitePhoto.fromMap).toList(),
      photoMarkers: results[5].map(PhotoMarker.fromMap).toList(),
    );
  }

  Future<void> saveBundle(SiteLayoutBundle bundle) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update(
        'site_layout_projects',
        bundle.project.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [bundle.project.id],
      );
      await _replaceLayoutRows(
        txn,
        'site_layout_objects',
        bundle.layout.id,
        bundle.objects.map((item) => item.toMap()),
      );
      await _replaceLayoutRows(
        txn,
        'site_machine_placements',
        bundle.layout.id,
        bundle.machines.map((item) => item.toMap()),
      );
      await _replaceLayoutRows(
        txn,
        'site_measurements',
        bundle.layout.id,
        bundle.measurements.map((item) => item.toMap()),
      );
      await _replaceLayoutRows(
        txn,
        'site_annotations',
        bundle.layout.id,
        bundle.annotations.map((item) => item.toMap()),
      );
      await _replaceLayoutRows(
        txn,
        'site_photo_markers',
        bundle.layout.id,
        bundle.photoMarkers.map((item) => item.toMap()),
      );
    });
  }

  Future<void> _replaceLayoutRows(
    DatabaseExecutor db,
    String table,
    String layoutId,
    Iterable<Map<String, Object?>> rows,
  ) async {
    await db.delete(table, where: 'layoutId = ?', whereArgs: [layoutId]);
    for (final row in rows) {
      await db.insert(table, row);
    }
  }

  Future<void> addPhoto(SitePhoto photo) async {
    final db = await _database.database;
    await db.insert('site_photos', photo.toMap());
    await _touchProject(db, photo.projectId);
  }

  Future<void> deletePhoto(String photoId) async {
    final db = await _database.database;
    await db.delete('site_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  Future<void> _touchProject(DatabaseExecutor db, String projectId) =>
      db.update(
        'site_layout_projects',
        {'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [projectId],
      );
}
