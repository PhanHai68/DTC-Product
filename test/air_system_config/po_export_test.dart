import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/pipe/pipe_strings.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
import 'package:dtc_product/features/air_system_config/screens/air_config_editor_screen.dart';
import 'package:dtc_product/features/air_system_config/services/air_config_export_service.dart';
import 'package:dtc_product/features/air_system_config/services/air_po_excel.dart';
import 'package:dtc_product/features/air_system_config/services/air_po_pdf.dart';
import 'package:dtc_product/features/air_system_config/services/po_requester_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// ACP-100PV (bộ vật tư 100HP, ống DN50), 40 m, tick van xả + vật tư điện.
AirConfig _config() => AirConfigTemplate.workshop.build()
  ..compressor.source = CompressorSource.catalog
  ..compressor.modelCode = 'ACP-100PV'
  ..pipe.totalLengthM = 40
  ..pipe.drainKit = true
  ..pipe.electricKit = true;

PoDocument _doc() {
  final c = _config();
  final r = appAirEngine().compute(c);
  return AirConfigExportService.poDocument(
    c,
    r,
    pipe: appPipeEngine().compute(c, r),
    kits: installKits,
    now: DateTime(2026, 10, 30),
  );
}

Future<PoTemplate> _template() =>
    PoTemplate.load((path) async => File(path).readAsBytesSync());

