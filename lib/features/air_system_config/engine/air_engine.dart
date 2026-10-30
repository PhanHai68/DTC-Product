import 'dart:math' as math;

import '../../../core/utils/air_tank_volume.dart';
import '../../../models/air_tank_spec.dart';
import '../../../models/line_filter_spec.dart';
import '../../../models/refrigerated_dryer_spec.dart';
import '../models/air_config.dart';
import '../models/air_constants.dart';
import '../models/air_result.dart';
import '../models/catalog_compressor.dart';

/// Làm tròn 0,1 kiểu nửa lên, chống sai số dấu phẩy động (8,25 → 8,3).
double round1(double value) => ((value * 10) + 1e-7).roundToDouble() / 10;

/// Bộ tính cấu hình hệ thống khí nén — hàm thuần, không gọi giao diện/mạng.
/// Màn hình, sơ đồ và các file xuất đều dùng chung kết quả này.
///
/// Dữ liệu dùng chung với các màn khác: model máy nén `specs.json` và
/// `oil_free_specs.json`, bình `air_tanks.json`, MCCB/cáp `mccb_cable.json`;
/// hằng số trong `air_system_constants.json`.
class AirEngine {
  const AirEngine({
    required this.constants,
    required this.compressors,
    required this.tanks,
    this.mccb = const [],
    this.refrigeratedDryers = const [],
    this.lineFilters = const [],
  });

  final AirSystemConstants constants;
  final List<CatalogCompressor> compressors;

  /// Sắp theo dung tích tăng dần.
  final List<AirTankSpec> tanks;
  final List<Map<String, String>> mccb;

  /// Máy sấy lạnh ACD, lưu lượng tăng dần.
  final List<RefrigeratedDryerSpec> refrigeratedDryers;

  /// Lọc đường ống, lưu lượng tăng dần.
  final List<LineFilterSpec> lineFilters;

  /// Lớp nước ISO 8573-1 theo điểm sương (°C).
  static int? waterClass(int? pdp) => switch (pdp) {
    null => null,
    <= -70 => 1,
    <= -40 => 2,
    <= -20 => 3,
    <= 3 => 4,
    <= 7 => 5,
    _ => 6,
  };

  /// Model trong dữ liệu thuộc loại máy (theo danh mục máy nén khí).
  List<CatalogCompressor> catalogModels(CompressorType type) => [
    for (final m in compressors)
      if (type.catalogSeries.contains(m.series)) m,
  ];

