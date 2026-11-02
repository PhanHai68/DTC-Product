import 'dart:math' as math;

import '../../../core/utils/air_tank_volume.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import '../models/catalog_compressor.dart';
import 'air_engine.dart';

/// Model app đã tính (cấu hình tự động [auto]) cho loại thiết bị — dùng khi
/// máy trong sơ đồ tuỳ chỉnh chưa chọn model riêng.
String? customDefaultModel(CustomKind kind, AirResult auto) => switch (kind) {
  CustomKind.compressor =>
    auto.compressor?.model?.modelCode ?? auto.compressor?.manualName,
  CustomKind.tank => auto.tank?.spec?.model,
  CustomKind.refrigeratedDryer =>
    auto.dryerPicks[DryerKind.refrigerated]?.spec.model,
  CustomKind.waterSeparator ||
  CustomKind.coarseFilter ||
  CustomKind.fineFilter ||
  CustomKind.ultraFineFilter ||
  CustomKind.carbonFilter => auto.lineFilter?.spec.model,
  CustomKind.afterCooler || CustomKind.desiccantDryer => null,
};

/// Khóa tổn áp trong `air_system_constants.json` của từng loại thiết bị.
String? _dropKey(CustomKind kind) => switch (kind) {
  CustomKind.compressor || CustomKind.tank => null,
  CustomKind.afterCooler => 'afterCooler',
  CustomKind.waterSeparator => 'waterSeparator',
  CustomKind.refrigeratedDryer => 'refrigeratedDryer',
  CustomKind.desiccantDryer => 'desiccantDryer',
  CustomKind.coarseFilter => 'coarseFilter',
  CustomKind.fineFilter => 'fineFilter',
  CustomKind.ultraFineFilter => 'sterileFilter',
  CustomKind.carbonFilter => 'carbonFilter',
};

/// Mã cảnh báo tính theo thiết bị của cấu hình tự động: bỏ khi dùng sơ đồ
/// tuỳ chỉnh và tính lại theo các máy trong sơ đồ.
const _deviceWarnings = {
  AirWarningCode.modelFlowLow,
  AirWarningCode.tankTooLarge,
  AirWarningCode.tankManualNotInCatalog,
  AirWarningCode.tankDesignHigh,
  AirWarningCode.noDryerModel,
  AirWarningCode.dryerPressureHigh,
  AirWarningCode.noTank,
  AirWarningCode.fourInOneIntegrated,
  AirWarningCode.oilNoOilFilter,
  AirWarningCode.desiccantNoOilFilter,
  AirWarningCode.purge,
};

