import 'dart:convert';

import 'package:dtc_product/features/grinding_machine/models/grinding_extra_spec.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_spec_sheet_pdf_service.dart';
import 'package:dtc_product/features/grinding_machine/utils/grinding_format.dart';
import 'package:dtc_product/features/grinding_machine/utils/grinding_spec_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingExtraSpec _spec(String key, {double? n, String? text, String? unit}) =>
    GrindingExtraSpec(
      machineId: 'X__X-1',
      specKey: key,
      specValueNumber: n,
      specValueText: text,
      unit: unit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const machine = GrindingMachine(
    machineId: 'X__X-1',
    seriesCode: 'X',
    model: 'X-1',
    capacityMinKgH: 80,
    capacityMaxKgH: 300,
    finenessMin: 0.5,
    finenessMax: 20,
    finenessUnit: 'mm',
    mainMotorKwMin: 7.5,
    mainMotorKwMax: 7.5,
    lengthMm: 840,
    widthMm: 470,
    heightMm: 1020,
    weightKg: 112,
  );

  group('GrindingSpecSheet', () {
    test('gộp cặp _min/_max, ẩn khoá nội bộ, dịch nhãn, bỏ đơn vị count', () {
      final sheet = GrindingSpecSheet(
        machine: machine,
        series: null,
        extraSpecs: [
          _spec('temperature_c_min', n: -196, unit: '°C'),
          _spec('temperature_c_max', n: 0, unit: '°C'),
          _spec('needs_verification', text: 'air_consumption_unit'),
          _spec('compressed_air_consumption_source_unit', text: 'm3/s'),
          _spec('roller_count', n: 3, unit: 'count'),
          _spec('chamber_diameter_mm', n: 200, unit: 'mm'),
          _spec('some_new_key', text: 'abc'),
        ],
      );

      final rows = {for (final r in sheet.extraRows) r.label: r.value};
      expect(rows['Nhiệt độ làm việc'], '-196 - 0 °C');
      expect(rows['Số trục cán'], '3');
      expect(rows['Đường kính buồng nghiền'], '200 mm');
      // Khoá chưa có bản dịch: hiển thị nguyên văn đã bỏ "_".
      expect(rows['Some new key'], 'abc');
      expect(rows.length, 4);
    });

    test('thẻ chỉ số chỉ có số, đơn vị nằm ở nhãn', () {
      final sheet = GrindingSpecSheet(
        machine: machine,
        series: null,
        extraSpecs: const [],
      );
      expect(sheet.highlights.map((h) => (h.$1, h.$2)).toList(), [
        ('Công suất (kg/h)', '80 - 300'),
        ('Độ mịn (mm)', '0.5 - 20'),
        ('Động cơ (kW)', '7.5'),
      ]);
      expect(sheet.installRows.map((r) => r.value).toList(), [
        '840 x 470 x 1020 mm',
        '112 kg',
      ]);
      // Dòng không có ảnh -> không hiện khung ảnh.
      expect(sheet.imagePath, isNull);
    });

    test(
      'ảnh theo dòng máy: đúng dòng trong database, file ảnh có thật',
      () async {
        final seed = jsonDecode(
          await rootBundle.loadString(
            'assets/database/grinding_machine_seed.json',
          ),
        ) as Map<String, dynamic>;
        final seriesCodes = {
          for (final s in seed['series'] as List) s['seriesCode'] as String,
        };
        const expected = {
          'ASP_ULTRAFINE': 'home_grinding_machine_asp350.png',
          'AS_SMALL_HAMMER': 'grinding_as_small_hammer.jpg',
          'ASDF_MULTISTAGE': 'grinding_asdf_multistage.jpg',
          'ASZ_PIN': 'grinding_asz_pin.jpg',
          'ASC_COARSE': 'grinding_asc_coarse.png',
          'AS_ROLLER': 'grinding_as_roller.png',
          'ASU_UNIVERSAL': 'grinding_asu_turbine.png',
          'ASK_JET': 'grinding_ask_jet.png',
          'ASG_UNIVERSAL_SYSTEM': 'grinding_asg_cyclone.png',
          'ASF_FITZ_MILL': 'grinding_asf_fitz.png',
          'ASF_AS_HAMMER': 'grinding_as_hammer.jpg',
          'AS_CRYOGENIC': 'grinding_as_cryogenic.jpg',
        };
        for (final MapEntry(key: code, value: file) in expected.entries) {
          expect(seriesCodes, contains(code));
          final sheet = GrindingSpecSheet(
            machine: GrindingMachine(
              machineId: 'm',
              seriesCode: code,
              model: 'M',
            ),
            series: null,
            extraSpecs: const [],
          );
          expect(sheet.imagePath, 'assets/images/$file', reason: code);
          expect(sheet.imageCaption, isNotNull, reason: code);
          final bytes = await rootBundle.load(sheet.imagePath!);
          expect(bytes.lengthInBytes, greaterThan(1000), reason: code);
        }
      },
    );

    test('kích thước đầu vào nhiều vế: mỗi vế 1 dòng ngắn', () {
      final sheet = GrindingSpecSheet(
        machine: const GrindingMachine(
          machineId: 'm',
          seriesCode: 'AS_SMALL_HAMMER',
          model: 'AS-180',
          inputSizeNote:
              '<10 mm cho nguyên liệu hạt; <15×40×2 mm cho nguyên liệu lá',
        ),
        series: null,
        extraSpecs: const [],
      );
      final row = sheet.technicalRows.single;
      expect(row.label, 'Kích thước đầu vào');
      expect(row.value, 'Hạt: < 10 mm\nLá: < 15×40×2 mm');
      expect(
        sheet.shareText(contactName: 'An', contactPhone: '1'),
        contains('• Kích thước đầu vào: Hạt: < 10 mm; Lá: < 15×40×2 mm'),
      );
    });

    test('text chia sẻ có tiêu đề, thông số và liên hệ', () {
      final text = GrindingSpecSheet(
        machine: machine,
        series: null,
        extraSpecs: const [],
      ).shareText(contactName: 'An', contactPhone: '0901234567');
      expect(text, contains('MÁY NGHIỀN X-1'));
      expect(text, contains('• Công suất xử lý: 80 - 300 kg/h'));
      expect(text, contains('0901234567'));
    });

    test('PDF catalog dựng được với font tiếng Việt', () async {
      final bytes = await GrindingSpecSheetPdfService.buildPdf(
        sheet: GrindingSpecSheet(
          machine: machine,
          series: null,
          extraSpecs: [_spec('roller_count', n: 3, unit: 'count')],
        ),
        selectionTags: const {'food', 'hammer'},
        contactName: 'Nguyễn Văn A',
        contactPhone: '0901234567',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  test('nhãn chọn máy cutting/hammer/screen đã có tiếng Việt', () {
    expect(GrindingFormat.tagLabel('cutting'), 'Nghiền cắt');
    expect(GrindingFormat.tagLabel('hammer'), 'Nghiền búa');
    expect(GrindingFormat.tagLabel('screen'), 'Có lưới sàng');
  });

  test('model sắp theo số tự nhiên, nhỏ đến lớn', () {
    final models = ['ASC-1000', 'ASC-200', 'ASC-600', 'ASC-300', 'ASC-400']
      ..sort(GrindingFormat.compareModel);
    expect(models, ['ASC-200', 'ASC-300', 'ASC-400', 'ASC-600', 'ASC-1000']);
  });
}
