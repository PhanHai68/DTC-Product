import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/pipe/pipe_engine.dart';
import 'package:dtc_product/features/air_system_config/pipe/pipe_strings.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
import 'package:dtc_product/features/air_system_config/screens/air_config_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Máy nén chọn theo model; tuyến ống [lengthM] m.
AirConfig _config(String model, double? lengthM) =>
    AirConfigTemplate.workshop.build()
      ..compressor.source = CompressorSource.catalog
      ..compressor.modelCode = model
      ..pipe.totalLengthM = lengthM;

PipeResult _pipe(AirConfig c) =>
    appPipeEngine().compute(c, appAirEngine().compute(c));

/// Số lượng theo tên vật tư.
Map<String, num> _qty(PipeResult r) => {for (final i in r.items) i.name: i.qty};

void main() {
  test('định mức 15 m: 18 vật tư, 3 cỡ ống, khớp tên / mã file PO', () {
    final k = pipeRunKit;
    expect(k.stepM, 15);
    expect(k.items, hasLength(18));
    expect(k.sizes, [25, 40, 50]);
    expect(k.dnByHp, {30: 25, 50: 40, 75: 50, 100: 50});
    // Vật tư theo cỡ ống: tên + mã có trong bộ vật tư cụm máy cùng cỡ.
    final kitNames = {
      for (final kit in installKits.kits)
        for (final i in kit.standard.items) (i.name, i.code),
    };
    for (final item in k.items) {
      for (final v in item.sizes.values) {
        expect(kitNames, contains((v.name, v.code)), reason: v.name);
      }
    }
    final consumables = k.items.where((i) => i.note == 'VT tiêu hao');
    expect(consumables, hasLength(9));
    expect(k.items.last.variant!.name, 'Que hàn 2.5mm');
  });

  test('chưa nhập tổng chiều dài: chưa có vật tư, nhắc nhập', () {
    final r = _pipe(_config('ACP-100PV', null));
    expect(r.items, isEmpty);
    expect(r.warnings.single.code, PipeWarningCode.missingLength);
  });

  test('số bước: lấy bằng hoặc lớn hơn gần nhất bội số 15 m', () {
    for (final (length, steps) in [
      (10.0, 1),
      (15.0, 1),
      (15.5, 2),
      (40.0, 3),
      (45.0, 3),
      (61.0, 5),
    ]) {
      final r = _pipe(_config('ACP-100PV', length));
      expect(r.steps, steps, reason: '$length m');
      expect(r.coveredM, steps * 15);
    }
  });

  test('máy 100HP (DN50), 40 m → 3 bước: nhân số lượng, làm tròn', () {
    final r = _pipe(_config('ACP-100PV', 40));
    expect(r.dn, 50);
    expect(r.warnings, isEmpty);
    expect(r.items, hasLength(18));
    final q = _qty(r);
    expect(q['Van bi đồng DN50, PN16 ( loại tay gạt)'], 3);
    expect(q['Racco'], 6);
    expect(q['Co ren 90°'], 12);
    // 15 m × 3 = 45 m → nguyên cây 6 m: 48 m.
    expect(q['Ống kẽm Ø60 *3.2mm*6000'], 48);
    // 0,5 cây × 3 = 1,5 → 2 cây.
    expect(q['V50 x5mm, dài 6m'], 2);
    expect(q['Băng keo non'], 75);
    final pipe = r.items.firstWhere((i) => i.name.startsWith('Ống kẽm'));
    expect(
      [pipe.code, pipe.unit, pipe.spec],
      ['THEPO.60*3.2*6000', 'Mét', 'Ø60 *3.2mm*6000mm'],
    );
    expect(r.items.last.note, 'VT tiêu hao');
  });

  test('cỡ ống theo công suất: 30HP → DN25, 50HP → DN40', () {
    final r30 = _pipe(_config('ACP-30PV', 15));
    expect(r30.dn, 25);
    expect(_qty(r30)['Ống kẽm Ø34 *3.2mm*6000'], 18);
    expect(_qty(r30)['Cùm U (ren M6) cố định ống 34'], 5);
    expect(_qty(r30)['V40 x3mm, dài 6m'], 1);
    final r50 = _pipe(_config('ACP-50PV', 15));
    expect(r50.dn, 40);
    final van = r50.items.first;
    expect(
      [van.code, van.name],
      ['VANBID40-16', 'Van bi đồng DN40, PN16 ( loại tay gạt)'],
    );
  });

  test('cỡ ống chưa có định mức: báo, không có vật tư', () {
    // ACP-150PV: 110 kW, chưa có bộ vật tư cụm máy, lỗ thoát khí DN65.
    final r = _pipe(_config('ACP-150PV', 30));
    expect(r.items, isEmpty);
    final w = r.warnings.single;
    expect(w.code, PipeWarningCode.noSize);
    expect(w.params['dn'], 65);
    expect(AirStrings(AirLang.vi).pipeWarning(w), contains('DN65'));
  });

  test('tổng chiều dài lưu cùng cấu hình (JSON)', () {
    final c = _config('ACP-100PV', 42.5);
    final back = AirConfig.fromJson(c.toJson());
    expect(back.pipe.totalLengthM, 42.5);
  });

  group('tab Vật tư lắp đặt — đường ống', () {
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

    testWidgets('nhập tổng chiều dài → bảng vật tư theo bước; lưu', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = _config('ACP-100PV', null);
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
      final s = AirStrings(AirLang.vi);
      expect(find.text(s.tabPipe), findsOneWidget);
      // Vật tư lắp đặt cụm máy ở trên: cuộn xuống phần đường ống.
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('air_pipe_view')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(
          s.pipeWarning(const PipeWarning(PipeWarningCode.missingLength)),
        ),
        400,
        scrollable: scrollable,
      );
      // Chỉ còn ô tổng chiều dài.
      expect(find.text('Số lần bẻ góc 90°'), findsNothing);
      await tester.ensureVisible(find.widgetWithText(TextField, s.pipeLength));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, s.pipeLength),
        '40',
      );
      await tester.pumpAndSettle();
      final table = find.byKey(const Key('pipe_bom_table'));
      await tester.scrollUntilVisible(table, 400, scrollable: scrollable);
      expect(
        find.descendant(
          of: table,
          matching: find.text('Ống kẽm Ø60 *3.2mm*6000'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Tính cho 45 m (3 bước × 15 m)'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.byKey(const Key('air_config_save')));
      await tester.pumpAndSettle();
      final saved = await repository.get(config.id);
      expect(saved!.pipe.totalLengthM, 40);
      expect(tester.takeException(), isNull);
    });
  });
}
