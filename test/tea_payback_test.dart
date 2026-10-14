import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/electricity_bill_provider.dart';
import 'package:dtc_product/providers/payback_period_provider.dart';
import 'package:dtc_product/providers/processing_profit_provider.dart';
import 'package:dtc_product/providers/self_business_provider.dart';
import 'package:dtc_product/screens/payback_analysis_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('hoàn vốn máy trà chỉ có DF53 Pro, công suất từ thiết bị dây chuyền', () {
    expect(powerConsumptionModels(ColorSorterLine.tea), ['DF53 Pro']);

    final rows = {
      for (final row in powerConsumptionData['DF53 Pro']!)
        row['Tiêu chí']!: row['Thông số']!,
    };
    // Năng suất = 1700 kg/h; công suất lớn nhất = tổng công suất × số lượng
    // thiết bị trong tea_aux_equipment.json; không có công suất trung bình.
    expect(rows['Năng suất (Tấn/h)'], '1.7');
    expect(rows['Máy tách màu (kW)'], '23.5');
    expect(rows['Máy nén khí (kW)'], '37');
    expect(rows['Băng tải phế phẩm × 2 (kW)'], '0.4');
    expect(rows['Công suất lớn nhất (kW)'], '66.75');
    expect(rows.containsKey('Công suất trung bình (kW)'), isFalse);

    // Gạo vẫn tính tiền điện theo công suất trung bình; trà theo lớn nhất.
    expect(billingPowerKw('SC16'), 77.12);
    expect(billingPowerKw('DF53 Pro'), 66.75);
  });

  test('tiền điện DF53 Pro tính theo công suất lớn nhất', () {
    final provider = ElectricityBillProvider()
      ..setModel('DF53 Pro')
      ..setNormalHours('10')
      ..calculate();
    expect(provider.errorMessage, isNull);
    expect(provider.totalBill, (66.75 * 10 * provider.normalRate).roundToDouble());
  });

  testWidgets('menu hoàn vốn trà: bước 4–6 sắp có, tiến độ tính trên 2 kết quả', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ElectricityBillProvider()),
          ChangeNotifierProvider(create: (_) => ProcessingProfitProvider()),
          ChangeNotifierProvider(create: (_) => PaybackPeriodProvider()),
          ChangeNotifierProvider(create: (_) => SelfBusinessProvider()),
        ],
        child: const MaterialApp(
          home: PaybackAnalysisMenuScreen(line: ColorSorterLine.tea),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Máy tách màu Trà'), findsOneWidget);
    expect(find.text('Tiến độ phương án: 0/2 kết quả'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xem biểu đồ hoàn vốn'), 200);
    expect(find.text('Sắp có'), findsNWidgets(3));
  });
}
