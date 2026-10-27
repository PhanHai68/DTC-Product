import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/acomp_tank_provider.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/engine/air_engine.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/models/air_result.dart';
import 'package:flutter_test/flutter_test.dart';

AirResult _run(AirConfig config) => appAirEngine().compute(config);

List<String> _iso(AirResult r) => [for (final q in r.quality) q.code];

int _drains(AirResult r) =>
    r.equipment
        .where((e) => e.kind == EquipmentKind.autoDrain)
        .firstOrNull
        ?.qty ??
    0;

bool _has(AirResult r, AirWarningCode code) =>
    r.warnings.any((w) => w.code == code);

bool _invalid(AirResult r, String field) =>
    r.warnings.any((w) => w.params['field'] == field);

/// Cấu hình đơn giản: một line, nhu cầu [demand] m³/phút.
AirConfig _config({
  double demand = 10,
  CompressorType type = CompressorType.pmVsd,
  LinePdp pdp = LinePdp.p3,
  double pressure = 8,
  double usePressure = 6,
}) => AirConfig(
  lines: [AirLine(name: 'Máy tách màu')],
  compressor: CompressorConfig(type: type, pressure: pressure, demand: demand),
  treatment: AirTreatment(pdp: pdp, usePressure: usePressure),
);

void main() {
  test('hằng số đọc từ air_system_constants.json', () {
    final c = airSystemConstants;
    expect(c.purgeRates, {'heatless': 0.15, 'heated': 0.07, 'blower': 0.02});
    expect(c.drop('piping'), 0.3);
    expect(c.motorSizesKw.first, 7.5);
    expect(c.motorSizesKw.last, 400);
    expect(c.designPressureFor(8), 10);
    expect(c.designPressureFor(8.1), 13);
    expect(c.designPressureFor(11), 13);
    expect(c.designPressureFor(12), 16);
    expect(c.maxLines, 20);
    expect(c.marginOptions, [15, 20, 25, 30]);
    expect(c.dryerMaxPressure, 10);
  });

  test('round1 làm tròn nửa lên, chống sai số', () {
    expect(round1(8.25), 8.3);
    expect(round1(6.5 + 0.55 + 0.1 + 0.3), 7.5);
    expect(round1(11.154), 11.2);
    expect(round1(10.925), 10.9);
  });

  group('Mẫu thực phẩm (sấy hấp thụ −40 °C)', () {
    late AirResult r;
    setUp(() => r = _run(AirConfigTemplate.food.build()));

    test('nhu cầu + khí xả → máy nén, áp, bình', () {
      // 15,5 + 15% khí xả = 17,825; dư 15% → ≥ 20,5: AFR-175F 22,52.
      expect(r.demand, 15.5);
      expect(r.purge, closeTo(2.325, 1e-9));
      expect(r.required, closeTo(17.825, 1e-9));
      expect(r.compressor!.model!.modelCode, 'AFR-175F');
      expect(r.flow, 22.52);
      expect(r.margin! * 100, closeTo(26.3, 0.1));
      // Áp sử dụng 7 + hấp thụ 0,25 + thô 0,10 + tinh 0,15 + after cooling
      // 0,10 + tách nước 0,10 + ống 0,30 = 8,0.
      expect(r.pressureNeed, 8.0);
      expect(r.compressor!.powerKw, 132);
      // 22,52 m³/phút → 3.875 L (công thức Tính thể tích bình chứa) → V4000.
      expect(r.tank!.spec!.model, 'V4000');
    });

    test('một nhóm chung cho mọi line; ISO và van xả', () {
      expect(r.groups.single.kind, DryerKind.desiccant);
      expect(r.groups.single.lineIndexes, [0, 1, 2]);
      expect(_iso(r), ['[1:2:0]', '[1:2:0]', '[1:2:0]']);
      // Bình + after cooling + tách nước + tách thô + tách tinh.
      expect(_drains(r), 5);
      expect(r.dryerPicks, isEmpty);
      expect(
        r.equipment.any((e) => e.kind == EquipmentKind.oilWaterSeparator),
        isFalse,
      );
    });
  });

  test('Mẫu xưởng cơ khí (sấy lạnh 2–10 °C): đủ áp, máy sấy ACD-13', () {
    final r = _run(AirConfigTemplate.workshop.build());
    expect(r.compressor!.model!.modelCode, 'ACP-100PV');
    // 6,5 + sấy lạnh 0,20 + thô 0,10 + tinh 0,15 + tách nước 0,10 + ống 0,30.
    expect(r.pressureNeed, 7.4);
    expect(r.hasErrors, isFalse);
    // Nước: 2–10 °C → lớp 6 (≤ 10 °C); dầu: tách tinh → lớp 2.
    expect(_iso(r).toSet(), {'[1:6:2]'});
    expect(r.dryerPicks[DryerKind.refrigerated]!.spec.model, 'ACD-13');
    // Bình + tách nước + thô + tinh + máy sấy lạnh.
    expect(_drains(r), 5);
    expect(r.equipment.any((e) => e.kind == EquipmentKind.mccb), isTrue);
  });

  group('Lọc đường ống theo lưu lượng máy nén', () {
    test('12,6 m³/phút → model 013 (13 m³/phút), đủ 3 cấp C/T/A', () {
      final r = _run(AirConfigTemplate.workshop.build());
      final f = r.lineFilter!;
      expect(f.spec.model, '013');
      expect(f.units, 1);
      expect(f.levels.map((l) => l.level), ['C', 'T', 'A']);
      final s = AirStrings(AirLang.vi);
      expect(s.lineFilterCard(r).$1, 'Model 013');
      expect(s.lineFilterCard(r).$2, 'C 3 µm · T 1 µm · A 0,01 µm');
      expect(s.dryerCard(r).$1, 'ACD-13');
      expect(s.compressorCardSub(r), startsWith('Lưu lượng: 12,6 m³/phút'));
    });

    test('vượt model lớn nhất → ghép nhiều bộ; bỏ hết lọc → không dùng', () {
      final big = _run(_config(demand: 30));
      expect(big.lineFilter!.spec.model, '020');
      expect(big.lineFilter!.units, greaterThan(1));
      final none = _run(
        _config()
          ..pretreat.standard = false
          ..pretreat.waterSeparator = false
          ..pretreat.coarseFilter = false
          ..pretreat.fineFilter = false,
      );
      expect(none.lineFilter, isNull);
      expect(AirStrings(AirLang.vi).lineFilterCard(none).$1, 'Không dùng');
    });
  });

  test('Mẫu nhà máy dược (−70 °C)', () {
    final r = _run(AirConfigTemplate.pharma.build());
    expect(r.purge, closeTo(0.2, 1e-9));
    expect(r.compressor!.model!.modelCode, 'AFR-100F');
    expect(r.compressorQty, 1);
    expect(r.pressureNeed, 8.0);
    expect(_iso(r).toSet(), {'[1:1:0]'});
  });

  group('Line chỉ là tên', () {
    test('số line và tên không ảnh hưởng tính toán', () {
      final one = _run(_config());
      final many = _run(
        _config()..lines.addAll([AirLine(name: 'Cân đóng gói'), AirLine()]),
      );
      expect(many.flow, one.flow);
      expect(many.pressureNeed, one.pressureNeed);
      expect(many.quality, hasLength(3));
      expect(many.groups.single.lineIndexes, [0, 1, 2]);
    });

    test('nhu cầu bắt buộc khi chọn theo nhu cầu; áp sử dụng bắt buộc', () {
      final config = _config()..compressor.demand = null;
      var r = _run(config);
      expect(_invalid(r, 'demand'), isTrue);
      expect(r.compressor, isNull);
      config
        ..compressor.demand = 10
        ..treatment.usePressure = null;
      r = _run(config);
      expect(_invalid(r, 'usePressure'), isTrue);
      expect(r.pressureNeed, 0);
    });

    test('áp cần = áp sử dụng + tổn áp; không sấy vẫn có thô + tinh', () {
      final r = _run(_config(pdp: LinePdp.none, usePressure: 6));
      // 6 + thô 0,10 + tinh 0,15 + tách nước 0,10 + ống 0,30 = 6,65 → 6,7.
      expect(r.pressureNeed, 6.7);
      final g = r.groups.single;
      expect(g.kind, DryerKind.none);
      expect(g.coarse && g.fine && !g.carbon && !g.sterile, isTrue);
      expect(_iso(r).single, '[1:X:2]');
    });
  });

  group('Máy nén theo nhu cầu / chọn model / nhập tay', () {
    test(
      'mức dư khách chọn: 12 → 15% ACP-125PV, 30% ACP-150PV, 0% ACP-100PV',
      () {
        final config = _config(demand: 12);
        expect(_run(config).compressor!.model!.modelCode, 'ACP-125PV');
        config.compressor.marginPercent = 30;
        final r = _run(config);
        expect(r.compressor!.model!.modelCode, 'ACP-150PV');
        expect(r.flow, 19.8);
        expect(r.margin! * 100, closeTo(65, 1e-6));
        config.compressor.marginPercent = 0;
        expect(_run(config).compressor!.model!.modelCode, 'ACP-100PV');
        config.compressor.marginPercent = null;
        expect(_invalid(_run(config), 'margin'), isTrue);
      },
    );

    test('chọn model: lưu lượng hệ thống = máy đã chọn, không tính mức dư', () {
      final config = _config()
        ..compressor.source = CompressorSource.catalog
        ..compressor.modelCode = 'ACP-75PV';
      final r = _run(config);
      expect(r.flow, 9.2);
      expect(r.required, 9.2);
      expect(r.margin, isNull);
      expect(r.hasErrors, isFalse);
      expect(
        r.tank!.requiredM3,
        closeTo(9.2 * 0.25 * 318.15 / (1.5 * 308.15), 1e-9),
      );
      // Model khác loại máy không được dùng.
      config.compressor.modelCode = 'ACP-75F';
      expect(_run(config).compressor, isNull);
    });

    test('nhập tay: bắt buộc lưu lượng máy (FAD)', () {
      final config = _config(type: CompressorType.twoStage)
        ..compressor.source = CompressorSource.manual
        ..compressor.manualName = 'TS-75';
      expect(_invalid(_run(config), 'manualFad'), isTrue);
      config.compressor.manualFad = 12;
      final r = _run(config);
      expect(r.flow, 12);
      expect(r.compressor!.manualName, 'TS-75');
      expect(_invalid(r, 'manualFad'), isFalse);
    });

    test('nhu cầu vượt model lớn nhất → nhiều máy', () {
      final pick = _run(_config(demand: 60, type: CompressorType.fixedSpeed))
          .compressor!;
      expect(pick.units, 2);
      expect(pick.flowAtPressure! * 2, greaterThanOrEqualTo(60 * 1.15));
    });

    test('vượt 400 kW cảnh báo chia máy', () {
      final r = _run(_config(demand: 80));
      expect(r.motorKw, isNull);
      expect(_has(r, AirWarningCode.powerOver), isTrue);
    });
  });

  group('Loại máy theo danh mục', () {
    test('4 IN 1: model ACA, ghi chú tích hợp máy sấy lạnh và bình', () {
      final r = _run(_config(demand: 2, type: CompressorType.fourInOne));
      expect(r.compressor!.model!.modelCode, startsWith('ACA-'));
      expect(_has(r, AirWarningCode.fourInOneIntegrated), isTrue);
    });

    test('FIXED SPEED chỉ chọn ACP-F', () {
      final r = _run(_config(type: CompressorType.fixedSpeed));
      expect(r.compressor!.model!.series, 'Fixed Speed');
    });

    test('2-STAGE: chưa có dữ liệu → ghi chú', () {
      final r = _run(_config(type: CompressorType.twoStage));
      expect(r.compressor, isNull);
      expect(_has(r, AirWarningCode.noCatalogModel), isTrue);
    });

    test('OIL-FREE: lưu lượng 8 / 10 / 12,5 bar của AFR', () {
      final config = _config(
        demand: 5.5,
        type: CompressorType.oilFree,
        pressure: 10,
      )..compressor.marginPercent = 0;
      var r = _run(config);
      expect(_iso(r).single.endsWith(':0]'), isTrue);
      expect(r.compressor!.model!.modelCode, 'AFR-50F'); // 5,80 @ 10 bar
      config.compressor.pressure = 11; // dùng lưu lượng 12,5 bar
      expect(_run(config).compressor!.model!.modelCode, 'AFR-60F');
      config.compressor.pressure = 13;
      r = _run(config);
      expect(r.compressor, isNull);
      expect(_has(r, AirWarningCode.catalogPressure), isTrue);
    });

    test('dữ liệu AFR: 20 dòng F + 20 dòng PV', () {
      expect(oilFreeSpecs.where((m) => !m.isVsd), hasLength(20));
      expect(oilFreeSpecs.where((m) => m.isVsd), hasLength(20));
      final pv100 = oilFreeSpecs.firstWhere((m) => m.model == 'AFR-100PV');
      expect(pv100.flow, {8.0: 12.6, 10.0: 11.42, 12.5: 9.85});
      expect(pv100.weightWaterKg, 1750);
    });
  });

  group('Lọc đường ống', () {
    test('tiêu chuẩn: tách nước trên tuyến chính, thô + tinh sau máy sấy', () {
      final config = _config();
      List<String> keys(AirResult r) => [
        for (final e in r.equipment)
          if (e.kind == EquipmentKind.waterSeparator ||
              e.kind == EquipmentKind.coarseFilter ||
              e.kind == EquipmentKind.fineFilter)
            e.key,
      ];
      expect(keys(_run(config)), [
        'waterSeparator',
        'coarse_refrigerated',
        'fine_refrigerated',
      ]);
      config.pretreat
        ..standard = false
        ..coarseFilter = false;
      expect(keys(_run(config)), ['waterSeparator', 'fine_refrigerated']);
    });

    test('lọc sau bình: 1 = thô, 2 = thô + tinh; bảo vệ máy sấy hấp thụ', () {
      final config = _config(pdp: LinePdp.m40);
      var r = _run(config);
      expect(_has(r, AirWarningCode.desiccantNoOilFilter), isTrue);
      final base = r.pressureNeed;
      config.pretreat.tankFilter = true;
      r = _run(config);
      expect(
        r.equipment
            .where((e) => e.params['afterTank'] == true)
            .map((e) => e.key),
        ['tankCoarse', 'tankFine'],
      );
      expect(r.pressureNeed, closeTo(base + 0.25, 0.051));
      expect(_has(r, AirWarningCode.desiccantNoOilFilter), isFalse);
      config.tank.enabled = false;
      expect(
        _run(config).equipment.any((e) => e.params['afterTank'] == true),
        isFalse,
      );
    });

    test('máy có dầu không có tách tinh: dầu lớp 4', () {
      final config = _config()
        ..pretreat.standard = false
        ..pretreat.fineFilter = false;
      final r = _run(config);
      expect(_has(r, AirWarningCode.oilNoOilFilter), isTrue);
      expect(r.quality.single.oil, 4);
      expect(r.quality.single.particle, 2);
    });
  });

  test('thiết bị điện theo bảng MCCB của model máy nén', () {
    final r = _run(AirConfigTemplate.workshop.build());
    final row = acompMccbData.firstWhere((m) => m['model'] == 'ACP-100PV');
    final rows = AirStrings(AirLang.vi).electricalRows(r);
    expect(rows.map((e) => e.$2), [
      '${row['mccbComp']} A',
      row['cableComp'],
      '${row['mcbDryer']} A',
      row['cableDryer'],
    ]);
    // Sấy hấp thụ: không có dòng MCB/cáp máy sấy lạnh.
    final desiccant = _run(
      _config(pdp: LinePdp.values.firstWhere((p) => (p.celsius ?? 0) < 0)),
    );
    expect(AirStrings(AirLang.vi).electricalRows(desiccant), hasLength(2));
  });

  group('Bình chứa', () {
    test('tự chọn: cùng công thức với màn Tính thể tích bình chứa', () {
      final r = _run(AirConfigTemplate.workshop.build());
      final tankScreen = AcompTankProvider()..setQc('${r.flow}');
      expect(r.tank!.requiredM3 * 1000, closeTo(tankScreen.vTh, 1e-6));
      expect(r.tank!.spec!.model, tankScreen.recommendedTank!.model);
    });

    test('áp > 8 bar cần bình thiết kế cao hơn dữ liệu', () {
      final r = _run(_config(pressure: 10, usePressure: 8));
      expect(r.tank!.designPressure, 13);
      expect(_has(r, AirWarningCode.tankDesignHigh), isTrue);
    });

    test('bình chọn tay: đúng cỡ lấy thông số, lệch thì ghi chú', () {
      final config = _config()..tank.manualVolumeM3 = 3;
      expect(_run(config).tank!.spec!.model, 'V3000');
      config.tank.manualVolumeM3 = 2.5;
      final r = _run(config);
      expect(r.tank!.spec, isNull);
      expect(_has(r, AirWarningCode.tankManualNotInCatalog), isTrue);
    });
  });

  group('Máy sấy lạnh ACD theo công suất máy nén', () {
    test('toàn bộ khí máy nén qua máy sấy: nhu cầu 10 → ACP-100PV 12,6 → '
        'ACD-13', () {
      final r = _run(_config());
      final d = r.dryerPicks[DryerKind.refrigerated]!;
      expect(d.inlet, 12.6);
      expect(d.spec.model, 'ACD-13');
      final item = r.equipment.firstWhere(
        (e) => e.kind == EquipmentKind.refrigeratedDryer,
      );
      final s = AirStrings(AirLang.vi);
      expect(s.equipmentName(item), 'Máy sấy tác nhân lạnh ACD-13');
      expect(
        s.equipmentSpec(item),
        contains('13,5 m³/phút/máy (cần 12,6 m³/phút)'),
      );
    });

    test('mặc định theo bảng máy nén tương ứng: ACP-75PV 55 kW → ACD-10', () {
      final r = _run(
        _config()
          ..compressor.source = CompressorSource.catalog
          ..compressor.modelCode = 'ACP-75PV',
      );
      final d = r.dryerPicks[DryerKind.refrigerated]!;
      expect(r.compressor!.powerKw, 55);
      expect(d.compressorKw, 55);
      expect(d.spec.model, 'ACD-10');
      final item = r.equipment.firstWhere(
        (e) => e.kind == EquipmentKind.refrigeratedDryer,
      );
      expect(
        AirStrings(AirLang.vi).equipmentSpec(item),
        contains('theo máy nén 55 kW'),
      );
    });

    test('vượt ACD-100 → nhiều máy; áp > 10 bar → bản áp cao', () {
      final big = _run(
        _config()
          ..compressor.source = CompressorSource.manual
          ..compressor.manualFad = 150,
      ).dryerPicks[DryerKind.refrigerated]!;
      expect(big.units, 2);
      expect(big.spec.model, 'ACD-80');
      final high = _run(_config(pressure: 11, usePressure: 8));
      expect(_has(high, AirWarningCode.dryerPressureHigh), isTrue);
    });
  });

  group('JSON', () {
    test('xuất ra nhập lại giữ nguyên cấu hình và kết quả', () {
      final original = AirConfigTemplate.pharma.build()
        ..overrides['tank'] = EquipmentOverride(name: 'Bình inox')
        ..extraItems.add(ExtraEquipment(name: 'Van bi', spec: 'DN50', qty: 3));
      final restored = AirConfig.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(_iso(_run(restored)), _iso(_run(original)));
      expect(_run(restored).equipment.last.qty, 3);
    });

    test('cấu hình cũ (line có lưu lượng, áp, điểm sương) chuyển sang mới', () {
      final old = AirConfig.fromJson({
        'compressor': {'type': 'oilInjected', 'source': 'auto'},
        'lines': [
          {
            'name': 'Line 1',
            'flow': 10,
            'pMin': 8,
            'pMax': 8,
            'pdp': 'm40',
            'carbon': true,
          },
          {'name': 'Line 2', 'flow': 4, 'pMin': 6, 'pMax': 7, 'pdp': 'p3'},
        ],
      });
      expect(old.compressor.demand, 14);
      expect(old.compressor.source, CompressorSource.demand);
      expect(old.treatment.pdp, LinePdp.m40);
      expect(old.treatment.usePressure, 8);
      expect(old.lines.map((l) => l.name), ['Line 1', 'Line 2']);
    });

    test('loại máy / cách chọn cũ vẫn đọc được', () {
      AirConfig read(String type, [String? series]) => AirConfig.fromJson({
        'compressor': {'type': type, 'series': ?series},
        'lines': [],
      });
      expect(read('oilFreeWater').compressor.type, CompressorType.oilFree);
      expect(read('oilInjected').compressor.type, CompressorType.pmVsd);
      expect(
        read('oilInjected', 'Fixed Speed').compressor.type,
        CompressorType.fixedSpeed,
      );
    });
  });

  test('20 line tính dưới 200 ms', () {
    final config = _config()
      ..lines.addAll([for (var i = 2; i <= 20; i++) AirLine(name: 'Line $i')]);
    final watch = Stopwatch()..start();
    final r = _run(config);
    watch.stop();
    expect(r.quality, hasLength(20));
    expect(watch.elapsedMilliseconds, lessThan(200));
  });
}