  AirResult compute(AirConfig config) {
    final c = constants;
    final warnings = <AirWarning>[];
    void invalid(String field, [String? line]) => warnings.add(
      AirWarning(WarningLevel.error, AirWarningCode.invalidInput, {
        'field': field,
        'line': line,
        if (field == 'pressure') ...{
          'min': c.minPressure,
          'max': c.maxPressure,
        },
      }),
    );

    // ── Đầu vào ─────────────────────────────────────────────────────────
    final comp = config.compressor;
    final pressure = comp.pressure ?? 0;
    if (comp.pressure == null ||
        pressure < c.minPressure - 1e-9 ||
        pressure > c.maxPressure + 1e-9) {
      invalid('pressure');
    }

    // Line chỉ là tên nơi dùng khí (hiện trên sơ đồ), không tham gia tính.
    final lines = config.lines;
    final all = [for (var i = 0; i < lines.length; i++) i];
    final treat = config.treatment;
    final pre = config.pretreat;
    final usePressure = treat.usePressure;
    final usePressureOk =
        usePressure != null && usePressure.isFinite && usePressure > 0;
    if (!usePressureOk) invalid('usePressure');

    // ── Nhu cầu, máy nén, lưu lượng ─────────────────────────────────────
    // Theo nhu cầu (bắt buộc nhập): khí cần = nhu cầu + khí xả tái sinh (máy
    // sấy hấp thụ); đề xuất model nhỏ nhất ≥ khí cần × (1 + % khách chọn).
    // Chọn model / nhập tay: lấy lưu lượng máy đã chọn làm khí có sẵn. Lưu
    // lượng hệ thống (bình, lọc tuyến chính, máy sấy) theo máy thật.
    final kind = _kindOf(treat.pdp);
    final purgeRate = c.purgeRates[config.regen.name] ?? 0;
    final purgeShare = kind == DryerKind.desiccant ? purgeRate : 0.0;
    final byDemand = comp.source == CompressorSource.demand;
    final customer = comp.demand;
    final customerOk = customer != null && customer.isFinite && customer > 0;
    if (byDemand && !customerOk) invalid('demand');
    final marginPct = comp.marginPercent;
    final marginOk =
        marginPct != null &&
        marginPct.isFinite &&
        marginPct >= 0 &&
        marginPct <= 100;
    if (byDemand && !marginOk) invalid('margin');
    final targetMargin = marginOk ? marginPct : c.defaultMargin;
    final demandAsked = byDemand && customerOk ? customer : 0.0;
    final target = demandAsked * (1 + purgeShare) * (1 + targetMargin / 100);
    if (comp.source == CompressorSource.manual &&
        !(comp.manualFad != null && comp.manualFad! > 0)) {
      invalid('manualFad');
    }

    final pick = _pickCompressor(config, target, pressure, warnings);
    final compressorQty = pick?.units ?? 1;
    final supplied = pick?.flowAtPressure == null
        ? null
        : pick!.flowAtPressure! * pick.units;
    final flow = supplied ?? target;
    // Khí dùng được (nhu cầu) và khí xả tái sinh.
    final demand = byDemand ? demandAsked : flow / (1 + purgeShare);
    final purge = demand * purgeShare;
    final required = byDemand ? demand + purge : flow;
    if (supplied != null && required > 0 && supplied + 1e-9 < required) {
      warnings.add(
        AirWarning(WarningLevel.error, AirWarningCode.modelFlowLow, {
          'model': pick!.model?.modelCode ?? pick.manualName ?? '',
          'flow': supplied,
          'need': required,
        }),
      );
    }

    // ── Xử lý khí chung: máy sấy theo điểm sương, lọc sau máy sấy ───────
    // Lọc đường ống: tách thô 1 µm + tách tinh 0,01 µm sau máy sấy; than
    // hoạt tính / vô trùng theo lựa chọn chung.
    final drop =
        switch (kind) {
          DryerKind.desiccant => c.drop('desiccantDryer'),
          DryerKind.refrigerated => c.drop('refrigeratedDryer'),
          DryerKind.none => 0.0,
        } +
        (pre.hasCoarse ? c.drop('coarseFilter') : 0) +
        (pre.hasFine ? c.drop('fineFilter') : 0);
    final groups = [
      AirGroup(
        kind: kind,
        lineIndexes: all,
        demand: demand,
        purge: purge,
        pdp: treat.pdp.celsius,
        coarse: pre.hasCoarse,
        fine: pre.hasFine,
        carbon: false,
        sterile: false,
        pressureDrop: drop,
      ),
    ];
    final group = groups.single;

    // ── Áp suất cần = áp sử dụng + tổn áp xử lý + tuyến chính + ống ─────
    final double pretreatDrop =
        (pre.afterCooler != AfterCoolerType.none ? c.drop('afterCooler') : 0) +
        (pre.hasWaterSeparator ? c.drop('waterSeparator') : 0);
    final pressureNeed = usePressureOk
        ? round1(usePressure + drop + pretreatDrop + c.drop('piping'))
        : 0.0;

    // ── Công suất, động cơ chuẩn ────────────────────────────────────────
    final specific = c.specificPower[comp.type.name] ?? 0;
    final correction = math.max(
      1.0,
      1 + c.powerCorrectionPerBar * (pressure - c.powerReferencePressure),
    );
    final powerEstimate = flow * specific * correction;
    final motorKw = c.motorSizesKw
        .where((m) => m + 1e-9 >= powerEstimate)
        .firstOrNull;
    if (motorKw == null && powerEstimate > 0) {
      warnings.add(
        AirWarning(WarningLevel.caution, AirWarningCode.powerOver, {
          'power': powerEstimate,
          'max': c.motorSizesKw.last,
        }),
      );
    }

    // ── Bình chứa ───────────────────────────────────────────────────────
    final tank = config.tank.enabled && flow > 0
        ? _pickTank(config, flow, pressure, warnings, invalid)
        : null;

    // ── Máy sấy lạnh ACD theo công suất máy nén ─────────────────────────
    // Mặc định theo bảng "máy nén khí tương ứng" của hãng. Toàn bộ khí máy
    // nén đi qua máy sấy → model phải đủ lưu lượng máy nén (không nhỏ hơn
    // nhu cầu) để không quá tải khi máy nén chạy hết công suất.
    final dryerPicks = <DryerKind, DryerPick>{};
    if (kind == DryerKind.refrigerated && flow > 0) {
      final pickKw = pick?.powerKw;
      final dryer = _pickRefrigeratedDryer(
        math.max(flow, demand),
        pickKw != null ? pickKw * pick!.units : motorKw,
      );
      if (dryer == null) {
        warnings.add(
          const AirWarning(WarningLevel.note, AirWarningCode.noDryerModel),
        );
      } else {
        dryerPicks[kind] = dryer;
        if (pressure > c.dryerMaxPressure + 1e-9) {
          warnings.add(
            AirWarning(WarningLevel.caution, AirWarningCode.dryerPressureHigh, {
              'model': dryer.spec.model,
              'max': c.dryerMaxPressure,
              'pressure': pressure,
            }),
          );
        }
      }
    }

    // ── Chất lượng khí (chung cho mọi line) ─────────────────────────────
    // Hạt: lọc tốt nhất trên đường đi (vô trùng/tách tinh 0,01 µm → 1,
    // tách thô 1 µm → 2, chỉ tách nước 3 µm → 3). Dầu: máy không dầu → 0;
    // máy có dầu: than hoạt tính → 1, tách tinh → 2, không có → 4.
    final particle = group.sterile || group.fine
        ? 1
        : group.coarse
        ? 2
        : pre.hasWaterSeparator
        ? 3
        : null;
    final oil = comp.type.isOilFree
        ? 0
        : group.carbon
        ? 1
        : group.fine
        ? 2
        : 4;
    final quality = [
      for (final i in all)
        LineQuality(
          lineIndex: i,
          group: kind,
          particle: particle,
          water: waterClass(treat.pdp.celsius),
          oil: oil,
        ),
    ];

    // ── Cảnh báo ────────────────────────────────────────────────────────
    if (!comp.type.isOilFree && groups.any((g) => !g.fine)) {
      warnings.add(
        const AirWarning(WarningLevel.caution, AirWarningCode.oilNoOilFilter),
      );
    }
    // Máy có dầu: dầu tới thẳng hạt hút ẩm nếu không có tách tinh trước máy
    // sấy hấp thụ (tách tinh tiêu chuẩn nằm sau máy sấy).
    if (!comp.type.isOilFree &&
        groups.any((g) => g.kind == DryerKind.desiccant)) {
      warnings.add(
        const AirWarning(
          WarningLevel.caution,
          AirWarningCode.desiccantNoOilFilter,
        ),
      );
    }
    final integrated = pick?.model;
    if (integrated != null && integrated.isFourInOne) {
      warnings.add(
        AirWarning(WarningLevel.note, AirWarningCode.fourInOneIntegrated, {
          'model': integrated.modelCode,
          'tank': integrated.airTank,
        }),
      );
    }
    if (!config.tank.enabled) {
      warnings.add(const AirWarning(WarningLevel.note, AirWarningCode.noTank));
    }
    if (purge > 0) {
      warnings.add(
        AirWarning(WarningLevel.note, AirWarningCode.purge, {
          'rate': purgeRate,
          'purge': purge,
        }),
      );
    }
    final sorted = [
      for (final level in WarningLevel.values)
        ...warnings.where((w) => w.level == level),
    ];

    // ── Danh mục thiết bị ───────────────────────────────────────────────
    final equipment = _equipment(
      config: config,
      groups: groups,
      flow: flow,
      pressure: pressure,
      powerEstimate: powerEstimate,
      motorKw: motorKw,
      pick: pick,
      compressorQty: compressorQty,
      tank: tank,
      purgeRate: purgeRate,
      dryerPicks: dryerPicks,
    );

    return AirResult(
      lines: lines,
      validLines: all,
      demand: demand,
      purge: purge,
      purgeRate: purgeRate,
      customerDemand: customerOk ? customer : null,
      required: required,
      flow: flow,
      flowFromModel: supplied != null,
      demandBased: byDemand,
      pressure: pressure,
      pressureNeed: pressureNeed,
      pretreatDrop: pretreatDrop,
      powerEstimate: powerEstimate,
      motorKw: motorKw,
      compressor: pick,
      compressorQty: compressorQty,
      tank: tank,
      dryerPicks: dryerPicks,
      electrical: pick?.model == null
          ? null
          : mccb.where((m) => m['model'] == pick!.model!.modelCode).firstOrNull,
      // Toàn bộ khí máy nén đi qua lọc đường ống → chọn theo lưu lượng máy.
      lineFilter: _pickLineFilter(
        math.max(flow, demand),
        water: pre.hasWaterSeparator,
        coarse: group.coarse,
        fine: group.fine,
      ),
      groups: groups,
      quality: quality,
      equipment: equipment,
      warnings: sorted,
    );
  }

