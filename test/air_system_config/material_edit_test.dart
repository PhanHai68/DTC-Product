import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/pipe/material_list.dart';
import 'package:dtc_product/features/air_system_config/pipe/pipe_strings.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
import 'package:dtc_product/features/air_system_config/screens/air_config_editor_screen.dart';
import 'package:dtc_product/features/air_system_config/services/air_config_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _s = AirStrings(AirLang.vi);

/// Máy nén ACP-30PV (bộ vật tư 30HP), tuyến ống [lengthM] m.
AirConfig _config({double? lengthM = 40}) => AirConfigTemplate.workshop.build()
  ..compressor.source = CompressorSource.catalog
  ..compressor.modelCode = 'ACP-30PV'
  ..pipe.totalLengthM = lengthM;

List<MaterialRow> _rows(MaterialList list, AirConfig c) {
  final r = appAirEngine().compute(c);
  return buildMaterialRows(
    list,
    c,
    kit: installKits.forPowerKw(r.compressor?.powerKw),
    pipe: appPipeEngine().compute(c, r),
  );
}

void main() {
  test('sửa / xoá / thêm vật tư cụm máy; lưu JSON; khôi phục', () {
    final c = _config();
    final auto = _rows(MaterialList.kit, c);
    expect(auto.first.name, 'Van bi đồng DN25, PN16 ( loại tay gạt)');
    expect(auto.every((r) => !r.isEdited && !r.isExtra), isTrue);

    // Sửa số lượng dòng đầu: chỉ lưu trường đã đổi.
    c.saveMaterial(
      MaterialList.kit,
      auto.first,
      name: auto.first.name,
      spec: auto.first.spec!,
      unit: auto.first.unit,
      qty: 12,
    );
    final edit = c.pipe.edits['kit']!.rows[auto.first.key]!;
    expect([edit.name, edit.spec, edit.unit, edit.qty], [null, null, null, 12]);
    // Xoá dòng thứ hai, thêm một vật tư.
    c.removeMaterial(MaterialList.kit, auto[1]);
    c.addMaterial(
      MaterialList.kit,
      name: 'Van an toàn',
      spec: 'DN15',
      unit: 'Cái',
      qty: 2,
    );

    final back = AirConfig.fromJson(c.toJson());
    final rows = _rows(MaterialList.kit, back);
    expect(rows.length, auto.length);
    expect(rows.first.qty, 12);
    expect(rows.first.isEdited, isTrue);
    expect(rows.map((r) => r.name), isNot(contains(auto[1].name)));
    expect(rows.last.name, 'Van an toàn');
    expect(rows.last.isExtra, isTrue);

    // Về giá trị tự tính, rồi khôi phục cả danh sách.
    back.resetMaterial(MaterialList.kit, rows.first);
    expect(_rows(MaterialList.kit, back).first.qty, 10);
    back.resetMaterialList(MaterialList.kit);
    expect(back.pipe.edits, isEmpty);
    expect(_rows(MaterialList.kit, back).length, auto.length);
  });

  test('vật tư đường ống: sửa tên vẫn tự tính số lượng theo chiều dài', () {
    final c = _config();
    Iterable<MaterialRow> pipes() =>
        _rows(MaterialList.pipe, c).where((r) => r.key == 'r4');
    final pipe = pipes().single;
    expect(pipe.name, 'Ống kẽm Ø34 *3.2mm*6000');
    // 40 m → 3 bước: 45 m ống → nguyên cây 6 m: 48 m.
    expect(pipe.qty, 48);
    c.saveMaterial(
      MaterialList.pipe,
      pipe,
      name: 'Ống kẽm Ø34 dày',
      spec: pipe.spec ?? '',
      unit: pipe.unit,
      qty: pipe.qty.toDouble(),
    );
    c.pipe.totalLengthM = 60;
    final after = pipes().single;
    expect(after.name, 'Ống kẽm Ø34 dày');
    // 60 m → 4 bước: 60 m ống (đủ 10 cây).
    expect(after.qty, 60);
  });

  test('file Excel theo danh sách đã sửa tay', () {
    final c = _config()..pipe.drainKit = true;
    final kit = _rows(MaterialList.kit, c);
    c.saveMaterial(
      MaterialList.kit,
      kit.first,
      name: 'Van bi đồng DN25 loại tốt',
      spec: kit.first.spec!,
      unit: kit.first.unit,
      qty: kit.first.qty.toDouble(),
    );
    c.removeMaterial(MaterialList.drain, _rows(MaterialList.drain, c).last);
    c.addMaterial(
      MaterialList.pipe,
      name: 'Van khoá cuối tuyến',
      spec: 'DN25',
      unit: 'cái',
      qty: 1,
    );
    final r = appAirEngine().compute(c);
    final doc = AirConfigExportService.poDocument(
      c,
      r,
      pipe: appPipeEngine().compute(c, r),
      kits: installKits,
    );
    expect(doc.sections[0].lines.first.name, 'Van bi đồng DN25 loại tốt');
    expect(doc.sections[1].lines.last.name, 'Van khoá cuối tuyến');
    expect(doc.sections[1].lines.last.unit, 'Cái');
    expect(doc.sections[2].lines, hasLength(3));
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

    testWidgets('chạm dòng → sửa số lượng; thêm vật tư; không còn "Cỡ ống"', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = _config();
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
      expect(find.text('Cỡ ống'), findsNothing);

      // Chưa tick "Cho phép sửa": chạm dòng không mở hộp sửa, không có nút
      // thêm vật tư.
      final vanBi = find.text('Van bi đồng DN25, PN16 ( loại tay gạt)');
      await tester.tap(vanBi);
      await tester.pumpAndSettle();
      expect(find.text(_s.matEdit), findsNothing);
      expect(find.byKey(const Key('kit_table_add')), findsNothing);

      // Tick "Cho phép sửa" rồi sửa số lượng van bi (dòng 1) từ 10 thành 12.
      await tester.tap(find.byKey(const Key('kit_table_edit')));
      await tester.pumpAndSettle();
      await tester.tap(vanBi);
      await tester.pumpAndSettle();
      expect(find.text(_s.matEdit), findsOneWidget);
      await tester.enterText(find.byKey(const Key('material_qty')), '12');
      await tester.tap(find.byKey(const Key('material_save')));
      await tester.pumpAndSettle();
      // Ô "12" giờ có ở cả cột STT (dòng 12) và cột SL dòng 1.
      final table = find.byKey(const Key('kit_table'));
      expect(
        find.descendant(of: table, matching: find.text('12')),
        findsNWidgets(2),
      );

      // Thêm vật tư cuối bảng cụm máy.
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('air_pipe_view')),
            matching: find.byType(Scrollable),
          )
          .first;
      final add = find.byKey(const Key('kit_table_add'));
      await tester.scrollUntilVisible(add, 400, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      // Thiếu tên: báo lỗi, chưa đóng hộp.
      await tester.tap(find.byKey(const Key('material_save')));
      await tester.pumpAndSettle();
      expect(find.text(_s.matNameRequired), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('material_name')),
        'Van an toàn',
      );
      await tester.enterText(find.byKey(const Key('material_unit')), 'Cái');
      await tester.tap(find.byKey(const Key('material_save')));
      await tester.pumpAndSettle();
      expect(find.text('Van an toàn'), findsOneWidget);
      expect(find.byKey(const Key('kit_table_reset')), findsOneWidget);

      await tester.tap(find.byKey(const Key('air_config_save')));
      await tester.pumpAndSettle();
      final saved = await repository.get(config.id);
      final kit = saved!.pipe.edits['kit']!;
      expect(kit.extras.single.name, 'Van an toàn');
      expect(kit.rows.values.single.qty, 12);
      expect(tester.takeException(), isNull);
    });
  });
}