/// Kết quả theo sơ đồ tuỳ chỉnh của [config] (đang bật), dựng từ kết quả tự
/// động [auto]: máy nén, bình, máy sấy, lọc theo từng máy trong sơ đồ; khí
/// đi qua mỗi máy chia đều theo ống nối; tổn áp cộng theo các tầng nối
/// tiếp. Nhu cầu, áp suất, line… giữ như cấu hình tự động.
AirResult applyCustomLayout(
  AirEngine engine,
  AirConfig config,
  AirResult auto,
) {
  final layout = config.custom;
  if (!layout.active) return auto;
  final c = engine.constants;
  final pressure = auto.pressure;
  final stages = layout.stages;

  // ── Từng máy: model, dữ liệu catalog, khí đi qua ──────────────────────
  final units = <CustomUnitCalc>[];
  var outflow = <double>[];
  for (var k = 0; k < stages.length; k++) {
    final st = stages[k];
    final inflow = List<double>.filled(st.qty, 0);
    if (k > 0) {
      final links = layout.linksFor(k);
      for (var i = 0; i < outflow.length; i++) {
        final targets = [
          for (final l in links)
            if (l.$1 == i) l.$2,
        ];
        for (final j in targets) {
          inflow[j] += outflow[i] / targets.length;
        }
      }
    }
    final next = <double>[];
    for (var j = 0; j < st.qty; j++) {
      final model = st.units[j].model ?? customDefaultModel(st.kind, auto);
      CatalogCompressor? compressor;
      var own = 0.0;
      if (st.kind == CustomKind.compressor) {
        compressor = engine.compressors
            .where((m) => m.modelCode == model)
            .firstOrNull;
        own = compressor?.flowAt(pressure) ?? compressor?.flowAt(8) ?? 0;
        // Máy nhập tay (không có trong dữ liệu) của cấu hình tự động.
        if (compressor == null &&
            model != null &&
            model == auto.compressor?.manualName) {
          own = auto.compressor?.flowAtPressure ?? 0;
        }
      }
      units.add(
        CustomUnitCalc(
          stage: k,
          index: j,
          kind: st.kind,
          model: model,
          inflow: st.kind == CustomKind.compressor ? own : inflow[j],
          compressor: compressor,
          tank: st.kind == CustomKind.tank
              ? engine.tanks.where((t) => t.model == model).firstOrNull
              : null,
          dryer: st.kind == CustomKind.refrigeratedDryer
              ? engine.refrigeratedDryers
                    .where((d) => d.model == model)
                    .firstOrNull
              : null,
          filter: st.kind.isFilter
              ? engine.lineFilters.where((f) => f.model == model).firstOrNull
              : null,
        ),
      );
      next.add(inflow[j] + own);
    }
    outflow = next;
  }

  final compressors = [
    for (final u in units)
      if (u.kind == CustomKind.compressor) u,
  ];
  final flow = compressors.fold(0.0, (s, u) => s + u.inflow);
  double kwOf(CustomUnitCalc u) =>
      u.compressor?.powerKW ??
      (u.model != null && u.model == auto.compressor?.manualName
          ? auto.compressor?.manualPowerKw ?? 0
          : 0);
  final kw = compressors.fold(0.0, (s, u) => s + kwOf(u));
  final electrical = <(String, Map<String, String>)>[];
  for (final u in compressors) {
    final model = u.compressor?.modelCode;
    if (model == null || electrical.any((e) => e.$1 == model)) continue;
    final row = engine.mccb.where((m) => m['model'] == model).firstOrNull;
    if (row != null) electrical.add((model, row));
  }
  final calc = CustomCalc(
    units: units,
    flow: flow,
    kw: kw,
    electrical: electrical,
  );

  // ── Máy nén: máy công suất lớn nhất làm đại diện (bộ vật tư, cỡ ống) ──
  final largest = compressors.isEmpty
      ? null
      : compressors.reduce((a, b) => kwOf(b) > kwOf(a) ? b : a);
  final sameModel =
      compressors.isNotEmpty &&
      compressors.every((u) => u.model == compressors.first.model);
  final compressor = largest == null
      ? auto.compressor
      : largest.compressor != null
      ? CompressorPick(
          model: largest.compressor,
          units: sameModel ? compressors.length : 1,
          flowAtPressure:
              largest.compressor!.flowAt(pressure) ??
              largest.compressor!.flowAt(8),
        )
      : auto.compressor;

  // ── Bình: tổng dung tích, model bình đầu tiên ─────────────────────────
  final tanks = [
    for (final u in units)
      if (u.kind == CustomKind.tank) u,
  ];
  final design = c.designPressureFor(pressure);
  final tankRequired = airTankTheoreticalLiters(qc: flow) / 1000;
  final tankVolume = tanks.fold(
    0.0,
    (s, u) => s + (u.tank?.volumeLiters ?? 0) / 1000,
  );
  final tank = tanks.isEmpty
      ? null
      : TankPick(
          spec: tanks.map((u) => u.tank).nonNulls.firstOrNull,
          volumeM3: tankVolume,
          requiredM3: tankRequired,
          designPressure: design,
        );

  // ── Máy sấy, lọc ──────────────────────────────────────────────────────
  final dryerKind = calc.has(CustomKind.desiccantDryer)
      ? DryerKind.desiccant
      : calc.has(CustomKind.refrigeratedDryer)
      ? DryerKind.refrigerated
      : DryerKind.none;
  final dryers = calc.of(CustomKind.refrigeratedDryer).toList();
  final dryerSpec = dryers.map((u) => u.dryer).nonNulls.firstOrNull;
  final dryerPicks = <DryerKind, DryerPick>{
    if (dryerSpec != null)
      DryerKind.refrigerated: DryerPick(
        spec: dryerSpec,
        units: dryers.length,
        inlet: flow,
      ),
  };
  final filterUnits = [
    for (final u in units)
      if (u.kind.isFilter) u,
  ];
  final filterSpec = filterUnits.map((u) => u.filter).nonNulls.firstOrNull;
  final water = calc.has(CustomKind.waterSeparator);
  final coarse = calc.has(CustomKind.coarseFilter);
  final fine = calc.has(CustomKind.fineFilter);
  final sterile = calc.has(CustomKind.ultraFineFilter);
  final carbon = calc.has(CustomKind.carbonFilter);
  final present = [water, coarse, fine];
  final lineFilter = filterSpec == null || !(water || coarse || fine)
      ? null
      : LineFilterPick(
          spec: filterSpec,
          units: [
            for (final st in stages)
              if (st.kind.isFilter) st.qty,
          ].fold(1, math.max),
          levels: [
            for (var k = 0; k < filterSpec.levels.length && k < 3; k++)
              if (present[k]) filterSpec.levels[k],
          ],
        );

  // ── Tổn áp: mỗi tầng một lần (các máy trong tầng chạy song song) ──────
  double drop(Iterable<CustomKind> kinds) =>
      {for (final k in kinds) ?_dropKey(k)}
          .fold(0.0, (s, key) => s + c.drop(key));
  final kinds = {for (final st in stages) st.kind};
  final treatDrop = drop(
    kinds.where(
      (k) => k.isDryer || (k.isFilter && k != CustomKind.waterSeparator),
    ),
  );
  final pretreatDrop = drop(
    kinds.where(
      (k) => k == CustomKind.afterCooler || k == CustomKind.waterSeparator,
    ),
  );
  final usePressure = config.treatment.usePressure;
  final pressureNeed = auto.pressureNeed > 0 && usePressure != null
      ? round1(usePressure + treatDrop + pretreatDrop + c.drop('piping'))
      : auto.pressureNeed;

  final base = auto.groups.firstOrNull;
  final groups = [
    AirGroup(
      kind: dryerKind,
      lineIndexes: base?.lineIndexes ?? auto.validLines,
      demand: auto.demand,
      purge: dryerKind == DryerKind.desiccant ? auto.purge : 0,
      pdp: base?.pdp,
      coarse: coarse,
      fine: fine,
      carbon: carbon,
      sterile: sterile,
      pressureDrop: treatDrop,
    ),
  ];

  // ── Chất lượng khí (cùng cách tính với cấu hình tự động) ──────────────
  final oilFree = config.compressor.type.isOilFree;
  final particle = sterile || fine
      ? 1
      : coarse
      ? 2
      : water
      ? 3
      : null;
  final oil = oilFree
      ? 0
      : carbon
      ? 1
      : fine
      ? 2
      : 4;
  final quality = [
    for (final q in auto.quality)
      LineQuality(
        lineIndex: q.lineIndex,
        group: dryerKind,
        particle: particle,
        water: dryerKind == DryerKind.none ? null : q.water,
        oil: oil,
      ),
  ];

  // ── Cảnh báo ──────────────────────────────────────────────────────────
  final warnings = [
    for (final w in auto.warnings)
      if (!_deviceWarnings.contains(w.code)) w,
  ];
  if (auto.demandBased && auto.required > 0 && flow + 1e-9 < auto.required) {
    warnings.add(
      AirWarning(WarningLevel.error, AirWarningCode.modelFlowLow, {
        'model': [for (final u in compressors) u.model ?? '—'].join(' + '),
        'flow': flow,
        'need': auto.required,
      }),
    );
  }
  for (final u in units) {
    final cap = u.capacity;
    if (cap != null && u.inflow > cap + 1e-9) {
      warnings.add(
        AirWarning(WarningLevel.caution, AirWarningCode.customUnitLow, {
          'kind': u.kind,
          'unit': u.index + 1,
          'count': stages[u.stage].qty,
          'model': u.model ?? '',
          'capacity': cap,
          'flow': u.inflow,
        }),
      );
    }
    final t = u.tank;
    if (t != null) {
      final need = airTankTheoreticalLiters(qc: u.inflow);
      if (u.inflow > 0 && t.volumeLiters + 1e-6 < need) {
        warnings.add(
          AirWarning(WarningLevel.caution, AirWarningCode.customUnitLow, {
            'kind': u.kind,
            'unit': u.index + 1,
            'count': stages[u.stage].qty,
            'model': u.model ?? '',
            'volume': t.volumeLiters / 1000,
            'needVolume': need / 1000,
            'flow': u.inflow,
          }),
        );
      }
    }
  }
  final weakTank = tanks
      .map((u) => u.tank)
      .nonNulls
      .where((t) => t.designPressureKgfCm2 + 1e-9 < design)
      .firstOrNull;
  if (weakTank != null) {
    warnings.add(
      AirWarning(WarningLevel.caution, AirWarningCode.tankDesignHigh, {
        'design': design,
        'tankDesign': weakTank.designPressureKgfCm2,
      }),
    );
  }
  if (dryerSpec != null && pressure > c.dryerMaxPressure + 1e-9) {
    warnings.add(
      AirWarning(WarningLevel.caution, AirWarningCode.dryerPressureHigh, {
        'model': dryerSpec.model,
        'max': c.dryerMaxPressure,
        'pressure': pressure,
      }),
    );
  }
  if (!oilFree && !fine) {
    warnings.add(
      const AirWarning(WarningLevel.caution, AirWarningCode.oilNoOilFilter),
    );
  }
  if (!oilFree && dryerKind == DryerKind.desiccant) {
    warnings.add(
      const AirWarning(
        WarningLevel.caution,
        AirWarningCode.desiccantNoOilFilter,
      ),
    );
  }
  final fourInOne = compressors
      .map((u) => u.compressor)
      .nonNulls
      .where((m) => m.isFourInOne)
      .firstOrNull;
  if (fourInOne != null) {
    warnings.add(
      AirWarning(WarningLevel.note, AirWarningCode.fourInOneIntegrated, {
        'model': fourInOne.modelCode,
        'tank': fourInOne.airTank,
      }),
    );
  }
  if (tanks.isEmpty) {
    warnings.add(const AirWarning(WarningLevel.note, AirWarningCode.noTank));
  }
  if (dryerKind == DryerKind.desiccant) {
    warnings.addAll(auto.warnings.where((w) => w.code == AirWarningCode.purge));
  }
  final sorted = [
    for (final level in WarningLevel.values)
      ...warnings.where((w) => w.level == level),
  ];

  return auto.withCustom(
    custom: calc,
    flow: flow > 0 ? flow : auto.flow,
    powerEstimate: kw > 0 ? kw : auto.powerEstimate,
    compressor: compressor,
    compressorQty: compressors.isEmpty
        ? auto.compressorQty
        : compressors.length,
    tank: tank,
    dryerPicks: dryerPicks,
    lineFilter: lineFilter,
    electrical: electrical.isEmpty
        ? null
        : electrical
              .firstWhere(
                (e) => e.$1 == largest?.compressor?.modelCode,
                orElse: () => electrical.first,
              )
              .$2,
    pressureNeed: pressureNeed,
    groups: groups,
    quality: quality,
    warnings: sorted,
  );
}
