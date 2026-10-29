import 'dart:convert';
import 'dart:io';

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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

/// Máy nén chọn theo model trong dữ liệu.
AirConfig _withModel(String model, {double? lengthM}) =>
    AirConfigTemplate.workshop.build()
      ..compressor.source = CompressorSource.catalog
      ..compressor.modelCode = model
      ..pipe.totalLengthM = lengthM;

Future<PoTemplate> _template() =>
    PoTemplate.load((path) async => File(path).readAsBytesSync());

/// Các ô (A1…) của một vùng gộp "C13:F13".
Iterable<String> _cells(String range) sync* {
  final m = RegExp(r'^([A-Z]+)(\d+):([A-Z]+)(\d+)$').firstMatch(range)!;
  for (var r = int.parse(m[2]!); r <= int.parse(m[4]!); r++) {
    for (var c = m[1]!.codeUnitAt(0); c <= m[3]!.codeUnitAt(0); c++) {
      yield '${String.fromCharCode(c)}$r';
    }
  }
}

void main() {
  test('install_kits.json: 4 công suất, khớp model theo kW', () {
    final kits = installKits;
    expect([for (final k in kits.kits) k.hp], [30, 50, 75, 100]);
    expect([for (final k in kits.kits) k.kw], [22, 37, 55, 75]);
    final k30 = kits.forPowerKw(22)!;
    expect(k30.standard.title, contains('30HP'));
    expect(
      k30.standard.items.first.name,
      'Van bi đồng DN25, PN16 ( loại tay gạt)',
    );
    expect(k30.standard.items.first.qty, 10);
    expect(k30.drain.items.first.code, 'VXD-MICB');
    expect(k30.drain.note, isNotEmpty);
    expect(k30.electric.items.first.name, 'MCCB 3pha 63A');
    expect(k30.electric.note, startsWith('Tuỳ thuộc'));
    // Vật tư tiêu hao: ghi chú "VT tiêu hao", gom cuối danh sách.
    for (final kit in kits.kits) {
      final notes = kit.standard.items.map((i) => i.note).toList();
      final first = notes.indexOf('VT tiêu hao');
      expect(notes.where((n) => n == 'VT tiêu hao'), hasLength(10));
      expect(notes.sublist(first), everyElement('VT tiêu hao'));
      expect(kit.standard.items.last.name, 'Que hàn 2.5mm');
    }
    expect(kits.forPowerKw(45), isNull);
    expect(kits.forPowerKw(null), isNull);
    // Mọi model cùng công suất (ACP, AFR) dùng chung bộ vật tư.
    final engine = appAirEngine();
    final with22 = engine.compressors.where((c) => c.powerKW == 22);
    expect(with22.length, greaterThan(1));
    for (final c in with22) {
      expect(kits.forPowerKw(c.powerKW)?.hp, 30);
    }
  });

  test('tick van xả / vật tư điện lưu cùng cấu hình', () {
    final c = AirConfigTemplate.workshop.build()
      ..pipe.drainKit = true
      ..pipe.electricKit = true;
    final back = AirConfig.fromJson(c.toJson());
    expect([back.pipe.drainKit, back.pipe.electricKit], [true, true]);
    expect(
      AirConfig.fromJson(AirConfigTemplate.food.build().toJson()).pipe.drainKit,
      isFalse,
    );
  });

  test('phiếu đề nghị vật tư: thiết bị, cụm máy 30HP, đường ống, mục tick', () {
    final c = _withModel('ACP-30PV', lengthM: 40)..pipe.electricKit = true;
    final r = appAirEngine().compute(c);
    final doc = AirConfigExportService.poDocument(
      c,
      r,
      pipe: appPipeEngine().compute(c, r),
      kits: installKits,
      now: DateTime(2026, 10, 27),
    );
    expect(
      doc.projectTitle,
      'Vật tư lắp đặt hệ máy nén khí 30HP – Xưởng cơ khí',
    );
    expect(doc.date, '27/10/2026');
    final compressor = doc.equipment.first;
    expect(compressor.name, contains('ACP-30PV'));
    expect(compressor.unit, 'Máy');
    expect(compressor.spec, '30HP – 22 kW');
    // Máy sấy ngay sau máy nén; không ghi van xả tự động, bộ tách dầu – nước.
    expect(doc.equipment[1].name, startsWith('Máy sấy'));
    final names = doc.equipment.map((l) => l.name).toList();
    expect(names, isNot(contains('Van xả tự động')));
    expect(names, isNot(contains('Bộ tách dầu – nước')));
    // Lọc: "Bộ lọc …", không ghi nhóm sấy.
    expect(names, contains('Bộ lọc tách thô 1 µm'));
    expect(names, contains('Bộ lọc tách tinh 0,01 µm'));
    expect(names.where((n) => n.contains('nhóm')), isEmpty);
    expect(doc.sections.map((s) => s.band), [
      PoBand.blue,
      PoBand.blue,
      PoBand.yellow,
    ]);
    expect(doc.sections[0].title, contains('30HP'));
    expect(doc.sections[0].lines, hasLength(40));
    expect(
      doc.sections[1].title,
      'VẬT TƯ TỪ CỤM MÁY ĐẾN THIẾT BỊ SỬ DỤNG KHÍ NÉN',
    );
    // Định mức 15 m, cỡ DN25 (30HP); 40 m → 3 bước.
    final pipeLines = doc.sections[1].lines;
    expect(pipeLines, hasLength(18));
    final pipe = pipeLines.firstWhere((l) => l.name.startsWith('Ống kẽm'));
    expect(
      [pipe.name, pipe.unit, pipe.qty],
      ['Ống kẽm Ø34 *3.2mm*6000', 'Mét', 48],
    );
    expect(pipeLines.last.note, 'VT tiêu hao');
    expect(doc.sections[2].note, startsWith('Tuỳ thuộc'));
  });

  test('công suất chưa có dữ liệu: "Chưa cập nhật"', () {
    final c = _withModel('ACP-60PV');
    final r = appAirEngine().compute(c);
    expect(r.compressor?.powerKw, 45);
    final doc = AirConfigExportService.poDocument(c, r, kits: installKits);
    expect(doc.sections.single.lines.single.name, startsWith('Chưa cập nhật'));
    expect(doc.projectTitle, startsWith('Vật tư lắp đặt hệ máy nén khí 45 kW'));
  });

  test('file xlsx theo form: đủ phần, XML hợp lệ, ô gộp không chồng', () async {
    final c = _withModel('ACP-30PV', lengthM: 40)
      ..pipe.drainKit = true
      ..pipe.electricKit = true;
    final r = appAirEngine().compute(c);
    final file = AirConfigExportService.po(
      await _template(),
      c,
      r,
      base: 'test',
      pipe: appPipeEngine().compute(c, r),
      kits: installKits,
    );
    expect(file.name, 'test_DeNghiVatTu.xlsx');
    final out = Platform.environment['PO_XLSX_OUT'];
    if (out != null) File(out).writeAsBytesSync(file.bytes);

    final zip = ZipDecoder().decodeBytes(file.bytes);
    String part(String name) =>
        utf8.decode(zip.findFile(name)!.content as List<int>);
    for (final name in [
      '[Content_Types].xml',
      'xl/workbook.xml',
      'xl/styles.xml',
      'xl/drawings/drawing1.xml',
      'xl/worksheets/sheet1.xml',
    ]) {
      XmlDocument.parse(part(name));
    }
    expect(zip.findFile('xl/media/image1.png'), isNotNull);
    final sheet = XmlDocument.parse(part('xl/worksheets/sheet1.xml'));
    final text = sheet.findAllElements('t').map((t) => t.innerText).toList();
    for (final s in [
      'ĐỀ NGHỊ VẬT TƯ ',
      'Vật tư lắp đặt hệ máy nén khí 30HP – Xưởng cơ khí',
      'VẬT TƯ LẮP ĐẶT BỘ MÁY NÉN KHÍ 30HP TIÊU CHUẨN THEO SƠ ĐỒ',
      'VẬT TƯ TỪ CỤM MÁY ĐẾN THIẾT BỊ SỬ DỤNG KHÍ NÉN',
      'VAN XẢ TỰ ĐỘNG ĐÁY BÌNH TÍCH KHÍ',
      'VẬT TƯ ĐIỆN TẠM TÍNH',
      'Người đề nghị',
      'Giám đốc',
    ]) {
      expect(text, contains(s));
    }
    final seen = <String>{};
    for (final m in sheet.findAllElements('mergeCell')) {
      for (final cell in _cells(m.getAttribute('ref')!)) {
        expect(seen.add(cell), isTrue, reason: 'ô $cell gộp hai lần');
      }
    }
    // Dòng tăng dần, ô trong dòng theo thứ tự cột.
    var last = 0;
    for (final row in sheet.findAllElements('row')) {
      final r = int.parse(row.getAttribute('r')!);
      expect(r, greaterThan(last));
      last = r;
      final cols = [
        for (final c in row.findElements('c'))
          c.getAttribute('r')!.replaceAll(RegExp(r'\d'), ''),
      ];
      expect(cols, [...cols]..sort());
    }
    expect(
      part('xl/workbook.xml'),
      contains("'ĐỀ NGHỊ VẬT TƯ'!\$A\$1:\$O\$$last"),
    );
  });

  group('tab Vật tư lắp đặt', () {
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

    Future<void> open(WidgetTester tester, AirConfig config) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AirConfigEditorScreen(
            initial: config,
            repository: repository,
            initialTab: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('máy 30HP: bảng vật tư cụm máy; tick van xả hiện danh sách', (
      tester,
    ) async {
      final config = _withModel('ACP-30PV');
      await open(tester, config);
      final s = AirStrings(AirLang.vi);
      expect(find.text(s.tabPipe), findsOneWidget);
      expect(find.text(s.kitTitle), findsOneWidget);
      expect(find.byKey(const Key('kit_table')), findsOneWidget);
      expect(find.byKey(const Key('kit_drain_table')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('kit_drain')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kit_drain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kit_drain_table')), findsOneWidget);
      expect(
        find.text('Van điện tử xả nước tự động Joc MIC-B (230V/15W)'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('kit_electric_table')), findsNothing);
      await tester.tap(find.byKey(const Key('air_config_save')));
      await tester.pumpAndSettle();
      final saved = await repository.get(config.id);
      expect([saved!.pipe.drainKit, saved.pipe.electricKit], [true, false]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('công suất chưa có dữ liệu: "Chưa cập nhật"', (tester) async {
      await open(tester, _withModel('ACP-60PV'));
      expect(find.byKey(const Key('kit_not_updated')), findsOneWidget);
      expect(find.byKey(const Key('kit_table')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
