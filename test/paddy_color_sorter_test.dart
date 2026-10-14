import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/electricity_bill_provider.dart';
import 'package:dtc_product/providers/paddy_color_sorter_provider.dart';
import 'package:dtc_product/providers/payback_period_provider.dart';
import 'package:dtc_product/providers/processing_profit_provider.dart';
import 'package:dtc_product/providers/self_business_provider.dart';
import 'package:dtc_product/screens/paddy_color_sorter/paddy_aux_equip_screen.dart';
import 'package:dtc_product/screens/payback_analysis_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('dòng SF Pro đủ SF3D → SF12D theo bảng thông số thóc', () {
    expect(paddyColorSorterSpecs.map((s) => s['Model']), [
      'SF3D Pro',
      'SF5D Pro',
      'SF7D Pro',
      'SF8D Pro',
      'SF10D Pro',
      'SF12D Pro',
    ]);

    // Số trong tên model là số máng: ejector = máng × 96, camera = máng × 2.
    for (final spec in paddyColorSorterSpecs) {
      final model = spec['Model']!;
      final chutes = int.parse(RegExp(r'\d+').firstMatch(model)![0]!);
      expect(spec['Số máng'], '$chutes', reason: model);
      expect(spec['Số ejector'], '${chutes * 96}', reason: model);
      expect(spec['Số Camera'], '${chutes * 2}', reason: model);
    }
  });

  test('khí nén máy thóc lấy theo máy gạo cùng (hoặc gần nhất) số máng', () {
    Map<String, String> rice(String model) =>
        colorSorterSpecs.firstWhere((s) => s['Model'] == model);
    const riceModelFor = {
      'SF3D Pro': 'SC4',
      'SF5D Pro': 'SC8',
      'SF7D Pro': 'SC10', // cùng 7 máng
      'SF8D Pro': 'SC10', // 8 máng → SC10 7 máng (gần nhất)
      'SF10D Pro': 'SC12',
      'SF12D Pro': 'SC16 Pro',
    };
    for (final spec in paddyColorSorterSpecs) {
      final source = rice(riceModelFor[spec['Model']]!);
      for (final key in [
        'Áp suất khí nén',
        'Lưu lượng khí tiêu thụ',
        'Máy nén khí đồng bộ',
        'Bình tích khí đồng bộ',
      ]) {
        expect(spec[key], source[key], reason: '${spec['Model']} – $key');
      }
    }

    final sf7 = paddyColorSorterSpecs.firstWhere(
      (s) => s['Model'] == 'SF7D Pro',
    );
    expect(sf7['Máy nén khí đồng bộ'], '50HP');
    expect(sf7['Bình tích khí đồng bộ'], '1500 lít');
  });

  test('hoàn vốn máy thóc dùng bảng điện năng máy gạo cùng số máng', () {
    // Chỉ model có máy gạo cùng số máng; SF8D (8 máng) bỏ qua.
    expect(powerConsumptionModels(ColorSorterLine.paddy), [
      'SF3D Pro',
      'SF5D Pro',
      'SF7D Pro',
      'SF10D Pro',
      'SF12D Pro',
    ]);
    // Danh sách máy gạo giữ nguyên, không lẫn máy thóc.
    expect(
      powerConsumptionModels(ColorSorterLine.rice),
      everyElement(startsWith('SC')),
    );

    // Gàu tải, quạt hút bụi, nén khí theo máy gạo; năng suất = trung bình
    // mức thấp/cao của máy thóc; công suất máy tách màu theo máy thóc;
    // tối đa = tổng, trung bình = 80% tối đa.
    Map<String, String> rows(String model) => {
      for (final row in powerConsumptionData[model]!)
        row['Tiêu chí']!: row['Thông số']!,
    };
    const expected = {
      // model: (năng suất, máy tách màu, tối đa, trung bình)
      'SF3D Pro': ('2.25', '1.7', '22.70', '18.16'), // theo SC4
      'SF5D Pro': ('3.75', '2.6', '35.60', '28.48'), // theo SC8
      'SF7D Pro': ('5.25', '3.5', '51.50', '41.20'), // theo SC10
      'SF10D Pro': ('7.5', '5.0', '73.50', '58.80'), // theo SC12
      'SF12D Pro': ('9', '5.9', '96.40', '77.12'), // theo SC16 Pro
    };
    expected.forEach((model, values) {
      final r = rows(model);
      expect(r['Năng suất (Tấn/h)'], values.$1, reason: model);
      expect(r['Máy tách màu (kW)'], values.$2, reason: model);
      expect(r['Công suất tối đa (kW)'], values.$3, reason: model);
      expect(r['Công suất trung bình (kW)'], values.$4, reason: model);
    });
    expect(
      rows('SF10D Pro')['Hệ thống nén khí (kW)'],
      rows('SC12')['Hệ thống nén khí (kW)'],
    );
  });

  test('thiết bị phụ trợ máy thóc: máy gạo cùng số máng có danh sách', () {
    final keys = auxEquipSpecsByModel.keys;
    expect(riceModelForPaddy('SF3D Pro', keys), 'SC4');
    expect(riceModelForPaddy('SF5D Pro', keys), 'SC8');
    expect(riceModelForPaddy('SF10D Pro', keys), 'SC12');
    expect(riceModelForPaddy('SF12D Pro', keys), 'SC16');
    // SF7D Pro cùng 7 máng với SC10, nhưng màn phụ trợ vẫn ưu tiên danh sách
    // riêng của SF7D Pro.
    expect(riceModelForPaddy('SF7D Pro', keys), 'SC10');
    expect(riceModelForPaddy('SF8D Pro', keys), isNull);
  });

  testWidgets('màn thiết bị phụ trợ thóc chọn được model có dữ liệu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PaddyAuxEquipScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Thiết bị phụ trợ SF7D Pro'), findsOneWidget);
    for (final model in ['SF3D Pro', 'SF5D Pro', 'SF10D Pro', 'SF12D Pro']) {
      expect(find.widgetWithText(ChoiceChip, model), findsOneWidget);
    }
    expect(find.widgetWithText(ChoiceChip, 'SF8D Pro'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF3D Pro'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị phụ trợ SF3D Pro'), findsOneWidget);
    expect(
      find.text('Theo danh sách thiết bị phụ trợ của máy gạo SC4 (cùng 3 máng).'),
      findsOneWidget,
    );
  });

  testWidgets('menu hoàn vốn thóc không dùng tiếp phương án máy gạo', (
    tester,
  ) async {
    final electricity = ElectricityBillProvider()
      ..setModel('SC10')
      ..setNormalHours('8')
      ..calculate();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: electricity),
          ChangeNotifierProvider(create: (_) => ProcessingProfitProvider()),
          ChangeNotifierProvider(create: (_) => PaybackPeriodProvider()),
          ChangeNotifierProvider(create: (_) => SelfBusinessProvider()),
        ],
        child: const MaterialApp(
          home: PaybackAnalysisMenuScreen(line: ColorSorterLine.paddy),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Máy tách màu Thóc'), findsOneWidget);
    expect(find.text('Tiến độ phương án: 0/4 kết quả'), findsOneWidget);
    expect(find.text('Bắt đầu phương án mới'), findsOneWidget);
  });

  test('tư vấn chọn model thóc theo năng suất', () {
    final provider = PaddyColorSorterProvider();
    expect(provider.suggestModelByCapacity(2)?['model'], 'SF3D Pro');
    expect(provider.suggestModelByCapacity(5)?['model'], 'SF5D Pro');
    expect(provider.suggestModelByCapacity(6)?['model'], 'SF7D Pro');
    expect(provider.suggestModelByCapacity(11)?['model'], 'SF12D Pro');
    expect(provider.suggestModelByCapacity(13), isNull);
  });
}
