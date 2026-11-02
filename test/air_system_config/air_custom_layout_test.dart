import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram.dart';
import 'package:dtc_product/features/air_system_config/diagram/custom_equipment.dart';
import 'package:dtc_product/features/air_system_config/engine/custom_calc.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/models/air_result.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
import 'package:dtc_product/features/air_system_config/room/room_engine.dart';
import 'package:dtc_product/features/air_system_config/screens/air_config_editor_screen.dart';
import 'package:dtc_product/features/air_system_config/services/air_config_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Cấu hình ACP-100PV + 2 line, sơ đồ tuỳ chỉnh 2 máy nén (ACP-100PV,
/// ACP-50PV) và [tanks] bình, nối riêng từng máy khi [paired].
(AirConfig, CustomEquipment) _custom({int tanks = 2, bool paired = true}) {
  final config = AirConfig()
    ..compressor.modelCode = 'ACP-100PV'
    ..lines.add(AirLine(name: 'Máy tách màu'));
  final engine = appAirEngine();
  final r = engine.compute(config);
  final eq = CustomEquipment(engine, config, r, AirStrings(AirLang.vi));
  final layout = customLayoutFromResult(config, r);
  layout.stages.first.units.add(CustomUnit(model: 'ACP-50PV'));
  final tank = layout.stages.firstWhere((st) => st.kind == CustomKind.tank);
  while (tank.units.length < tanks) {
    tank.units.add(CustomUnit());
  }
  tank.paired = paired;
  config.custom
    ..enabled = true
    ..stages.addAll(layout.stages);
  return (config, eq);
}

List<String> _overlaps(AirDiagram d) {
  final texts = d.texts.toList();
  return [
    for (var i = 0; i < texts.length; i++)
      for (var j = i + 1; j < texts.length; j++)
        if (texts[i].box.deflate(1).overlaps(texts[j].box.deflate(1)))
          '"${texts[i].text}" × "${texts[j].text}"',
  ];
}

