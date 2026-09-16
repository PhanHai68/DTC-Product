import 'package:dtc_product/data/mineral_specs_data.dart';
import 'package:dtc_product/screens/mineral_color_sorter/mineral_color_sorter_screen.dart';
import 'package:dtc_product/screens/mineral_color_sorter_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAtPhoneSize(WidgetTester tester, Widget home) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  test('dữ liệu SX8 khớp bảng thông số và cấu hình khí nén DF53 Pro', () {
    final specs = mineralColorSorterSpecs.single;

    expect(specs['model'], 'SX8');
    expect(specs['layers_qty'], '2');
    expect(specs['camera_qty'], '64');
    expect(specs['ejector_qty'], '2048');
    expect(specs['chutes_qty'], '8');
    expect(specs['power_kw'], '9.1');
    expect(specs['voltage_v'], '380');
    expect(specs['frequency_hz'], '50');
    expect(specs['air_flow_m3_min'], '< 4.5');
    expect(specs['dimensions_display_mm'], '4080 x 2035 x 2945');
    expect(specs['weight_kg'], '4100');
    expect(specs['air_compressor'], 'ACOMP 50 HP');
    expect(specs['air_tank'], '1500 lít');
    expect(specs['key_features'], contains('PLOV 3.0'));
  });

  testWidgets('menu Khoáng sản có các mục tương tự menu Trà', (tester) async {
    await _pumpAtPhoneSize(tester, const MineralColorSorterMenuScreen());

    expect(find.text('Máy tách màu Khoáng sản'), findsOneWidget);
    expect(find.text('Thông số kỹ thuật'), findsOneWidget);
    expect(find.text('Thiết bị phụ trợ'), findsOneWidget);
    expect(find.text('Phân tích hoàn vốn'), findsOneWidget);
    expect(find.text('Tra cứu lỗi'), findsOneWidget);
    expect(find.text('Tài liệu vận hành'), findsOneWidget);
    expect(find.text('Sắp có'), findsNWidgets(4));
  });

  testWidgets('màn hình SX8 hiển thị ảnh, thông số và nút mô hình 3D', (
    tester,
  ) async {
    await _pumpAtPhoneSize(tester, const MineralColorSorterScreen());

    expect(find.text('SX8'), findsWidgets);
    expect(find.text('64'), findsWidgets);
    expect(find.text('2048'), findsWidgets);
    expect(find.text('Xem Mô Hình 3D 360°'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/color_sorter/sx8.jpg',
      ),
      findsOneWidget,
    );
  });
}
