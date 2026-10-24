import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/electricity_bill_provider.dart';
import 'package:dtc_product/providers/payback_period_provider.dart';
import 'package:dtc_product/providers/processing_profit_provider.dart';
import 'package:dtc_product/providers/self_business_provider.dart';
import 'package:dtc_product/screens/payback/payback_period_screen.dart';
import 'package:dtc_product/screens/payback/processing_profit_screen.dart';
import 'package:dtc_product/widgets/payback/formula_explainer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('các provider lưu số liệu của lần tính gần nhất, reset thì xóa', () {
    final electricity = ElectricityBillProvider()
      ..setModel('SC16')
      ..setNormalHours('8')
      ..setPeakHours('2')
      ..calculate();
    final bill = electricity.lastInputs!;
    expect(bill.powerKw, billingPowerKw('SC16'));
    expect(bill.averagePower, isTrue);
    expect(bill.normalHours, 8);
    expect(bill.peakRate, electricity.peakRate);

    // Sửa ô nhập sau khi tính không làm đổi số liệu đã dùng.
    electricity.setNormalHours('3');
    expect(electricity.lastInputs!.normalHours, 8);

    final tea = ElectricityBillProvider()
      ..setModel('DF53 Pro')
      ..setNormalHours('10')
      ..calculate();
    expect(tea.lastInputs!.averagePower, isFalse);

    final processing = ProcessingProfitProvider()
      ..setProcessingPrice('100000')
      ..setDailySalary('300000')
      ..calculate(capacity: 4, totalHours: 10, totalBill: 500000);
    expect(processing.lastInputs!.revenue, 100000 * 4 * 10);
    expect(processing.lastInputs!.dailySalary, 300000);

    final payback = PaybackPeriodProvider()
      ..setMachinePrice('500000000')
      ..setFullSetupPrice('800000000')
      ..calculate(3200000);
    expect(payback.lastInputs, (
      machinePrice: 500000000.0,
      fullSetupPrice: 800000000.0,
      totalProfit: 3200000.0,
    ));

    final business = SelfBusinessProvider()
      ..setRawMaterialPrice('10000')
      ..calculate(
        capacity: 4,
        totalHours: 10,
        electricityBill: 500000,
        dailySalary: 0,
      );
    expect(business.lastInputs!.finishedCapacity, 4 * 0.96875);

    for (final reset in [
      electricity.resetSession,
      processing.resetSession,
      payback.resetSession,
      business.resetSession,
    ]) {
      reset();
    }
    expect(electricity.lastInputs, isNull);
    expect(processing.lastInputs, isNull);
    expect(payback.lastInputs, isNull);
    expect(business.lastInputs, isNull);
  });

  test('formulaNumber dùng dấu chấm ngăn nghìn, dấu phẩy thập phân', () {
    expect(formulaNumber(1811), '1.811');
    expect(formulaNumber(77.12), '77,12');
    expect(formulaNumber(0.125), '0,125');
  });

  Widget wrap(Widget screen, ElectricityBillProvider electricity) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: electricity),
        ChangeNotifierProvider(create: (_) => ProcessingProfitProvider()),
        ChangeNotifierProvider(create: (_) => PaybackPeriodProvider()),
        ChangeNotifierProvider(create: (_) => SelfBusinessProvider()),
      ],
      child: MaterialApp(home: screen),
    );
  }

  Future<void> openFormula(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Cách tính'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cách tính'));
    await tester.pumpAndSettle();
  }

  testWidgets('lợi nhuận gia công: công thức luôn có, thay số sau khi tính', (
    tester,
  ) async {
    final electricity = ElectricityBillProvider()
      ..setModel('SC16')
      ..setNormalHours('10')
      ..calculate();
    await tester.pumpWidget(wrap(const ProcessingProfitScreen(), electricity));

    await openFormula(tester);
    expect(
      find.textContaining('Lợi nhuận gia công/ngày = Doanh thu gia công'),
      findsOneWidget,
    );
    expect(find.text('Thay số lần tính gần nhất'), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '100000');
    await tester.enterText(fields.at(1), '300000');
    await tester.ensureVisible(find.text('Xác nhận'));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    expect(find.text('Thay số lần tính gần nhất'), findsOneWidget);
    expect(find.textContaining('Doanh thu = 100.000'), findsOneWidget);
    expect(find.textContaining('Lợi nhuận = '), findsOneWidget);
  });

  testWidgets('hoàn vốn: lợi nhuận ≤ 0 giải thích là không thể hoàn vốn', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const PaybackPeriodScreen(), ElectricityBillProvider()),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '500000');
    await tester.enterText(fields.at(1), '800000');
    await tester.ensureVisible(find.text('Xác nhận'));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    await openFormula(tester);

    expect(find.textContaining('nên không thể hoàn vốn'), findsOneWidget);
  });
}
