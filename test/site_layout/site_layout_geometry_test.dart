import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/services/layout_geometry_service.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  SiteLayoutBundle bundle({
    List<MachinePlacement> machines = const [],
    List<SiteLayoutObject> objects = const [],
    double? ceiling = 5000,
    double? beam,
  }) => SiteLayoutBundle(
    project: SiteLayoutProject(
      id: 'p1',
      name: 'Nhà máy A',
      surveyDate: now,
      siteWidthMm: 10000,
      siteLengthMm: 8000,
      ceilingHeightMm: ceiling,
      lowestBeamHeightMm: beam,
      createdAt: now,
      updatedAt: now,
    ),
    layout: SiteLayoutVariant(
      id: 'l1',
      projectId: 'p1',
      name: 'Phương án A',
      createdAt: now,
      updatedAt: now,
    ),
    machines: machines,
    objects: objects,
  );

  MachinePlacement machine({
    double x = 1000,
    double y = 1000,
    double rotation = 0,
  }) => MachinePlacement(
    id: 'm1',
    layoutId: 'l1',
    sourceType: 'test',
    sourceId: 'source',
    category: 'Máy thử',
    model: 'TEST-1',
    displayName: 'Máy thử TEST-1',
    xMm: x,
    yMm: y,
    rotationDeg: rotation,
    lengthMm: 2000,
    widthMm: 1000,
    heightMm: 3000,
    clearanceFrontMm: 500,
    clearanceRearMm: 600,
    clearanceLeftMm: 700,
    clearanceRightMm: 800,
    clearanceTopMm: 400,
    clearanceVerified: true,
  );

  test('snap luôn tính theo mm, không phụ thuộc tỷ lệ hiển thị', () {
    expect(LayoutGeometryService.snap(1124, 250), 1000);
    expect(LayoutGeometryService.snap(1125, 250), 1250);
    expect(LayoutGeometryService.snap(1125, 0), 1125);
  });

  test('đường thẳng không được tính là vật cản kỹ thuật', () {
    const line = SiteLayoutObject(
      id: 'line_1',
      layoutId: 'l1',
      type: SiteObjectType.line,
      xMm: 1000,
      yMm: 1000,
      widthMm: 3000,
      lengthMm: 50,
      label: 'Đường thẳng',
    );
    final warnings = LayoutGeometryService.validate(
      bundle(machines: [machine()], objects: const [line]),
    );

    expect(
      warnings.where(
        (warning) => warning.type == LayoutWarningType.physicalOverlap,
      ),
      isEmpty,
    );
  });

  test('xoay 90 độ đổi footprint và ánh xạ đúng khoảng hở', () {
    final item = machine(rotation: 90);
    expect(item.renderedWidthMm, 2000);
    expect(item.renderedLengthMm, 1000);
    final clearance = LayoutGeometryService.worldClearance(item);
    expect(clearance.top, 600);
    expect(clearance.right, 700);
    expect(clearance.bottom, 500);
    expect(clearance.left, 800);
  });

  test('mặt trước luôn nằm trên cạnh có chiều dài lớn nhất', () {
    final portrait = LayoutGeometryService.localClearance(machine());
    expect(portrait.right, 500);
    expect(portrait.left, 600);
    expect(portrait.top, 700);
    expect(portrait.bottom, 800);

    final landscape = MachinePlacement(
      id: 'm2',
      layoutId: 'l1',
      sourceType: 'test',
      sourceId: 'source-2',
      category: 'Máy thử',
      model: 'TEST-2',
      displayName: 'Máy thử TEST-2',
      xMm: 0,
      yMm: 0,
      lengthMm: 1000,
      widthMm: 2000,
      heightMm: 1000,
      clearanceFrontMm: 500,
      clearanceRearMm: 600,
      clearanceLeftMm: 700,
      clearanceRightMm: 800,
    );
    final landscapeClearance = LayoutGeometryService.localClearance(landscape);
    expect(landscapeClearance.top, 500);
    expect(landscapeClearance.bottom, 600);
    expect(landscapeClearance.left, 700);
    expect(landscapeClearance.right, 800);
  });

  test('cảnh báo nêu khoảng yêu cầu, thực tế và thiếu hụt', () {
    final item = machine();
    final blocker = SiteLayoutObject(
      id: 'wall',
      layoutId: 'l1',
      type: SiteObjectType.wall,
      xMm: 1000,
      yMm: 600,
      widthMm: 1000,
      lengthMm: 300,
      label: 'Tường Bắc',
    );
    final warnings = LayoutGeometryService.validate(
      bundle(machines: [item], objects: [blocker]),
    );
    final warning = warnings.firstWhere(
      (value) => value.type == LayoutWarningType.clearance,
    );
    expect(warning.requiredMm, 700);
    expect(warning.actualMm, 100);
    expect(warning.shortageMm, 600);
  });

  test('không khóa vị trí nhưng cảnh báo ngoài ranh giới và chiều cao', () {
    final warnings = LayoutGeometryService.validate(
      bundle(machines: [machine(x: 9500)], ceiling: 3200),
    );
    expect(
      warnings.any((value) => value.type == LayoutWarningType.outOfBounds),
      isTrue,
    );
    expect(
      warnings.any((value) => value.type == LayoutWarningType.height),
      isTrue,
    );
  });

  test('thiếu trần và dầm trả về chưa xác minh', () {
    final warnings = LayoutGeometryService.validate(
      bundle(machines: [machine()], ceiling: null),
    );
    expect(
      warnings.any((value) => value.type == LayoutWarningType.missingData),
      isTrue,
    );
  });
}
