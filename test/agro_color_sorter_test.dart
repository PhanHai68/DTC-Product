import 'package:dtc_product/data/agro_specs_data.dart';
import 'package:dtc_product/screens/agro_color_sorter/agro_color_sorter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAtPhoneSize(WidgetTester tester, Widget home) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  test('dữ liệu H7 khớp bảng thông số nông sản', () {
    final specs = agroColorSorterSpecs.single;

    expect(specs['model'], 'H7');
    expect(specs['chutes_qty'], '8');
    expect(specs['camera_qty'], '14');
    expect(specs['ejector_qty'], '448');
    expect(specs['dimensions_display_mm'], '3629 x 1816 x 2177');
  });

  testWidgets('màn hình H7 hiển thị ảnh, thông số và CHƯA có nút mô hình 3D', (
    tester,
  ) async {
    await _pumpAtPhoneSize(tester, const AgroColorSorterScreen());

    expect(find.text('H7'), findsWidgets);
    expect(find.text('14'), findsWidgets);
    expect(find.text('448'), findsWidgets);
    // Chức năng xem 3D đã gỡ (chưa có nguồn dữ liệu 3D nào đạt chất lượng
    // hiển thị chấp nhận được) — sẽ bổ sung lại khi có nguồn phù hợp.
    expect(find.text('Xem Mô Hình 3D 360°'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/color_sorter/Hinh_anh H7.jpg',
      ),
      findsOneWidget,
    );
  });
}
