import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/features/site_layout/screens/site_project_form_screen.dart';

void main() {
  testWidgets('form tạo dự án chỉ giữ ba thông tin và hai kích thước', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SiteProjectFormScreen()));

    expect(find.text('Tên dự án *'), findsOneWidget);
    expect(find.text('Địa điểm *'), findsOneWidget);
    expect(find.text('Người khảo sát *'), findsOneWidget);
    expect(find.text('Kích thước mặt bằng lắp đặt'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Khách hàng'), findsNothing);
    expect(find.text('Ngày khảo sát'), findsNothing);
    expect(find.text('Chiều cao trần'), findsNothing);
    expect(find.text('Ghi chú dự án'), findsNothing);
  });

  testWidgets('đổi đơn vị giữ nguyên kích thước thực đã nhập', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SiteProjectFormScreen()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(3), '12');
    await tester.enterText(fields.at(4), '8,5');

    await tester.tap(find.text('cm'));
    await tester.pump();

    final width = tester.widget<TextFormField>(fields.at(3));
    final length = tester.widget<TextFormField>(fields.at(4));
    expect(width.controller!.text, '1200');
    expect(length.controller!.text, '850');
  });
}
