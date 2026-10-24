import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/models/acomp_spec_model.dart';
import 'package:dtc_product/models/acomp_vsd_compare_config.dart';
import 'package:dtc_product/providers/electricity_bill_provider.dart';
import 'package:dtc_product/screens/acomp/acomp_vsd_compare_screen.dart';
import 'package:dtc_product/services/acomp_energy_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _assumptions = AcompVsdAssumptions(
  unloadPowerRatio: 0.30,
  vsdBaseRatio: 0.10,
  vsdMinLoad: 0.30,
  fixedPressureBandBar: 0.5,
  energyPerBar: 0.07,
);

AcompSpecModel _spec(String code, String series, double kw, double flow) =>
    AcompSpecModel(
      modelCode: code,
      series: series,
      powerKW: kw,
      powerHP: kw * 4 / 3,
      flow7Bar: flow,
      flow8Bar: flow,
      airOutlet: 'DN40',
      lubricant: 22,
      weight: 460,
      dimensions: '1390x950x1250',
    );

AcompOperatingInput _input(
  double load, {
  double? vsdPrice,
  double? fixedPrice,
}) => AcompOperatingInput(
  loadPercent: load,
  pressureBar: 8,
  hoursPerDay: 16,
  daysPerYear: 300,
  electricityPrice: 2000,
  vsdPrice: vsdPrice,
  fixedPrice: fixedPrice,
);

