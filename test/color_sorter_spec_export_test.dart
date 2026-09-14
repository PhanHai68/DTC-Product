import 'package:dtc_product/screens/color_sorter/color_sorter_screen.dart';
import 'package:dtc_product/screens/color_sorter/spec_image_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const specs = {
    'Model': 'SC8',
    'Năng suất (tấn/giờ)': '8 - 10',
    'Số máng': '5',
    'Số ejector': '480',
    'Số Camera': '10',
  };

  test('nội dung văn bản có thông số và liên hệ được nhập', () {
    final text = buildColorSorterSpecShareText(
      specs: specs,
      contactName: 'Nguyễn Văn An',
      contactPhone: '0901 234 567',
    );

    expect(text, contains('MÁY TÁCH MÀU SC8'));
    expect(text, isNot(contains('MÁY TÁCH MÀU DTC SC8')));
    expect(text, contains('Nguyễn Văn An'));
    expect(text, contains('0901 234 567'));
    expect(text, contains('8 - 10 tấn/giờ'));
    expect(text, isNot(contains('lưu lượng')));
  });

  testWidgets('màn hình chia sẻ cho nhập tên và số liên hệ riêng', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SpecImageExportDialog(specs: specs)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chia sẻ thông số'), findsOneWidget);
    expect(find.byKey(const Key('contact_name_field')), findsOneWidget);
    expect(find.byKey(const Key('contact_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('copy_spec_text_button')), findsOneWidget);
    expect(find.byKey(const Key('share_spec_pdf_button')), findsOneWidget);
    expect(find.text('Nội dung chia sẽ'), findsOneWidget);
    expect(find.text('NỘI DUNG PDF KHỔ A4'), findsNothing);
    expect(find.textContaining('0832.666.755'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('contact_name_field')),
      'Nguyễn Văn An',
    );
    await tester.enterText(
      find.byKey(const Key('contact_phone_field')),
      '0901 234 567',
    );
    await tester.pump();

    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('0901 234 567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bắt buộc nhập đủ tên và số điện thoại trước khi chia sẻ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SpecImageExportDialog(specs: specs)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy_spec_text_button')));
    await tester.pump();

    expect(find.text('Vui lòng nhập tên người liên hệ'), findsOneWidget);
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
  });

  testWidgets('tự điền liên hệ đã lưu và không hiển thị nội dung ví dụ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'color_sorter_contact_name': 'Phan Hải',
      'color_sorter_contact_phone': '0945 989 028',
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SpecImageExportDialog(specs: specs)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phan Hải'), findsOneWidget);
    expect(find.text('0945 989 028'), findsOneWidget);
    expect(find.textContaining('Ví dụ:'), findsNothing);
  });

  testWidgets('thông số nổi bật và tab hiển thị đủ trên điện thoại', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ColorSorterScreen()));
    await tester.pump();

    expect(find.text('MÁY TÁCH MÀU SC16 PRO'), findsOneWidget);
    expect(find.text('MÁY TÁCH MÀU DTC SC16 PRO'), findsNothing);
    expect(find.text('Năng suất (T/h)'), findsOneWidget);
    expect(find.text('Số Camera'), findsWidgets);
    expect(find.text('Số Ejector'), findsOneWidget);
    expect(find.text('24 Camera'), findsNothing);
    expect(find.text('1152 Ejector'), findsNothing);
    expect(find.text('Thông số\nkỹ thuật'), findsOneWidget);
    expect(find.text('Hệ thống\nkhí nén'), findsOneWidget);
    expect(find.text('Lắp đặt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