  static String lineName(List<AirLine> lines, int index) {
    final name = lines[index].name.trim();
    return name.isEmpty ? 'Line ${index + 1}' : name;
  }

  static DryerKind _kindOf(LinePdp pdp) => pdp.isDesiccant
      ? DryerKind.desiccant
      : pdp.isRefrigerated
      ? DryerKind.refrigerated
      : DryerKind.none;

  /// Máy nén theo cách chọn: [CompressorSource.demand] đề xuất model nhỏ nhất
  /// có lưu lượng ≥ [target] (nhu cầu đã cộng % khách chọn; nhiều máy khi một
  /// máy không đủ); [CompressorSource.catalog] dùng đúng model đã
  /// chọn, 1 máy; [CompressorSource.manual] máy ngoài dữ liệu.
  CompressorPick? _pickCompressor(
    AirConfig config,
    double target,
    double pressure,
    List<AirWarning> warnings,
  ) {
    final comp = config.compressor;
    switch (comp.source) {
      case CompressorSource.manual:
        final fad = comp.manualFad;
        return CompressorPick(
          manualName: comp.manualName.trim().isEmpty
              ? null
              : comp.manualName.trim(),
          manualPowerKw: comp.manualPowerKw,
          flowAtPressure: fad != null && fad.isFinite && fad > 0 ? fad : null,
        );
      case CompressorSource.catalog:
        final model = catalogModels(comp.type)
            .where((m) => m.modelCode == comp.modelCode)
            .firstOrNull;
        if (model == null) return null;
        final perUnit = model.flowAt(pressure);
        if (perUnit == null) {
          warnings.add(
            AirWarning(WarningLevel.note, AirWarningCode.catalogPressure, {
              'max': model.maxPressure,
            }),
          );
        }
        return CompressorPick(model: model, flowAtPressure: perUnit);
      case CompressorSource.demand:
        if (target <= 0) return null;
        if (!comp.type.hasCatalog) {
          warnings.add(
            AirWarning(WarningLevel.note, AirWarningCode.noCatalogModel, {
              'type': comp.type,
            }),
          );
          return null;
        }
        final all = catalogModels(comp.type);
        final models = [
          for (final m in all)
            if (m.flowAt(pressure) != null) m,
        ];
        if (models.isEmpty) {
          if (all.isNotEmpty) {
            warnings.add(
              AirWarning(WarningLevel.note, AirWarningCode.catalogPressure, {
                'max': all.map((m) => m.maxPressure).reduce(math.max),
              }),
            );
          }
          return null;
        }
        // Cùng lưu lượng thì ưu tiên máy tốc độ cố định (sort không ổn định).
        models.sort((a, b) {
          final byFlow = a.flowAt(pressure)!.compareTo(b.flowAt(pressure)!);
          return byFlow != 0 ? byFlow : (a.isVsd ? 1 : 0) - (b.isVsd ? 1 : 0);
        });
        final largest = models.last.flowAt(pressure)!;
        final units = math.max(1, (target / largest - 1e-9).ceil());
        final model = models.firstWhere(
          (m) => m.flowAt(pressure)! * units + 1e-9 >= target,
        );
        return CompressorPick(
          model: model,
          units: units,
          flowAtPressure: model.flowAt(pressure),
        );
    }
  }

