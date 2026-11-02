import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram.dart';
import 'package:dtc_product/features/air_system_config/diagram/custom_equipment.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
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
