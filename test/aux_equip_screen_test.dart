import 'package:dtc_product/screens/aux_equip/aux_equip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('danh sách thiết bị phụ trợ cuộn dọc đến dòng cuối', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: AuxEquipScreen(initialModel: 'SC16')),
    );
    await tester.pump();

    expect(find.byKey(const Key('aux_export_pdf_button')), findsOneWidget);
    expect(find.byKey(const Key('aux_vertical_scroll_view')), findsOneWidget);
    expect(find.text('Đường ống lắp đặt cụm máy (m)'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('aux_vertical_scroll_view')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    final lastRow = tester.getRect(find.text('Đường ống lắp đặt cụm máy (m)'));
    expect(lastRow.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });
}
