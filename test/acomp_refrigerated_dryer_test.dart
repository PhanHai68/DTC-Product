import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/screens/acomp/acomp_refrigerated_dryer_screen.dart';
import 'package:dtc_product/screens/acomp/acomp_tech_category_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dữ liệu máy sấy tác nhân lạnh: 16 model ACD, khớp catalog', () {
    expect(refrigeratedDryers, hasLength(16));
    expect(refrigeratedDryers.every((m) => m.model.startsWith('ACD-')), isTrue);
    expect(refrigeratedDryers.map((m) => m.model).take(3), [
      'ACD-1',
      'ACD-2',
      'ACD-3',
    ]);
    final capacities = [for (final m in refrigeratedDryers) m.capacityM3min];
    expect(capacities, [...capacities]..sort());

    // Bảng hãng (OFD → ACD): lưu lượng, môi chất, máy nén khí tương ứng.
    final table = {
      for (final m in refrigeratedDryers.take(11))
        m.model:
            '${m.capacityM3min} ${m.refrigerant} '
            '${m.matchingCompressorKw.join('/')}',
    };
    expect(table, {
      'ACD-1': '1.2 R134a 7.5/11.0',
      'ACD-2': '2.4 R134a 15.0',
      'ACD-3': '3.6 R410a 22.0',
      'ACD-6': '6.5 R410a 30.0/37.0',
      'ACD-8': '8.5 R410a 45.0',
      'ACD-10': '11.0 R410a 55.0',
      'ACD-13': '13.5 R410a 75.0',
      'ACD-15': '17.0 R407C 90.0',
      'ACD-20': '23.0 R407C 110.0',
      'ACD-25': '25.0 R407C 132.0',
      'ACD-30': '30.0 R407C 160.0',
    });
    expect(
      refrigeratedDryers.take(11).every((m) => m.maxInletTempC == 65),
      isTrue,
    );
    final d15 = refrigeratedDryers.firstWhere((m) => m.model == 'ACD-15');
    expect(d15.voltage, contains('3 pha'));

    final d10 = refrigeratedDryers.firstWhere((m) => m.model == 'ACD-10');
    expect(d10.capacityM3min, 11);
    expect(d10.compressorKw, 2);
    expect(d10.fanW, 380);
    expect(d10.airOutlet, 'DN50');
    expect([d10.lengthMm, d10.widthMm, d10.heightMm], [1050, 600, 1030]);
    expect(d10.weightKg, 140);
    expect(d10.operatingTemperature, '≤ 45 °C');
    expect(d10.voltage, contains('1 pha'));

    final d100 = refrigeratedDryers.last;
    expect(d100.model, 'ACD-100');
    expect(d100.compressorKw, 18.4);
    expect(d100.operatingTemperature, '≤ 65 °C');
    expect(d100.voltage, contains('3 pha'));
    expect(d100.workingPressure, startsWith('2–10 bar'));
  });

  testWidgets('Thông số kỹ thuật có 2 tab: Máy nén khí | Máy sấy khí', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AcompTechCategoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Máy nén khí trục vít biến tần'), findsOneWidget);
    expect(find.text('Máy sấy khí tác nhân lạnh'), findsNothing);
    await tester.tap(find.text('Máy sấy khí'));
    await tester.pumpAndSettle();
    expect(find.text('Máy sấy khí tác nhân lạnh'), findsOneWidget);
    expect(find.text('Model: ACD'), findsOneWidget);
  });

  test('lọc đường ống: 7 model theo catalog, không có 090', () {
    expect(lineFilters.map((m) => m.model), [
      '015',
      '024',
      '035',
      '060',
      '010',
      '013',
      '020',
    ]);
    final f020 = lineFilters.last;
    expect(f020.capacityM3min, 20);
    expect(f020.port, '2 1/2" = DN65');
    expect(f020.levels.map((l) => l.level), ['C', 'T', 'A']);
    expect(lineFilters.first.levels.map((l) => l.micron), [3, 1, 0.01]);
  });

  testWidgets('tab Lọc đường ống: thẻ model với cấp lọc', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AcompTechCategoryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc đường ống'));
    await tester.pumpAndSettle();
    expect(find.text('Model 015'), findsOneWidget);
    expect(find.text('1,5 m³/phút'), findsOneWidget);
    expect(find.text('Đường kính đầu vào/đầu ra: 1/2" = DN20'), findsOneWidget);
    expect(find.text('0,01 µm'), findsWidgets);
    expect(find.text('Model 090'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn máy sấy tác nhân lạnh: chọn model xem thông số tiếng Việt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AcompRefrigeratedDryerScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refrigerated_dryer_model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACD-20 - 23 m³/phút').last);
    await tester.pumpAndSettle();
    expect(find.text('Thông số Model: ACD-20'), findsOneWidget);
    expect(find.text('3,68 kW'), findsOneWidget);
    expect(find.text('480 W'), findsOneWidget);
    expect(find.text('1.500 x 750 x 1.440 mm'), findsOneWidget);
    expect(find.text('220 kg'), findsOneWidget);
    expect(find.text('2–10 °C'), findsOneWidget);
    expect(find.text('R407C'), findsOneWidget);
    expect(find.text('110 kW'), findsOneWidget);
    expect(find.text('Nhiệt độ khí vào tối đa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