void main() {
  test('gộp mã: mỗi vật tư một dòng, cộng số lượng các hạng mục', () {
    final doc = _doc();
    expect(doc.sections.length, 4);
    final merged = doc.merged();
    expect(merged.equipment.length, doc.equipment.length);
    final section = merged.sections.single;
    expect(section.title, 'VẬT TƯ LẮP ĐẶT');
    final lines = section.lines;
    PoLine byCode(String code) => lines.singleWhere((l) => l.code == code);
    // Van bi DN50: cụm máy 10 + đường ống 1.
    expect(byCode('VANBID50-16').qty, 11);
    // Nối ren 21/21: cụm máy 1 + van xả 2 (cùng mã N2DRK21).
    expect(byCode('N2DRK21').qty, 3);
    // Ống kẽm Ø60: cụm máy 15 m + đường ống 48 m.
    expect(byCode('THEPO.60*3.2*6000').qty, 63);
    // Không còn dòng trùng mã; vật tư tiêu hao ở cuối.
    final codes = [for (final l in lines) ?l.code];
    expect(codes.toSet().length, codes.length);
    final firstConsumable = lines.indexWhere((l) => l.note == 'VT tiêu hao');
    expect(
      lines.sublist(firstConsumable).every((l) => l.note == 'VT tiêu hao'),
      isTrue,
    );
    // Tổng số lượng không đổi khi gộp.
    num total(Iterable<PoLine> ls) => ls.fold(0, (a, l) => a + (l.qty ?? 0));
    expect(total(lines), total([for (final s in doc.sections) ...s.lines]));
  });

  test('Excel gộp mã: một mục "VẬT TƯ LẮP ĐẶT"', () async {
    final c = _config();
    final r = appAirEngine().compute(c);
    final file = AirConfigExportService.po(
      await _template(),
      c,
      r,
      base: 'test',
      pipe: appPipeEngine().compute(c, r),
      kits: installKits,
      merged: true,
      requester: const PoRequester(
        requester: 'Nguyễn Văn A',
        employeeId: 'NV001',
        position: 'Kỹ sư',
        department: 'Kỹ thuật',
        projectCode: 'DTC-2026-15',
        requestNo: '002',
      ),
    );
    expect(file.name, 'test_DeNghiVatTu_GopMa.xlsx');
    final sheet = utf8.decode(
      ZipDecoder()
              .decodeBytes(file.bytes)
              .findFile('xl/worksheets/sheet1.xml')!
              .content
          as List<int>,
    );
    expect(sheet, contains('VẬT TƯ LẮP ĐẶT'));
    expect(sheet, isNot(contains('VAN XẢ TỰ ĐỘNG ĐÁY BÌNH TÍCH KHÍ')));
    // Thông tin người đề nghị điền đúng ô của form; không còn chỗ điền thừa.
    for (final (ref, text) in [
      ('D6', 'Nguyễn Văn A'),
      ('H6', 'NV001'),
      ('D8', 'Kỹ sư'),
      ('H8', 'Kỹ thuật'),
      ('D10', 'DTC-2026-15'),
      ('H10', '002'),
    ]) {
      expect(
        RegExp('<c r="$ref"[^>]*><is><t[^>]*>([^<]*)</t>')
            .firstMatch(sheet)
            ?.group(1),
        text,
        reason: ref,
      );
    }
    expect(sheet, isNot(contains('{{')));
    // Dải màu tiêu đề mục từ cột B tới hết cột Ghi chú (O).
    final band = RegExp(
      r'<c r="B(\d+)"[^>]*t="inlineStr"><is><t[^>]*>VẬT TƯ LẮP ĐẶT</t>',
    ).firstMatch(sheet)!.group(1);
    expect(sheet, contains('<mergeCell ref="B$band:O$band"/>'));
  });

  test('PDF: theo hạng mục và gộp mã đều xuất được', () async {
    final t = await _template();
    expect(t.company.first, 'CÔNG TY TNHH TM DV DTC');
    Uint8List read(String p) => File(p).readAsBytesSync();
    for (final doc in [_doc(), _doc().merged()]) {
      final bytes = buildPoPdf(
        doc,
        company: t.company,
        regular: read('assets/fonts/Roboto-Regular.ttf'),
        bold: read('assets/fonts/Roboto-Bold.ttf'),
        logo: read('assets/images/DTCGroup-Slogan.png'),
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      final pdf = PdfDocument(inputBytes: bytes);
      expect(pdf.pages.count, greaterThanOrEqualTo(1));
      final text = PdfTextExtractor(pdf).extractText();
      expect(text, contains('Giám đốc'));
      pdf.dispose();
    }
  });

  test('tự nhớ thông tin người đề nghị (trừ số lần đề nghị)', () async {
    SharedPreferences.setMockInitialValues({});
    var info = await PoRequesterStore.load();
    expect(
      [info.requester, info.projectCode, info.requestNo],
      ['', 'DTC-', '001'],
    );
    await PoRequesterStore.save(
      const PoRequester(
        requester: 'Nguyễn Văn A',
        employeeId: 'NV001',
        position: 'Kỹ sư',
        department: 'Kỹ thuật',
        projectCode: 'DTC-2026-15',
        requestNo: '005',
      ),
    );
    info = await PoRequesterStore.load();
    expect(
      [
        info.requester,
        info.employeeId,
        info.position,
        info.department,
        info.projectCode,
      ],
      ['Nguyễn Văn A', 'NV001', 'Kỹ sư', 'Kỹ thuật', 'DTC-2026-15'],
    );
    expect(info.requestNo, '001');
  });

  group('màn hình', () {
    late Database database;
    late AirConfigRepository repository;
    setUp(() async {
      sqfliteFfiInit();
      database = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final wrapper = AirConfigDatabase.forTesting(database);
      await wrapper.createSchemaForTesting(database);
      repository = AirConfigRepository(database: wrapper);
    });
    tearDown(() async => database.close());

    testWidgets('xuất đề nghị vật tư: thông tin đã nhớ, xoá ô; chọn Excel / '
        'PDF, theo hạng mục / gộp', (tester) async {
      SharedPreferences.setMockInitialValues({
        'po_requester_name': 'Nguyễn Văn A',
        'po_requester_department': 'Kỹ thuật',
      });
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AirConfigEditorScreen(
            initial: _config(),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = AirStrings(AirLang.vi);
      await tester.tap(find.byKey(const Key('air_config_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.exportPo));
      await tester.pumpAndSettle();
      expect(find.text(s.poDialogTitle), findsOneWidget);
      // Ô đã nhớ hiện sẵn; mã dự án gợi ý "DTC-", số lần "001".
      TextField box(String key) =>
          tester.widget<TextField>(find.byKey(Key('po_$key')));
      expect(box('requester').controller!.text, 'Nguyễn Văn A');
      expect(box('department').controller!.text, 'Kỹ thuật');
      expect(box('project_code').controller!.text, 'DTC-');
      expect(box('request_no').controller!.text, '001');
      // Nút xoá trong ô để nhập người khác.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('po_requester')),
          matching: find.byIcon(Icons.clear_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(box('requester').controller!.text, isEmpty);
      expect(find.text(s.poGroupedHint), findsOneWidget);
      await tester.ensureVisible(find.text(s.poMerged));
      await tester.tap(find.text(s.poMerged));
      await tester.pumpAndSettle();
      expect(find.text(s.poMergedHint), findsOneWidget);
      await tester.ensureVisible(find.text('PDF'));
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.matCancel));
      await tester.pumpAndSettle();
      expect(find.text(s.poDialogTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