  /// Máy sấy lạnh ACD mặc định theo công suất máy nén [compressorKw]: model
  /// nhỏ nhất có "máy nén khí tương ứng" ≥ công suất máy. Model đó không đủ
  /// lưu lượng [inlet], hoặc máy vượt bảng tương ứng / chưa biết công suất,
  /// thì chọn theo lưu lượng. `null` khi chưa có dữ liệu.
  DryerPick? _pickRefrigeratedDryer(double inlet, double? compressorKw) {
    if (refrigeratedDryers.isEmpty || inlet <= 0) return null;
    final byPower = compressorKw == null || compressorKw <= 0
        ? null
        : refrigeratedDryers
              .where(
                (d) =>
                    d.matchingCompressorKw.isNotEmpty &&
                    d.matchingCompressorKw.reduce(math.max) + 1e-9 >=
                        compressorKw,
              )
              .firstOrNull;
    if (byPower != null && byPower.capacityM3min + 1e-9 >= inlet) {
      return DryerPick(
        spec: byPower,
        units: 1,
        inlet: inlet,
        compressorKw: compressorKw,
      );
    }
    final largest = refrigeratedDryers.last.capacityM3min;
    final units = math.max(1, (inlet / largest - 1e-9).ceil());
    final spec = refrigeratedDryers.firstWhere(
      (d) => d.capacityM3min * units + 1e-9 >= inlet,
    );
    return DryerPick(spec: spec, units: units, inlet: inlet);
  }

