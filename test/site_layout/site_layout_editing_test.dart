import 'dart:math' as math;

import 'package:dtc_product/features/site_layout/data/site_layout_database.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/providers/site_layout_provider.dart';
import 'package:dtc_product/features/site_layout/repositories/site_layout_repository.dart';
import 'package:dtc_product/features/site_layout/services/layout_geometry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('model tương thích dữ liệu cũ', () {
    test('field edit mới có default an toàn khi bản ghi cũ chưa có', () {
      final object = SiteLayoutObject.fromMap({
        'id': 'old_object',
        'layoutId': 'layout_1',
        'type': 'column',
        'xMm': 1000,
        'yMm': 1250,
        'widthMm': 500,
        'lengthMm': 600,
        'rotationDeg': 90,
      });

      expect(object.rotationDeg, 90.0);
      expect(object.isLocked, isFalse);
      expect(object.zIndex, 0);
    });

    test('project cũ dùng cỡ chữ kích thước mặc định 150%', () {
      final project = SiteLayoutProject.fromMap({
        'id': 'old_project',
        'name': 'Old',
        'surveyDate': DateTime(2026, 1, 1).toIso8601String(),
        'siteWidthMm': 10000,
        'siteLengthMm': 8000,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(project.dimensionTextScale, 1.5);
    });
  });

  group('resize geometry', () {
    const wall = SiteLayoutObject(
      id: 'wall',
      layoutId: 'layout',
      type: SiteObjectType.wall,
      xMm: 1000,
      yMm: 925,
      widthMm: 3000,
      lengthMm: 150,
    );

    test('tường resize theo grid và giữ đầu đối diện', () {
      final leftBefore = LayoutGeometryService.objectHandlePoint(
        wall,
        LayoutResizeHandle.leftEnd,
      );
      final resized = LayoutGeometryService.resizeObject(
        wall,
        LayoutResizeHandle.rightEnd,
        const math.Point(4751, 1000),
        snapToGrid: true,
        gridMm: 250,
      );
      final leftAfter = LayoutGeometryService.objectHandlePoint(
        resized,
        LayoutResizeHandle.leftEnd,
      );

      expect(resized.widthMm, 3750);
      expect(leftAfter.x, closeTo(leftBefore.x, 0.001));
      expect(leftAfter.y, closeTo(leftBefore.y, 0.001));
    });

    test('resize tự do vẫn chặn kích thước dưới 100 mm', () {
      final resized = LayoutGeometryService.resizeObject(
        wall,
        LayoutResizeHandle.rightEnd,
        const math.Point(1020, 1000),
        snapToGrid: false,
        gridMm: 250,
      );
      expect(resized.widthMm, LayoutGeometryService.minimumObjectSizeMm);
    });

    test('kéo đầu tường tự do cập nhật đồng thời chiều dài và góc', () {
      final startBefore = LayoutGeometryService.objectHandlePoint(
        wall,
        LayoutResizeHandle.leftEnd,
      );
      final resized = LayoutGeometryService.resizeObject(
        wall,
        LayoutResizeHandle.rightEnd,
        const math.Point(4000, 3000),
        snapToGrid: true,
        gridMm: 250,
      );
      final startAfter = LayoutGeometryService.objectHandlePoint(
        resized,
        LayoutResizeHandle.leftEnd,
      );

      expect(resized.widthMm, closeTo(3605.55, 0.01));
      expect(resized.rotationDeg, closeTo(33.69, 0.01));
      expect(startAfter.x, closeTo(startBefore.x, 0.001));
      expect(startAfter.y, closeTo(startBefore.y, 0.001));
    });

    test('nhập chiều dài và góc giữ điểm đầu tường', () {
      final startBefore = LayoutGeometryService.objectHandlePoint(
        wall,
        LayoutResizeHandle.leftEnd,
      );
      final updated = LayoutGeometryService.updateObjectDimensions(
        wall,
        widthMm: 3500,
        lengthMm: 150,
        rotationDeg: 35,
      );
      final startAfter = LayoutGeometryService.objectHandlePoint(
        updated,
        LayoutResizeHandle.leftEnd,
      );

      expect(updated.widthMm, closeTo(3500, 0.001));
      expect(updated.rotationDeg, closeTo(35, 0.001));
      expect(startAfter.x, closeTo(startBefore.x, 0.001));
      expect(startAfter.y, closeTo(startBefore.y, 0.001));
    });

    test('hit test theo footprint đã xoay thay vì bounding box', () {
      const column = SiteLayoutObject(
        id: 'column',
        layoutId: 'layout',
        type: SiteObjectType.column,
        xMm: 1000,
        yMm: 1000,
        widthMm: 500,
        lengthMm: 600,
        rotationDeg: 35,
      );
      final center = LayoutGeometryService.objectCenter(column);
      expect(LayoutGeometryService.containsObject(column, center), isTrue);
      expect(
        LayoutGeometryService.containsObject(
          column,
          math.Point(column.xMm, column.yMm),
        ),
        isFalse,
      );
    });

    test('cửa chỉ resize chiều rộng, object chữ nhật resize hai chiều', () {
      const door = SiteLayoutObject(
        id: 'door',
        layoutId: 'layout',
        type: SiteObjectType.door,
        xMm: 0,
        yMm: 925,
        widthMm: 1200,
        lengthMm: 150,
      );
      final resizedDoor = LayoutGeometryService.resizeObject(
        door,
        LayoutResizeHandle.rightEnd,
        const math.Point(1750, 1000),
        snapToGrid: true,
        gridMm: 250,
      );
      expect(resizedDoor.widthMm, 1750);
      expect(resizedDoor.lengthMm, 150);

      for (final type in [
        SiteObjectType.column,
        SiteObjectType.restrictedArea,
        SiteObjectType.obstacle,
        SiteObjectType.existingMachine,
      ]) {
        final object = SiteLayoutObject(
          id: type.name,
          layoutId: 'layout',
          type: type,
          xMm: 0,
          yMm: 0,
          widthMm: 500,
          lengthMm: 600,
        );
        final resized = LayoutGeometryService.resizeObject(
          object,
          LayoutResizeHandle.bottomRight,
          const math.Point(1000, 1250),
          snapToGrid: true,
          gridMm: 250,
        );
        expect(resized.widthMm, 1000, reason: type.name);
        expect(resized.lengthMm, 1250, reason: type.name);
      }
    });

    test('trim xóa đoạn tường dư sau giao điểm', () {
      const longWall = SiteLayoutObject(
        id: 'long_wall',
        layoutId: 'layout',
        type: SiteObjectType.wall,
        xMm: 0,
        yMm: -75,
        widthMm: 4000,
        lengthMm: 150,
      );
      final trimmed = LayoutGeometryService.trimLinearObject(
        longWall,
        const math.Point(3700, 0),
        const [(math.Point(3000, -1000), math.Point(3000, 1000))],
      );
      expect(trimmed, hasLength(1));
      expect(trimmed.single.widthMm, closeTo(3000, 0.001));
      final end = LayoutGeometryService.objectHandlePoint(
        trimmed.single,
        LayoutResizeHandle.rightEnd,
      );
      expect(end.x, closeTo(3000, 0.001));
    });

    test('trim đoạn giữa giữ lại hai phía của tường', () {
      const longWall = SiteLayoutObject(
        id: 'long_wall',
        layoutId: 'layout',
        type: SiteObjectType.wall,
        xMm: 0,
        yMm: -75,
        widthMm: 4000,
        lengthMm: 150,
      );
      final trimmed = LayoutGeometryService.trimLinearObject(
        longWall,
        const math.Point(2000, 0),
        const [
          (math.Point(1000, -1000), math.Point(1000, 1000)),
          (math.Point(3000, -1000), math.Point(3000, 1000)),
        ],
      );
      expect(trimmed, hasLength(2));
      expect(trimmed.map((item) => item.widthMm), everyElement(1000));
    });
  });

  group('provider edit history và persistence', () {
    late Database database;
    late SiteLayoutRepository repository;
    late SiteLayoutProvider provider;
    late String projectId;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final helper = SiteLayoutDatabase.forTesting(database);
      await helper.createSchemaForTesting(database);
      repository = SiteLayoutRepository(database: helper);
      final project = await repository.createProject(
        name: 'Edit test',
        customer: '',
        location: '',
        surveyor: '',
        surveyDate: DateTime(2026, 9, 25),
        siteWidthMm: 12000,
        siteLengthMm: 10000,
      );
      projectId = project.id;
      provider = SiteLayoutProvider(repository: repository);
      await provider.loadProject(projectId);
    });

    tearDown(() async {
      provider.dispose();
      await database.close();
    });

    test('một drag resize chỉ tạo một action undo', () {
      provider.setTool(EditorTool.wall);
      provider.addObject(SiteObjectType.wall, 1000, 1000);
      expect(provider.tool, EditorTool.select);
      final id = provider.selectedObject!.id;
      expect(provider.beginTransform(id), isTrue);

      provider.updateTransformResize(LayoutResizeHandle.rightEnd, 4250, 1000);
      provider.updateTransformResize(LayoutResizeHandle.rightEnd, 4500, 1000);
      provider.updateTransformResize(LayoutResizeHandle.rightEnd, 4750, 1000);
      provider.endTransform();
      expect(provider.selectedObject!.widthMm, 3750);

      provider.undo();
      expect(
        provider.bundle!.objects.singleWhere((item) => item.id == id).widthMm,
        2000,
      );
    });

    test('gàu tải mới có kích thước mặc định 300 x 300 mm', () {
      provider.addObject(SiteObjectType.bucketElevator, 1000, 1000);

      expect(provider.selectedObject!.widthMm, 300);
      expect(provider.selectedObject!.lengthMm, 300);
    });

    test('vẽ đường thẳng trực tiếp có độ dày bằng một phần ba tường', () {
      provider.setTool(EditorTool.line);
      provider.addLine(1000, 1000, 4000, 2500);

      final line = provider.selectedObject!;
      expect(line.type, SiteObjectType.line);
      expect(line.lengthMm, 50);
      expect(line.widthMm, closeTo(3354.1, 0.2));
      expect(provider.tool, EditorTool.select);

      provider.undo();
      expect(provider.bundle!.objects, isEmpty);
    });

    test('đầu tường bắt vào điểm giữa cạnh cột trước khi bắt lưới', () {
      provider.addObject(SiteObjectType.column, 4000, 1000);
      provider.addObject(SiteObjectType.wall, 1000, 1250);
      final wallId = provider.selectedObject!.id;

      expect(provider.beginTransform(wallId), isTrue);
      provider.updateTransformResize(LayoutResizeHandle.rightEnd, 3890, 1170);

      final end = LayoutGeometryService.objectHandlePoint(
        provider.selectedObject!,
        LayoutResizeHandle.rightEnd,
      );
      expect(end.x, closeTo(4000, 0.001));
      expect(end.y, closeTo(1200, 0.001));
      expect(provider.activeSnapPoint?.x, 4000);
      expect(provider.activeSnapPoint?.y, 1200);

      provider.endTransform();
      expect(provider.activeSnapPoint, isNull);
      provider.undo();
      final restoredEnd = LayoutGeometryService.objectHandlePoint(
        provider.bundle!.objects.singleWhere((item) => item.id == wallId),
        LayoutResizeHandle.rightEnd,
      );
      expect(restoredEnd.x, closeTo(3000, 0.001));
      expect(restoredEnd.y, closeTo(1250, 0.001));
    });

    test('kéo rotation handle xoay trong chế độ chọn và undo được', () {
      provider.addObject(SiteObjectType.column, 1000, 1000);
      final object = provider.selectedObject!;
      final center = LayoutGeometryService.objectCenter(object);
      expect(provider.beginTransform(object.id), isTrue);
      provider.updateTransformRotation(center.x + 1000, center.y);
      expect(provider.selectedObject!.rotationDeg, closeTo(90, 0.001));
      provider.endTransform();
      provider.undo();
      expect(
        provider.bundle!.objects
            .singleWhere((item) => item.id == object.id)
            .rotationDeg,
        0,
      );
    });

    test('công cụ Cắt trim tường và hỗ trợ undo', () {
      provider.addObject(SiteObjectType.wall, 1000, 1000);
      final targetId = provider.selectedObject!.id;
      provider.addObject(SiteObjectType.wall, 1000, 0);
      provider.setSelectedRotation(90);
      provider.setTool(EditorTool.trim);

      provider.trimLinearObject(targetId, 2800, 1000);
      final trimmed = provider.bundle!.objects.singleWhere(
        (item) => item.id == targetId,
      );
      expect(trimmed.widthMm, closeTo(1000, 0.001));
      expect(provider.tool, EditorTool.trim);

      provider.undo();
      final restored = provider.bundle!.objects.singleWhere(
        (item) => item.id == targetId,
      );
      expect(restored.widthMm, closeTo(2000, 0.001));
    });

    test('thêm máy lưu khoảng hở đã nhập nhưng giữ footprint catalog', () {
      provider.addMachine(
        const CatalogMachineLayoutData(
          sourceType: 'color_sorter',
          sourceId: 'sc16-clearance',
          category: 'Máy tách màu',
          model: 'SC16 Pro',
          displayName: 'SC16 Pro',
          lengthMm: 3629,
          widthMm: 1816,
          heightMm: 2100,
        ),
        clearanceFrontMm: 1000,
        clearanceRearMm: 600,
        clearanceLeftMm: 600,
        clearanceRightMm: 600,
        clearanceVerified: true,
      );
      final machine = provider.selectedMachine!;
      expect(machine.widthMm, 1816);
      expect(machine.lengthMm, 3629);
      expect(machine.clearanceFrontMm, 1000);
      expect(machine.clearanceRearMm, 600);
      expect(machine.clearanceLeftMm, 600);
      expect(machine.clearanceRightMm, 600);
      expect(machine.clearanceVerified, isTrue);
    });

    test('cỡ chữ kích thước được lưu và mở lại theo project', () async {
      provider.setDimensionTextScale(2.0);
      expect(provider.bundle!.project.dimensionTextScale, 2.0);
      await provider.saveNow();
      final reloaded = await repository.getBundle(
        projectId,
        provider.bundle!.layout.id,
      );
      expect(reloaded!.project.dimensionTextScale, 2.0);
    });

    test('phép đo chọn được, di chuyển, đổi đầu mút và xóa/undo được', () {
      provider.addMeasurement(1000, 1000, 3000, 1000);
      final id = provider.selectedMeasurement!.id;
      expect(provider.tool, EditorTool.select);
      expect(provider.selectedMeasurement!.distanceMm, 2000);

      expect(provider.beginTransform(id), isTrue);
      provider.updateTransformMove(500, 250);
      provider.endTransform();
      expect(provider.selectedMeasurement!.x1Mm, 1500);
      expect(provider.selectedMeasurement!.y1Mm, 1250);
      expect(provider.selectedMeasurement!.x2Mm, 3500);
      expect(provider.selectedMeasurement!.distanceMm, 2000);

      expect(provider.beginTransform(id), isTrue);
      provider.updateTransformResize(LayoutResizeHandle.rightEnd, 4250, 1250);
      provider.endTransform();
      expect(provider.selectedMeasurement!.x2Mm, 4250);
      expect(provider.selectedMeasurement!.distanceMm, 2750);

      provider.deleteSelected();
      expect(provider.bundle!.measurements, isEmpty);
      provider.undo();
      expect(provider.bundle!.measurements.single.id, id);
    });

    test('di chuyển cột cũng bắt cạnh cột vào đầu tường', () {
      provider.addObject(SiteObjectType.wall, 1000, 1000);
      final wall = provider.selectedObject!;
      final wallEnd = LayoutGeometryService.objectHandlePoint(
        wall,
        LayoutResizeHandle.rightEnd,
      );
      provider.addObject(SiteObjectType.column, 3250, 750);
      final columnId = provider.selectedObject!.id;

      expect(provider.beginTransform(columnId), isTrue);
      provider.updateTransformMove(-250, 0);

      final columnPoints = LayoutGeometryService.objectSnapPoints(
        provider.selectedObject!,
      );
      expect(
        columnPoints.any(
          (point) =>
              (point.x - wallEnd.x).abs() < 0.001 &&
              (point.y - wallEnd.y).abs() < 0.001,
        ),
        isTrue,
      );
      expect(provider.activeSnapPoint?.x, closeTo(wallEnd.x, 0.001));
      expect(provider.activeSnapPoint?.y, closeTo(wallEnd.y, 0.001));
      provider.endTransform();
    });

    test('move snap, lock, duplicate và save/load giữ nguyên edit', () async {
      provider.addObject(SiteObjectType.column, 1000, 1000);
      final originalId = provider.selectedObject!.id;
      expect(provider.beginTransform(originalId), isTrue);
      provider.updateTransformMove(260, 370);
      provider.endTransform();
      expect(provider.selectedObject!.xMm, 1250);
      expect(provider.selectedObject!.yMm, 1250);

      provider.setSelectedRotation(35);
      provider.toggleLockSelected();
      expect(provider.selectedObject!.isLocked, isTrue);
      expect(provider.beginTransform(originalId), isFalse);

      provider.duplicateSelected();
      final duplicate = provider.selectedObject!;
      expect(duplicate.id, isNot(originalId));
      expect(duplicate.isLocked, isFalse);
      expect(duplicate.rotationDeg, 35);
      expect(duplicate.xMm, greaterThan(1250));

      await provider.saveNow();
      final reloaded = await repository.getBundle(
        projectId,
        provider.bundle!.layout.id,
      );
      final storedOriginal = reloaded!.objects.singleWhere(
        (item) => item.id == originalId,
      );
      expect(storedOriginal.isLocked, isTrue);
      expect(storedOriginal.rotationDeg, 35);
      expect(reloaded.objects, hasLength(2));
    });

    test(
      'snap tắt cho phép move tự do; undo/redo đủ rotate/delete/duplicate',
      () {
        provider.addObject(SiteObjectType.column, 1000, 1000);
        final originalId = provider.selectedObject!.id;
        provider.toggleSnap();
        provider.beginTransform(originalId);
        provider.updateTransformMove(123.5, 87.25);
        provider.endTransform();
        expect(provider.selectedObject!.xMm, 1123.5);
        expect(provider.selectedObject!.yMm, 1087.25);
        provider.undo();
        expect(
          provider.bundle!.objects
              .singleWhere((item) => item.id == originalId)
              .xMm,
          1000,
        );
        provider.redo();
        provider.select(originalId);

        final centerBefore = LayoutGeometryService.objectCenter(
          provider.selectedObject!,
        );
        provider.setSelectedRotation(35);
        final centerAfter = LayoutGeometryService.objectCenter(
          provider.selectedObject!,
        );
        expect(centerAfter.x, closeTo(centerBefore.x, 0.001));
        expect(centerAfter.y, closeTo(centerBefore.y, 0.001));
        provider.undo();
        expect(
          provider.bundle!.objects
              .singleWhere((item) => item.id == originalId)
              .rotationDeg,
          0,
        );
        provider.redo();
        provider.select(originalId);

        provider.duplicateSelected();
        final duplicateId = provider.selectedObject!.id;
        expect(provider.bundle!.objects, hasLength(2));
        provider.undo();
        expect(provider.bundle!.objects, hasLength(1));
        provider.redo();
        expect(provider.bundle!.objects, hasLength(2));

        provider.select(duplicateId);
        provider.deleteSelected();
        expect(provider.bundle!.objects, hasLength(1));
        provider.undo();
        expect(provider.bundle!.objects, hasLength(2));
        provider.redo();
        expect(provider.bundle!.objects, hasLength(1));
      },
    );

    test('máy database không đổi footprint khi gọi resize', () {
      provider.addMachine(
        const CatalogMachineLayoutData(
          sourceType: 'color_sorter',
          sourceId: 'sc16-pro',
          category: 'Máy tách màu',
          model: 'SC16 Pro',
          displayName: 'SC16 Pro',
          lengthMm: 3629,
          widthMm: 1816,
          heightMm: 2100,
        ),
      );
      final machine = provider.selectedMachine!;
      expect(provider.beginTransform(machine.id), isTrue);
      provider.updateTransformResize(
        LayoutResizeHandle.bottomRight,
        9000,
        9000,
      );
      provider.endTransform();

      expect(provider.selectedMachine!.widthMm, 1816);
      expect(provider.selectedMachine!.lengthMm, 3629);

      provider.updateSelectedMachine(
        provider.selectedMachine!.copyWith(
          clearanceFrontMm: 1000,
          clearanceRearMm: 600,
          clearanceLeftMm: 600,
          clearanceRightMm: 600,
          clearanceVerified: true,
        ),
      );
      expect(provider.selectedMachine!.widthMm, 1816);
      expect(provider.selectedMachine!.lengthMm, 3629);
      expect(provider.selectedMachine!.clearanceFrontMm, 1000);
    });
  });

  test(
    'migration v1 thêm lock và z-index với default không phá dữ liệu',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(database.close);
      await database.execute(
        'CREATE TABLE site_layout_objects(id TEXT PRIMARY KEY)',
      );
      await database.execute(
        'CREATE TABLE site_machine_placements(id TEXT PRIMARY KEY)',
      );
      await database.insert('site_layout_objects', {'id': 'old_object'});
      await database.insert('site_machine_placements', {'id': 'old_machine'});

      final helper = SiteLayoutDatabase.forTesting(database);
      await helper.upgradeSchemaForTesting(database, 1, 2);
      final object = (await database.query('site_layout_objects')).single;
      final machine = (await database.query('site_machine_placements')).single;
      expect(object['isLocked'], 0);
      expect(object['zIndex'], 0);
      expect(machine['isLocked'], 0);
      expect(machine['zIndex'], 0);
    },
  );

  test(
    'migration v2 thêm cỡ chữ kích thước mặc định không phá project',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(database.close);
      await database.execute(
        'CREATE TABLE site_layout_projects(id TEXT PRIMARY KEY)',
      );
      await database.insert('site_layout_projects', {'id': 'old_project'});

      final helper = SiteLayoutDatabase.forTesting(database);
      await helper.upgradeSchemaForTesting(database, 2, 3);
      final project = (await database.query('site_layout_projects')).single;
      expect(project['dimensionTextScale'], 1.5);
    },
  );
}
