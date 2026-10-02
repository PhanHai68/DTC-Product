import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/providers/site_layout_provider.dart';
import 'package:dtc_product/features/site_layout/screens/site_layout_editor_screen.dart';

void main() {
  testWidgets('editor dùng hai hàng công cụ ngang ở chiều rộng điện thoại', (
    tester,
  ) async {
    final provider = _ToolbarProvider();
    addTearDown(provider.dispose);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<SiteLayoutProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: SiteLayoutEditorToolbar(
              provider: provider,
              onAddMachine: () {},
              onEditSelected: null,
              onWarnings: () {},
            ),
          ),
        ),
      ),
    );

    final primary = find.byKey(const Key('site_layout_toolbar_primary'));
    final secondary = find.byKey(const Key('site_layout_toolbar_secondary'));
    expect(primary, findsOneWidget);
    expect(secondary, findsOneWidget);
    expect(
      find.descendant(of: primary, matching: find.byIcon(Icons.add_rounded)),
      findsOneWidget,
    );

    final labels = ['Hoàn tác', 'Làm lại', 'Đo', 'Xóa'];
    final positions = labels
        .map(
          (label) => tester.getCenter(
            find.descendant(of: secondary, matching: find.text(label)),
          ),
        )
        .toList();
    for (var index = 1; index < positions.length; index++) {
      expect(positions[index].dx, greaterThan(positions[index - 1].dx));
    }
    await tester.drag(primary, const Offset(-320, 0));
    await tester.pump();
    expect(find.text('Bắt điểm'), findsOneWidget);

    await tester.drag(primary, const Offset(-420, 0));
    await tester.pump();
    expect(find.text('Khoảng hở'), findsOneWidget);
  });
}

class _ToolbarProvider extends SiteLayoutProvider {
  _ToolbarProvider();

  static final _now = DateTime(2026, 9, 26);
  static final _testBundle = SiteLayoutBundle(
    project: SiteLayoutProject(
      id: 'project_toolbar',
      name: 'Dự án toolbar',
      location: 'Cần Thơ',
      surveyor: 'Kỹ sư DTC',
      surveyDate: _now,
      siteWidthMm: 12000,
      siteLengthMm: 8000,
      createdAt: _now,
      updatedAt: _now,
    ),
    layout: SiteLayoutVariant(
      id: 'layout_toolbar',
      projectId: 'project_toolbar',
      name: 'Phương án A',
      createdAt: _now,
      updatedAt: _now,
    ),
  );

  @override
  SiteLayoutBundle get bundle => _testBundle;
}