void main() {
  test('dựng từ cấu hình tự động: đúng thứ tự tầng, model mặc định', () {
    final config = AirConfigTemplate.food.build();
    config.pretreat.carbonFilter = true;
    final r = appAirEngine().compute(config);
    final layout = customLayoutFromResult(config, r);
    final kinds = [for (final st in layout.stages) st.kind];
    expect(kinds.first, CustomKind.compressor);
    expect(
      kinds.indexOf(CustomKind.tank),
      lessThan(kinds.indexOf(CustomKind.waterSeparator)),
    );
    expect(kinds.last, CustomKind.carbonFilter);
    expect(
      layout.stages.every((st) => st.units.every((u) => u.model == null)),
      isTrue,
    );
  });

  for (final (name, tanks, paired) in [
    ('mỗi máy một bình', 2, true),
    ('2 máy chung 1 bình', 1, false),
    ('2 máy, 2 bình gộp ống', 2, false),
  ]) {
    test('sơ đồ $name: không chồng chữ, đủ ống, thiết bị', () {
      final (config, eq) = _custom(tanks: tanks, paired: paired);
      final d = buildCustomAirDiagram(config, eq.result, eq.s, eq);
      expect(_overlaps(d), isEmpty);
      expect(
        d.shapes.whereType<DImage>().where(
          (i) => i.asset == AirDiagramAssets.compressor,
        ),
        hasLength(2),
      );
      expect(
        d.shapes.whereType<DImage>().where(
          (i) => i.asset == AirDiagramAssets.tank,
        ),
        hasLength(tanks),
      );
      expect(
        d.texts.map((t) => t.text),
        contains(
          '2 máy nén khí + $tanks '
          'bình chứa khí + 1 máy sấy lạnh',
        ),
      );
    });
  }

  test('phiếu đề nghị vật tư: thiết bị chính theo sơ đồ tuỳ chỉnh', () {
    final (config, eq) = _custom();
    final doc = AirConfigExportService.poDocument(
      config,
      eq.result,
      custom: eq,
    );
    final compressors = doc.equipment.where((l) => l.name == 'Máy nén khí');
    expect(compressors.map((l) => l.spec!.split(' – ').first), [
      'ACP-100PV',
      'ACP-50PV',
    ]);
    expect(doc.equipment.firstWhere((l) => l.name == 'Bình chứa khí').qty, 2);
    // Tắt sơ đồ tuỳ chỉnh: về danh mục tự động.
    config.custom.enabled = false;
    final auto = AirConfigExportService.poDocument(
      config,
      eq.result,
      custom: eq,
    );
    expect(auto.equipment.where((l) => l.name == 'Máy nén khí'), isEmpty);
  });

  test('đường ống tuỳ chỉnh: vẽ đúng số ống, lưu / đọc', () {
    final (config, eq) = _custom(tanks: 2, paired: false);
    final k = config.custom.stages.indexWhere(
      (st) => st.kind == CustomKind.tank,
    );
    // Máy nén 1 → bình 1 và bình 2; máy nén 2 → bình 2.
    config.custom.stages[k].links = [(0, 0), (0, 1), (1, 1)];
    expect(config.custom.connection(k), CustomConnection.custom);
    final d = buildCustomAirDiagram(config, eq.result, eq.s, eq);
    expect(_overlaps(d), isEmpty);
    final back = AirConfig.fromJson(config.toJson());
    expect(back.custom.linksFor(k), [(0, 0), (0, 1), (1, 1)]);
    expect(back.custom.unlinked(k).$1, isEmpty);
  });

  group('tính theo sơ đồ tuỳ chỉnh', () {
    test('tổng lưu lượng, công suất từng máy; tắt thì như tự động', () {
      final (config, eq) = _custom();
      final engine = eq.engine;
      final auto = eq.result;
      final r = applyCustomLayout(engine, config, auto);
      double flowOf(String code) => engine.compressors
          .firstWhere((m) => m.modelCode == code)
          .flowAt(r.pressure)!;
      double kwOf(String code) =>
          engine.compressors.firstWhere((m) => m.modelCode == code).powerKW;
      final flow = flowOf('ACP-100PV') + flowOf('ACP-50PV');
      expect(r.custom!.flow, closeTo(flow, 1e-9));
      expect(r.flow, closeTo(flow, 1e-9));
      expect(r.compressorQty, 2);
      // Máy lớn nhất làm đại diện (bộ vật tư cụm máy, cỡ ống).
      expect(r.compressor!.model!.modelCode, 'ACP-100PV');
      final s = AirStrings(AirLang.vi);
      expect(
        s.powerCard(r).$2,
        '${s.n2(kwOf('ACP-100PV') + kwOf('ACP-50PV'))} kW',
      );
      expect(s.compressorCardSub(r), contains('ACP-100PV + ACP-50PV'));
      expect(s.tankCardSub(r.tank, r), startsWith('2 × '));
      config.custom.enabled = false;
      expect(identical(applyCustomLayout(engine, config, auto), auto), isTrue);
    });

    test('khí chia theo ống nối; máy sấy nhỏ → cảnh báo', () {
      final (config, eq) = _custom();
      final engine = eq.engine;
      final dryer = config.custom.stages.firstWhere(
        (st) => st.kind == CustomKind.refrigeratedDryer,
      );
      dryer.units.single.model = engine.refrigeratedDryers.first.model;
      final r = applyCustomLayout(engine, config, eq.result);
      final tanks = r.custom!.of(CustomKind.tank).toList();
      final comps = r.custom!.of(CustomKind.compressor).toList();
      // Nối riêng: bình k nhận khí của máy nén k.
      expect(tanks[0].inflow, closeTo(comps[0].inflow, 1e-9));
      expect(tanks[1].inflow, closeTo(comps[1].inflow, 1e-9));
      // Máy sấy nhận toàn bộ khí.
      expect(
        r.custom!.of(CustomKind.refrigeratedDryer).single.inflow,
        closeTo(r.custom!.flow, 1e-9),
      );
      final low = r.warnings.where(
        (w) => w.code == AirWarningCode.customUnitLow,
      );
      expect(
        low.map((w) => w.params['kind']),
        contains(CustomKind.refrigeratedDryer),
      );
      expect(
        AirStrings(AirLang.vi).warning(
          low.firstWhere(
            (w) => w.params['kind'] == CustomKind.refrigeratedDryer,
          ),
        ),
        contains('nhỏ hơn'),
      );
    });

    test('tổn áp theo tầng: bỏ lọc tách tinh thì giảm, có cảnh báo dầu', () {
      final (config, eq) = _custom();
      final engine = eq.engine;
      final before = applyCustomLayout(engine, config, eq.result);
      expect(before.pressureNeed, closeTo(eq.result.pressureNeed, 1e-9));
      config.custom.stages.removeWhere(
        (st) => st.kind == CustomKind.fineFilter,
      );
      config.custom.prune();
      final after = applyCustomLayout(engine, config, eq.result);
      expect(
        after.pressureNeed,
        closeTo(
          before.pressureNeed - engine.constants.drop('fineFilter'),
          0.051,
        ),
      );
      expect(
        after.warnings.map((w) => w.code),
        contains(AirWarningCode.oilNoOilFilter),
      );
      expect(after.groups.single.fine, isFalse);
    });

    test('phòng lắp đặt: mỗi máy một ô, đúng model, lọc theo tầng', () {
      final (config, eq) = _custom();
      final r = applyCustomLayout(eq.engine, config, eq.result);
      final room = appRoomEngine().compute(config, r);
      expect(room.of(RoomItemKind.compressor).map((i) => i.model), [
        'ACP-100PV',
        'ACP-50PV',
      ]);
      expect(room.of(RoomItemKind.tank), hasLength(2));
      final filterUnits = config.custom.stages
          .where((st) => st.kind.isFilter)
          .fold(0, (n, st) => n + st.qty);
      expect(room.filters, hasLength(filterUnits));
      expect(room.ventilation.compressorKw, closeTo(r.custom!.kw, 1e-9));
    });
  });

  test('lưu / đọc JSON giữ sơ đồ tuỳ chỉnh', () {
    final (config, _) = _custom();
    final back = AirConfig.fromJson(config.toJson());
    expect(back.custom.active, isTrue);
    expect(back.custom.stages.first.units.last.model, 'ACP-50PV');
    expect(
      back.custom.stages.firstWhere((st) => st.kind == CustomKind.tank).paired,
      isTrue,
    );
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

    testWidgets('Tuỳ chỉnh cấu hình: bật, thêm máy nén, nối riêng bình', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = AirConfig()..compressor.modelCode = 'ACP-100PV';
      await tester.pumpWidget(
        MaterialApp(
          home: AirConfigEditorScreen(
            initial: config,
            repository: repository,
            initialTab: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('air_custom_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('air_custom_open')));
      await tester.pumpAndSettle();
      expect(find.text('Tuỳ chỉnh cấu hình'), findsOneWidget);
      await tester.tap(find.byKey(const Key('air_custom_enabled')));
      await tester.pumpAndSettle();
      expect(config.custom.active, isTrue);
      expect(config.custom.stages.first.kind, CustomKind.compressor);
      // Máy nén ×2, bình ×2 → hiện ô "Nối riêng từng máy".
      await tester.tap(find.byKey(const ValueKey('air_custom_plus_0')));
      await tester.pumpAndSettle();
      expect(config.custom.stages.first.qty, 2);
      await tester.tap(find.byKey(const ValueKey('air_custom_plus_1')));
      await tester.pumpAndSettle();
      final conn = find.byKey(const ValueKey('air_custom_conn_1'));
      await tester.tap(
        find.descendant(of: conn, matching: find.text('Nối riêng')),
      );
      await tester.pumpAndSettle();
      expect(config.custom.isPaired(1), isTrue);
      // Tuỳ chỉnh: bắt đầu từ 2 ống nối riêng; bỏ ống máy 2 → bình 2, thêm
      // máy 2 → bình 1.
      await tester.tap(
        find.descendant(of: conn, matching: find.text('Tuỳ chỉnh')),
      );
      await tester.pumpAndSettle();
      expect(config.custom.linksFor(1), [(0, 0), (1, 1)]);
      await tester.tap(find.byKey(const ValueKey('air_custom_link_1_1_1')));
      await tester.pumpAndSettle();
      expect(find.text('Máy 2 chưa có ống vào'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('air_custom_link_1_1_0')));
      await tester.pumpAndSettle();
      expect(config.custom.linksFor(1), [(0, 0), (1, 0)]);
      // Bớt máy nén còn 1: ống từ máy 2 bị bỏ.
      await tester.tap(find.byKey(const ValueKey('air_custom_minus_0')));
      await tester.pumpAndSettle();
      expect(config.custom.linksFor(1), [(0, 0)]);
      expect(tester.takeException(), isNull);
    });
  });
}