  /// Model nhỏ nhất đủ [flow]; vượt model lớn nhất thì ghép nhiều bộ song
  /// song. [water]/[coarse]/[fine]: cấp lọc nào có trong hệ thống.
  LineFilterPick? _pickLineFilter(
    double flow, {
    required bool water,
    required bool coarse,
    required bool fine,
  }) {
    if (lineFilters.isEmpty || flow <= 0 || !(water || coarse || fine)) {
      return null;
    }
    final largest = lineFilters.last.capacityM3min;
    final units = math.max(1, (flow / largest - 1e-9).ceil());
    final spec = lineFilters.firstWhere(
      (f) => f.capacityM3min * units + 1e-9 >= flow,
    );
    // Thứ tự cấp trong dữ liệu: tách nước, tách thô, tách tinh.
    final present = [water, coarse, fine];
    return LineFilterPick(
      spec: spec,
      units: units,
      levels: [
        for (var k = 0; k < spec.levels.length && k < 3; k++)
          if (present[k]) spec.levels[k],
      ],
    );
  }

  TankPick? _pickTank(
    AirConfig config,
    double flow,
    double pressure,
    List<AirWarning> warnings,
    void Function(String field, [String? line]) invalid,
  ) {
    // Cùng công thức và giá trị mặc định với màn "Tính thể tích bình chứa".
    final required = airTankTheoreticalLiters(qc: flow) / 1000;
    final design = constants.designPressureFor(pressure);
    final manual = config.tank.manualVolumeM3;
    TankPick pick;
    if (manual != null) {
      if (!manual.isFinite || manual <= 0) {
        invalid('tankVolume');
        return null;
      }
      final spec = tanks
          .where((t) => (t.volumeLiters - manual * 1000).abs() < 1e-6)
          .firstOrNull;
      if (spec == null) {
        warnings.add(
          const AirWarning(
            WarningLevel.note,
            AirWarningCode.tankManualNotInCatalog,
          ),
        );
      }
      pick = TankPick(
        spec: spec,
        volumeM3: manual,
        requiredM3: required,
        designPressure: design,
        manual: true,
      );
    } else {
      if (required <= 0) return null;
      final spec = tanks
          .where((t) => t.volumeLiters + 1e-6 >= required * 1000)
          .firstOrNull;
      if (spec == null) {
        warnings.add(
          AirWarning(WarningLevel.caution, AirWarningCode.tankTooLarge, {
            'required': required,
            'max': tanks.isEmpty ? 0.0 : tanks.last.volumeLiters / 1000,
          }),
        );
      }
      pick = TankPick(
        spec: spec,
        volumeM3: spec == null ? required : spec.volumeLiters / 1000,
        requiredM3: required,
        designPressure: design,
        tooLarge: spec == null,
      );
    }
    if (pick.designInsufficient) {
      warnings.add(
        AirWarning(WarningLevel.caution, AirWarningCode.tankDesignHigh, {
          'design': design,
          'tankDesign': pick.spec!.designPressureKgfCm2,
        }),
      );
    }
    return pick;
  }

