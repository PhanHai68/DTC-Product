import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/screens/agro_color_sorter/agro_air_system.dart';
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
  test('dòng H đủ H1 → H12 theo bảng thông số nông sản', () {
    expect(agroColorSorterSpecs.map((s) => s['model']), [
      'H1',
      'H2',
      'H3',
      'H4',
      'H5',
      'H7',
      'H8',
      'H10',
      'H12',
    ]);

    // Số sau chữ H là số máng: ejector = máng × 64, camera = máng × 2.
    for (final specs in agroColorSorterSpecs) {
      final chutes = int.parse(specs['model']!.substring(1));
      expect(specs['chutes_qty'], '$chutes', reason: specs['model']);
      expect(specs['ejector_qty'], '${chutes * 64}', reason: specs['model']);
      expect(specs['camera_qty'], '${chutes * 2}', reason: specs['model']);
    }

    final h7 = agroColorSorterSpecs.firstWhere((s) => s['model'] == 'H7');
    expect(h7['capacity_display'], '4 - 8 t/h');
    expect(h7['dimensions_display_mm'], '3289 x 1816 x 2177');
  });

  test('máy nén khí và bình chứa dòng H tính theo "Các loại đậu"', () {
    // Ejector × 6 L/phút → ×1.3 → ×6.2 kW → model ACOMP PM VSD; bình chứa từ
    // lưu lượng 7 bar của model đó với thông số mặc định màn tính bình chứa
    // (bình tiêu chuẩn nhỏ nhất không nhỏ hơn dung tích lý thuyết).
    const expected = {
      'H1': ('15 HP', '300 lít'),
      'H2': ('15 HP', '300 lít'),
      'H3': ('15 HP', '300 lít'),
      'H4': ('20 HP', '500 lít'),
      'H5': ('30 HP', '1000 lít'),
      'H7': ('30 HP', '1000 lít'),
      'H8': ('50 HP', '1500 lít'),
      'H10': ('50 HP', '1500 lít'),
      'H12': ('60 HP', '1500 lít'),
    };
    for (final spec in agroColorSorterSpecs.map(withAgroAirSystem)) {
      final (compressor, tank) = expected[spec['model']]!;
      expect(spec['air_compressor'], compressor, reason: spec['model']);
      expect(spec['air_tank'], tank, reason: spec['model']);
    }
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

  testWidgets('chọn H5 dùng chung ảnh H7 và đổi số camera/ejector', (
    tester,
  ) async {
    await _pumpAtPhoneSize(
      tester,
      const AgroColorSorterScreen(initialModel: 'H5'),
    );

    expect(find.text('H12'), findsWidgets);
    expect(find.text('10'), findsWidgets);
    expect(find.text('320'), findsWidgets);
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
