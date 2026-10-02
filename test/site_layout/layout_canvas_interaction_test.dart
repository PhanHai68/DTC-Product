import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/services/layout_geometry_service.dart';
import 'package:dtc_product/features/site_layout/widgets/layout_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 25);
  const wall = SiteLayoutObject(
    id: 'wall_1',
    layoutId: 'layout_1',
    type: SiteObjectType.wall,
    xMm: 1000,
    yMm: 925,
    widthMm: 2000,
    lengthMm: 150,
  );
  final bundle = SiteLayoutBundle(
    project: SiteLayoutProject(
      id: 'project_1',
      name: 'Canvas test',
      surveyDate: now,
      siteWidthMm: 5000,
      siteLengthMm: 5000,
      createdAt: now,
      updatedAt: now,
    ),
    layout: SiteLayoutVariant(
      id: 'layout_1',
      projectId: 'project_1',
      name: 'Phương án A',
      createdAt: now,
      updatedAt: now,
    ),
    objects: const [wall],
  );

  testWidgets('kéo handle đầu tường được nhận thay vì kéo thân object', (
    tester,
  ) async {
    LayoutResizeHandle? receivedHandle;
    double? receivedX;
    double? receivedY;
    var moveUpdates = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.select,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: wall.id,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onTransformStart: (id) => id == wall.id,
            onMoveUpdate: (_, _) => moveUpdates++,
            onResizeUpdate: (handle, x, y) {
              receivedHandle = handle;
              receivedX = x;
              receivedY = y;
            },
            onTransformEnd: () {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final canvasTopLeft = tester.getTopLeft(paintFinder);
    const pixelsPerMm = 0.08;
    final rightEnd = LayoutGeometryService.objectHandlePoint(
      wall,
      LayoutResizeHandle.rightEnd,
    );
    final handlePosition =
        canvasTopLeft +
        Offset(rightEnd.x * pixelsPerMm, rightEnd.y * pixelsPerMm);

    await tester.dragFrom(handlePosition, const Offset(40, 40));
    await tester.pump();

    expect(receivedHandle, LayoutResizeHandle.rightEnd);
    expect(receivedX, closeTo(3500, 1));
    expect(receivedY, closeTo(1500, 1));
    expect(moveUpdates, 0);
  });

  testWidgets('chạm vào cánh cửa sơ đồ vẫn chọn đúng cửa', (tester) async {
    const door = SiteLayoutObject(
      id: 'door_1',
      layoutId: 'layout_1',
      type: SiteObjectType.door,
      xMm: 1000,
      yMm: 925,
      widthMm: 1000,
      lengthMm: 150,
    );
    String? selectedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle.copyWith(objects: const [door]),
            tool: EditorTool.select,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: null,
            warnings: const [],
            onSelect: (id) => selectedId = id,
            onAddObject: (_, _, _) {},
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) {},
            onResizeUpdate: (_, _, _) {},
            onTransformEnd: () {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final renderBox = tester.renderObject<RenderBox>(paintFinder);
    const pixelsPerMm = 0.08;
    // Cửa nằm ngang; cánh mở từ bản lề xuống dưới. Điểm này nằm trên
    // cánh cửa nhưng đủ xa đường ngưỡng để kiểm tra hit-test của ký hiệu.
    final leafPoint = renderBox.localToGlobal(
      const Offset(1000 * pixelsPerMm, 1600 * pixelsPerMm),
    );
    await tester.tapAt(leafPoint);
    await tester.pump();

    expect(selectedId, door.id);
  });

  testWidgets('đối tượng đã chọn luôn có nút nhập kích thước nhanh', (
    tester,
  ) async {
    var editCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.select,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: wall.id,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) {},
            onResizeUpdate: (_, _, _) {},
            onTransformEnd: () {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
            onEditSelected: () => editCalls++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nhập kích thước'), findsOneWidget);
    await tester.tap(find.text('Nhập kích thước'));
    expect(editCalls, 1);
  });

  testWidgets('rotation handle xoay ngay trong chế độ chọn', (tester) async {
    var rotateUpdates = 0;
    var moveUpdates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.select,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: wall.id,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) => moveUpdates++,
            onResizeUpdate: (_, _, _) {},
            onRotateUpdate: (_, _) => rotateUpdates++,
            onTransformEnd: () {},
            onTrimObject: (_, _, _) {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final renderBox = tester.renderObject<RenderBox>(paintFinder);
    // Tâm tường (2000, 1000), rotation handle cách mép trên 34 px.
    final rotationHandle = renderBox.localToGlobal(const Offset(160, 40));
    await tester.dragFrom(rotationHandle, const Offset(70, 40));
    await tester.pump();

    expect(rotateUpdates, greaterThan(0));
    expect(moveUpdates, 0);
  });

  testWidgets('công cụ Cắt chuyển đúng object và vị trí chạm', (tester) async {
    String? trimmedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.trim,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: null,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) {},
            onResizeUpdate: (_, _, _) {},
            onRotateUpdate: (_, _) {},
            onTransformEnd: () {},
            onTrimObject: (id, _, _) => trimmedId = id,
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final renderBox = tester.renderObject<RenderBox>(paintFinder);
    await tester.tapAt(renderBox.localToGlobal(const Offset(160, 80)));
    await tester.pump();
    expect(trimmedId, wall.id);
  });

  testWidgets('Marker ảnh hiện điểm kéo và chỉ chọn ảnh sau khi thả', (
    tester,
  ) async {
    double? markerX;
    double? markerY;
    var choosePhotoCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.photoMarker,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: null,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) {},
            onResizeUpdate: (_, _, _) {},
            onTransformEnd: () {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (x, y) async {
              choosePhotoCalls++;
              markerX = x;
              markerY = y;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final renderBox = tester.renderObject<RenderBox>(paintFinder);
    final gesture = await tester.startGesture(
      renderBox.localToGlobal(const Offset(100, 100)),
    );
    await gesture.moveBy(const Offset(40, 30));
    await tester.pump();

    final draggingPainter =
        tester.widget<CustomPaint>(paintFinder).painter as SiteLayoutPainter;
    expect(draggingPainter.draftPhotoMarker, const Offset(140, 130));
    expect(choosePhotoCalls, 0);

    await gesture.up();
    await tester.pump();
    expect(choosePhotoCalls, 1);
    expect(markerX, closeTo(1750, 1));
    expect(markerY, closeTo(1625, 1));
  });

  testWidgets('công cụ Đường thẳng vẽ trực tiếp từ điểm kéo đầu đến cuối', (
    tester,
  ) async {
    (double, double, double, double)? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutCanvas(
            bundle: bundle,
            tool: EditorTool.line,
            gridMm: 250,
            snapToGrid: true,
            showClearance: true,
            selectedId: null,
            warnings: const [],
            onSelect: (_) {},
            onAddObject: (_, _, _) {},
            onAddLine: (x1, y1, x2, y2) => received = (x1, y1, x2, y2),
            onTransformStart: (_) => true,
            onMoveUpdate: (_, _) {},
            onResizeUpdate: (_, _, _) {},
            onTransformEnd: () {},
            onAddMeasurement: (_, _, _, _) {},
            onAddNote: (_, _) {},
            onAddPhotoMarker: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    final paintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SiteLayoutPainter,
    );
    final renderBox = tester.renderObject<RenderBox>(paintFinder);
    await tester.dragFrom(
      renderBox.localToGlobal(const Offset(80, 80)),
      const Offset(160, 80),
    );
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.$1, closeTo(1000, 1));
    expect(received!.$2, closeTo(1000, 1));
    expect(received!.$3, closeTo(3000, 1));
    expect(received!.$4, closeTo(2000, 1));
  });
}