  List<EquipmentItem> _equipment({
    required AirConfig config,
    required List<AirGroup> groups,
    required double flow,
    required double pressure,
    required double powerEstimate,
    required double? motorKw,
    required CompressorPick? pick,
    required int compressorQty,
    required TankPick? tank,
    required double purgeRate,
    required Map<DryerKind, DryerPick> dryerPicks,
  }) {
    final pre = config.pretreat;
    final lines = config.lines;
    List<String> names(AirGroup g) => [
      for (final i in g.lineIndexes) lineName(lines, i),
    ];
    final items = <EquipmentItem>[
      EquipmentItem(
        key: 'compressor',
        kind: EquipmentKind.compressor,
        qty: compressorQty,
        params: {
          'type': config.compressor.type,
          'flow': flow,
          'pressure': pressure,
          'power': powerEstimate,
          'motor': motorKw,
          'pick': pick,
        },
      ),
      if (tank != null)
        EquipmentItem(
          key: 'tank',
          kind: EquipmentKind.tank,
          qty: 1,
          params: {'tank': tank},
        ),
      if (pre.afterCooler != AfterCoolerType.none)
        EquipmentItem(
          key: 'afterCooler',
          kind: EquipmentKind.afterCooler,
          qty: 1,
          params: {'type': pre.afterCooler, 'flow': flow},
        ),
      if (pre.hasWaterSeparator)
        EquipmentItem(
          key: 'waterSeparator',
          kind: EquipmentKind.waterSeparator,
          qty: 1,
          params: {'flow': flow},
        ),
    ];
    for (final g in groups) {
      final groupParams = {'flow': g.demand, 'lines': names(g)};
      if (g.hasDryer) {
        final dryer = dryerPicks[g.kind];
        items.add(
          EquipmentItem(
            key: 'dryer_${g.kind.name}',
            kind: g.kind == DryerKind.desiccant
                ? EquipmentKind.desiccantDryer
                : EquipmentKind.refrigeratedDryer,
            qty: dryer?.units ?? 1,
            group: g.kind,
            params: {
              'inlet': g.dryerInlet,
              'pdp': g.pdp,
              'purge': g.purge,
              'rate': purgeRate,
              'regen': config.regen,
              'lines': names(g),
              'pick': dryer,
            },
          ),
        );
      }
      for (final (on, kind, prefix) in [
        (g.coarse, EquipmentKind.coarseFilter, 'coarse'),
        (g.fine, EquipmentKind.fineFilter, 'fine'),
        (g.carbon, EquipmentKind.carbonFilter, 'carbon'),
        (g.sterile, EquipmentKind.sterileFilter, 'sterile'),
      ]) {
        if (!on) continue;
        items.add(
          EquipmentItem(
            key: '${prefix}_${g.kind.name}',
            kind: kind,
            qty: 1,
            group: g.kind,
            params: groupParams,
          ),
        );
      }
    }
    if (pre.autoDrain) {
      final sources = {
        'tank': tank != null ? 1 : 0,
        'afterCooler': pre.afterCooler != AfterCoolerType.none ? 1 : 0,
        'waterSeparator': pre.hasWaterSeparator ? 1 : 0,
        'coarseFilter': groups.where((g) => g.coarse).length,
        'fineFilter': groups.where((g) => g.fine).length,
        'refrigeratedDryer': groups
            .where((g) => g.kind == DryerKind.refrigerated)
            .length,
      }..removeWhere((_, n) => n == 0);
      final count = sources.values.fold(0, (s, n) => s + n);
      if (count > 0) {
        items.add(
          EquipmentItem(
            key: 'autoDrain',
            kind: EquipmentKind.autoDrain,
            qty: count,
            params: {'sources': sources},
          ),
        );
      }
    }
    if (!config.compressor.type.isOilFree) {
      items.add(
        const EquipmentItem(
          key: 'separator',
          kind: EquipmentKind.oilWaterSeparator,
          qty: 1,
        ),
      );
    }
    final model = pick?.model;
    final electrical = model == null
        ? null
        : mccb.where((m) => m['model'] == model.modelCode).firstOrNull;
    if (electrical != null) {
      items
        ..add(
          EquipmentItem(
            key: 'mccb',
            kind: EquipmentKind.mccb,
            qty: compressorQty,
            params: {'model': model!.modelCode, 'mccb': electrical['mccbComp']},
          ),
        )
        ..add(
          EquipmentItem(
            key: 'cable',
            kind: EquipmentKind.cable,
            qty: compressorQty,
            params: {
              'model': model.modelCode,
              'cable': electrical['cableComp'],
            },
          ),
        );
    }
    for (final x in config.extraItems) {
      items.add(
        EquipmentItem(
          key: 'extra_${x.id}',
          kind: EquipmentKind.extra,
          qty: x.qty,
          params: {'name': x.name, 'spec': x.spec},
        ),
      );
    }
    return items;
  }
}