void main() {
  const calculator = AcompEnergyCalculator(_assumptions);
  final pair37 = AcompSpeedPair(
    _spec('ACP-50PV', 'PM VSD', 37, 6.2),
    _spec('ACP-50F', 'Fixed Speed', 37, 6.2),
  );

  group('Mô hình điện năng', () {
    test('máy cố định: có tải/không tải cộng phần dải áp', () {
      expect(calculator.fixedPowerFraction(1), closeTo(1.035, 1e-9));
      expect(calculator.fixedPowerFraction(0.6), closeTo(0.72 * 1.035, 1e-9));
      expect(calculator.fixedPowerFraction(0), closeTo(0.30 * 1.035, 1e-9));
    });

    test(
      'máy biến tần: tỷ lệ theo tải, dưới tốc độ tối thiểu thì liên tục',
      () {
        expect(calculator.vsdPowerFraction(1), closeTo(1.0, 1e-9));
        expect(calculator.vsdPowerFraction(0.6), closeTo(0.64, 1e-9));
        final atMin = calculator.vsdPowerFraction(0.30);
        expect(atMin, closeTo(0.37, 1e-9));
        expect(calculator.vsdPowerFraction(0.2999), closeTo(atMin, 1e-3));
        expect(calculator.vsdPowerFraction(0.15), lessThan(atMin));
        expect(calculator.vsdPowerFraction(0), closeTo(0.37 * 0.30, 1e-9));
      },
    );

    test('ví dụ trong phương án: 37 kW, tải 60%, 16 giờ × 300 ngày', () {
      final result = calculator.compare(pair37, _input(60));
      expect(result.fixed.kwhPerYear, closeTo(132347.5, 1));
      expect(result.vsd.kwhPerYear, closeTo(113664, 1));
      expect(result.savingsPerYear, closeTo(37367040, 1000));
      expect(result.savingsPercent, closeTo(14.1, 0.1));
      expect(result.paybackYears, isNull);
    });

    test('hoàn vốn phần chênh giá và lợi thế lũy kế', () {
      final result = calculator.compare(
        pair37,
        _input(60, vsdPrice: 360e6, fixedPrice: 300e6),
      );
      expect(result.priceDifference, 60e6);
      expect(result.paybackYears, closeTo(60e6 / result.savingsPerYear, 1e-9));
      expect(
        result.netBenefitAfter(5),
        closeTo(result.savingsPerYear * 5 - 60e6, 1),
      );
      expect(result.totalCostAfter(0, vsdMachine: true), 360e6);
    });

    test('biến tần rẻ hơn thì hoàn vốn ngay', () {
      final result = calculator.compare(
        pair37,
        _input(60, vsdPrice: 280e6, fixedPrice: 300e6),
      );
      expect(result.paybackYears, 0);
    });

    test('cặp lệch lưu lượng: cùng nhu cầu khí theo máy nhỏ hơn', () {
      final pair = AcompSpeedPair(
        _spec('ACP-220PV', 'PM VSD', 160, 30.15),
        _spec('ACP-220F', 'Fixed Speed', 160, 30.2),
      );
      final result = calculator.compare(pair, _input(60));
      expect(result.demandFlow, closeTo(0.6 * 30.15, 1e-9));
      expect(result.vsd.load, closeTo(0.6, 1e-9));
      expect(result.fixed.load, closeTo(0.6 * 30.15 / 30.2, 1e-9));
      expect(pair.isMismatched(8), isTrue);
      expect(pair37.isMismatched(8), isFalse);
    });

    test('đường tiết kiệm giảm dần khi tải tăng', () {
      final curve = calculator.savingsCurve(pair37, _input(60));
      expect(curve.first.$1, 10);
      expect(curve.last.$1, 100);
      for (var i = 1; i < curve.length; i++) {
        if (curve[i].$1 < 30) continue;
        expect(curve[i].$2, lessThan(curve[i - 1].$2), reason: '${curve[i]}');
      }
    });
  });

  group('Gợi ý', () {
    final config = acompVsdCompareConfig;

    test('hoàn vốn nhanh thì khuyên biến tần', () {
      final result = calculator.compare(
        pair37,
        _input(60, vsdPrice: 340e6, fixedPrice: 300e6),
      );
      expect(adviseAcompSpeed(result, config).level, AcompAdviceLevel.vsd);
    });

    test('gần đầy tải và hoàn vốn lâu thì máy cố định là đủ', () {
      final result = calculator.compare(
        pair37,
        _input(95, vsdPrice: 500e6, fixedPrice: 300e6),
      );
      expect(adviseAcompSpeed(result, config).level, AcompAdviceLevel.fixed);
    });

    test('tải vừa nhưng hoàn vốn lâu thì cân nhắc', () {
      final result = calculator.compare(
        pair37,
        _input(70, vsdPrice: 500e6, fixedPrice: 300e6),
      );
      expect(adviseAcompSpeed(result, config).level, AcompAdviceLevel.consider);
    });
  });

  group('Dữ liệu', () {
    test('mọi model biến tần trong specs.json đều có máy cố định cùng cỡ', () {
      final pairs = buildAcompSpeedPairs(acompSpecData);
      final vsdCount = acompSpecData.where((s) => s.series == 'PM VSD').length;
      expect(pairs.length, vsdCount);
      for (final pair in pairs) {
        expect(pair.sizeCode, acompSizeCode(pair.fixed.modelCode));
        expect(
          acompMccbData.any((row) => row['model'] == pair.vsd.modelCode),
          isTrue,
          reason: '${pair.vsd.modelCode} thiếu trong mccb_cable.json',
        );
        expect(
          acompMccbData.any((row) => row['model'] == pair.fixed.modelCode),
          isTrue,
          reason: '${pair.fixed.modelCode} thiếu trong mccb_cable.json',
        );
      }
    });

    test('vsd_compare.json: giả định hợp lệ và có ghi chú', () {
      final config = acompVsdCompareConfig;
      final a = config.assumptions;
      for (final ratio in [a.unloadPowerRatio, a.vsdBaseRatio, a.vsdMinLoad]) {
        expect(ratio, inInclusiveRange(0, 1));
      }
      expect(a.fixedPressureBandBar, greaterThanOrEqualTo(0));
      expect(config.paybackYears, greaterThan(0));
      expect(config.vsdNotes, isNotEmpty);
      expect(config.fixedNotes, isNotEmpty);
    });
  });

  group('Màn hình', () {
    Future<void> pumpScreen(WidgetTester tester, {String? size}) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ElectricityBillProvider(),
          child: MaterialApp(home: AcompVsdCompareScreen(initialSize: size)),
        ),
      );
    }

    testWidgets('chọn sẵn cỡ máy, nhập tải thì hiện kết quả', (tester) async {
      await pumpScreen(tester, size: 'ACP-50');

      expect(find.text('ACP-50PV'), findsWidgets);
      expect(find.text('ACP-50F'), findsWidgets);
      expect(find.byKey(const Key('vsd_compare_savings')), findsNothing);
      expect(
        find.text('Nhập nhu cầu khí trung bình của khách (%) để xem kết quả.'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('vsd_compare_load')), '60');
      await tester.pump();

      expect(find.byKey(const Key('vsd_compare_advice')), findsOneWidget);
      expect(find.byKey(const Key('vsd_compare_savings')), findsOneWidget);
      expect(find.byKey(const Key('vsd_compare_payback')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('vsd_compare_vsd_price')),
        '360000000',
      );
      await tester.enterText(
        find.byKey(const Key('vsd_compare_fixed_price')),
        '300000000',
      );
      await tester.pump();
      expect(find.byKey(const Key('vsd_compare_payback')), findsOneWidget);
    });

    testWidgets('báo lỗi khi tải ngoài 10–100%', (tester) async {
      await pumpScreen(tester, size: 'ACP-50');
      await tester.enterText(find.byKey(const Key('vsd_compare_load')), '150');
      await tester.pump();
      expect(
        find.text('Nhu cầu khí trung bình phải từ 10 đến 100%.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vsd_compare_savings')), findsNothing);
    });
  });
}
