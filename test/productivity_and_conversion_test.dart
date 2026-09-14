import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/models/productivity_calc.dart';
import 'package:dtc_product/models/technical_conversion.dart';
import 'package:dtc_product/services/productivity_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductivityCalcData Tests', () {
    test('Calculates kgPerHour and tonPerHour correctly for 10kg in 1m 0s', () {
      final data = ProductivityCalcData(
        customerName: 'Test Customer',
        materialName: 'Test Material',
        notes: 'Test Notes',
        weightKg: 10.0,
        hours: 0,
        minutes: 1,
        seconds: 0,
        measuredAt: DateTime.now(),
      );

      expect(data.totalSeconds, 60);
      expect(data.kgPerHour, closeTo(600.0, 0.001));
      expect(data.tonPerHour, closeTo(0.6, 0.001));
      expect(data.tonPerDay, closeTo(14.4, 0.001));
    });

    test('Handles zero or invalid duration gracefully', () {
      final data = ProductivityCalcData(
        weightKg: 10.0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        measuredAt: DateTime.now(),
      );

      expect(data.totalSeconds, 0);
      expect(data.kgPerHour, 0.0);
      expect(data.tonPerHour, 0.0);
    });
  });

  group('TechnicalConversionData Tests', () {
    test('Converts pressure correctly from 1 Bar', () {
      final res = TechnicalConversionData.convertPressure(1.0, 'Bar');
      expect(res['Bar'], closeTo(1.0, 0.001));
      expect(res['PSI']!, closeTo(14.5038, 0.01));
      expect(res['MPa']!, closeTo(0.1, 0.001));
      expect(res['kPa']!, closeTo(100.0, 0.001));
      expect(res['kgf/cm²']!, closeTo(1.01972, 0.01));
    });

    test('Converts air flow correctly from 1 m3/min', () {
      final res = TechnicalConversionData.convertAirFlow(1.0, 'm³/min');
      expect(res['m³/min'], closeTo(1.0, 0.001));
      expect(res['L/min'], closeTo(1000.0, 0.001));
      expect(res['CFM']!, closeTo(35.3147, 0.01));
      expect(res['m³/h'], closeTo(60.0, 0.001));
      expect(res['L/s']!, closeTo(16.6667, 0.01));
    });

    test('Data lists contain correct items', () {
      expect(TechnicalConversionData.meshList.length, 35);
      expect(TechnicalConversionData.pipeSizeList.length, 17);
      expect(TechnicalConversionData.meshList.first.mesh, '3');
      expect(TechnicalConversionData.pipeSizeList.first.dn, 'DN6');
    });
  });

  group('ProductivityPdfService Tests', () {
    test('Builds valid PDF bytes with verified stamp', () async {
      final data = ProductivityCalcData(
        customerName: 'Công ty Cổ phần Nông nghiệp DTC',
        materialName: 'Gạo ST25',
        notes: 'Chạy thử nghiệm trên máy tách màu 5 máng',
        weightKg: 25.5,
        hours: 0,
        minutes: 2,
        seconds: 30,
        measuredAt: DateTime(2026, 9, 13, 14, 30),
      );

      final bytes = await ProductivityPdfService.build(data: data);
      expect(bytes, isNotEmpty);
      // PDF file signature starts with %PDF-
      final signature = String.fromCharCodes(bytes.take(5));
      expect(signature, '%PDF-');
    });
  });
}
