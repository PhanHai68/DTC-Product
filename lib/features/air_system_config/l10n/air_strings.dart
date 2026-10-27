import 'package:intl/intl.dart';

import '../engine/air_engine.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';

enum AirLang { vi, en }

/// Toàn bộ chữ của chức năng Cấu hình hệ thống khí nén (màn hình, sơ đồ, file
/// xuất), tiếng Việt và tiếng Anh. Số hiển thị theo ngôn ngữ (15,5 / 15.5).
class AirStrings {
  AirStrings(this.lang)
    : _n1 = NumberFormat('#,##0.#', lang == AirLang.vi ? 'vi' : 'en_US'),
      _n2 = NumberFormat('#,##0.##', lang == AirLang.vi ? 'vi' : 'en_US');

  final AirLang lang;
  final NumberFormat _n1;
  final NumberFormat _n2;

  bool get isEn => lang == AirLang.en;
  String _t(String vi, String en) => isEn ? en : vi;

  // ── Số và đơn vị ─────────────────────────────────────────────────────────
  String n1(num v) => _n1.format(round1(v.toDouble()));
  String n2(num v) => _n2.format(v);
  String n0(num v) => NumberFormat('#,##0', isEn ? 'en_US' : 'vi').format(v);
  String get flowUnit => _t('m³/phút', 'm³/min');
  String flow(num v) => '${n1(v)} $flowUnit';
  String bar(num v) => '${n2(v)} bar';
  String barRange(double? min, double? max) {
    if (min == null || max == null) return '—';
    return (min - max).abs() < 1e-9 ? bar(max) : '${n2(min)}–${n2(max)} bar';
  }

  String pdp(int? c) => c == null
      ? noDryer
      // Sấy lạnh: dải điểm sương 2–10 °C của máy ACD.
      : c == LinePdp.p3.celsius
      ? '2–10 °C'
      : '${c > 0
            ? '+'
            : c < 0
            ? '−'
            : ''}${c.abs()} °C';
  String percent(double ratio) => '${n2(ratio * 100)}%';

  // ── Nhãn lựa chọn ───────────────────────────────────────────────────────
  String get title => _t('Cấu hình hệ thống khí nén', 'Compressed Air System');

  /// Loại máy theo "Danh mục máy nén khí".
  String compressorType(CompressorType v) => switch (v) {
    CompressorType.pmVsd => _t(
      'PM VFD – Trục vít biến tần',
      'PM VFD – Variable speed screw',
    ),
    CompressorType.fixedSpeed => _t(
      'FIXED SPEED – Trục vít tốc độ cố định',
      'FIXED SPEED – Fixed speed screw',
    ),
    CompressorType.fourInOne => _t(
      '4 IN 1 – Trục vít 4 trong 1',
      '4 IN 1 – 4-in-1 screw',
    ),
    CompressorType.oilFree => _t(
      'OIL-FREE – Máy nén khí không dầu',
      'OIL-FREE – Oil-free compressor',
    ),
    CompressorType.twoStage => _t(
      '2-STAGE – Trục vít 2 cấp',
      '2-STAGE – Two-stage screw',
    ),
  };

  /// Tên máy nén theo loại (dùng khi chưa có model).
  String compressorTypeName(CompressorType v) => switch (v) {
    CompressorType.pmVsd => _t(
      'Máy nén khí trục vít biến tần',
      'Variable Speed Screw Compressor',
    ),
    CompressorType.fixedSpeed => _t(
      'Máy nén khí trục vít tốc độ cố định',
      'Fixed Speed Screw Compressor',
    ),
    CompressorType.fourInOne => _t(
      'Máy nén khí trục vít 4 trong 1',
      '4-in-1 Screw Compressor',
    ),
    CompressorType.oilFree => _t(
      'Máy nén khí không dầu',
      'Oil-free Air Compressor',
    ),
    CompressorType.twoStage => _t(
      'Máy nén khí trục vít 2 cấp',
      'Two-stage Screw Compressor',
    ),
  };
  String afterCooler(AfterCoolerType v) => switch (v) {
    AfterCoolerType.none => _t('Không dùng', 'None'),
    AfterCoolerType.air => _t('Giải nhiệt gió', 'Air cooled'),
    AfterCoolerType.water => _t('Giải nhiệt nước', 'Water cooled'),
  };
  String regen(RegenType v) => switch (v) {
    RegenType.heatless => _t('Không gia nhiệt', 'Heatless'),
    RegenType.heated => _t('Gia nhiệt', 'Heated'),
    RegenType.blower => _t('Quạt thổi', 'Blower purge'),
  };
  String linePdp(LinePdp v) => v == LinePdp.none ? noDryer : pdp(v.celsius);
  String get noDryer => _t('Không sấy', 'No dryer');
  String source(CompressorSource v) => switch (v) {
    CompressorSource.demand => _t('Theo nhu cầu', 'By demand'),
    CompressorSource.catalog => _t('Chọn model', 'Pick a model'),
    CompressorSource.manual => _t('Nhập tay', 'Manual entry'),
  };
  String group(DryerKind v) => switch (v) {
    DryerKind.desiccant => _t('Nhóm sấy hấp thụ', 'Desiccant dryer group'),
    DryerKind.refrigerated => _t('Nhóm sấy lạnh', 'Refrigerated dryer group'),
    DryerKind.none => _t('Nhóm không sấy', 'No-dryer group'),
  };
  String dryerTitle(DryerKind v) => switch (v) {
    DryerKind.desiccant => _t('Máy sấy hấp thụ', 'Desiccant Dryer'),
    DryerKind.refrigerated => _t('Máy sấy lạnh', 'Refrigerated Dryer'),
    DryerKind.none => _t('Không sấy', 'No dryer'),
  };

  // ── Form ─────────────────────────────────────────────────────────────────
  String get tabInput => _t('Nhập liệu', 'Input');
  String get tabResult => _t('Kết quả', 'Results');
  String get tabDiagram => _t('Sơ đồ', 'Diagram');
  String get diagramFullScreen => _t('Xem toàn màn hình', 'Full screen');
  String get sectionProject => _t('Dự án', 'Project');
  String get projectName => _t('Tên dự án', 'Project name');
  String get sectionCompressor => _t('Máy nén', 'Compressor');
  String get compressorTypeLabel => _t('Loại máy', 'Compressor type');
  String get workingPressure => _t('Áp suất làm việc', 'Working pressure');
  String get customerDemand => _t('Nhu cầu khách hàng', 'Customer air demand');
  String get marginLabel => _t(
    'Lưu lượng máy lớn hơn so với nhu cầu thực tế',
    'Compressor flow above actual demand',
  );
  String get backToCatalog => _t('Quay lại chọn từ dữ liệu', 'Back to catalog');
  String margin(double ratio) {
    final p = (ratio * 100).round();
    return _t('dư ${p >= 0 ? '+' : ''}$p%', 'margin ${p >= 0 ? '+' : ''}$p%');
  }

  String get modelSource => _t('Model máy nén', 'Compressor model');
  String get modelLabel => _t('Model', 'Model');
  String get manualModelName => _t('Tên / model máy', 'Name / model');
  String get manualPower => _t('Công suất', 'Power');
  String get manualFad => _t('Lưu lượng máy (FAD)', 'Unit flow (FAD)');
  String noCatalogFor(CompressorType type) => _t(
    'Dữ liệu chưa có model ${compressorTypeName(type).toLowerCase()}: chọn "Nhập tay" để nhập máy.',
    'No ${compressorTypeName(type)} models in the catalog yet: choose "Manual entry".',
  );

  /// Dòng tóm tắt máy được chọn: "Đề xuất: 2 × ACP-100PV (12,6 m³/phút) · dư +18%".
  String suggested(AirResult r, {required bool byDemand}) {
    final pick = r.compressor!;
    final count = pick.units > 1 ? '${pick.units} × ' : '';
    final name = pick.model?.modelCode ?? pick.manualName ?? '';
    final flowText = pick.flowAtPressure == null
        ? ''
        : ' (${flow(pick.flowAtPressure!)})';
    final m = r.margin == null ? '' : ' · ${margin(r.margin!)}';
    return byDemand
        ? _t(
            'Đề xuất: $count$name$flowText$m',
            'Suggested: $count$name$flowText$m',
          )
        : '$count$name$flowText$m';
  }

  String get sectionTank => _t('Bình chứa', 'Air receiver');
  String get tankEnabled => _t('Có bình chứa', 'Include air receiver');
  String get tankManual => _t('Thể tích chọn tay', 'Manual volume');
  String get tankManualHint => _t('Trống = tự chọn', 'Empty = auto');
  String get sectionPretreat => _t('Lọc đường ống', 'Pipeline filters');
  String get standardFilters =>
      _t('Theo tiêu chuẩn lọc đường ống', 'Standard pipeline filtration');
  String get standardFiltersHint => _t(
    'Bình tích khí → tách nước 3 µm → máy sấy → tách thô 1 µm → tách tinh 0,01 µm',
    'Receiver → water separator 3 µm → dryer → coarse 1 µm → fine 0.01 µm',
  );
  String get waterSeparator => _t('Lọc tách nước 3 µm', 'Water separator 3 µm');
  String get coarseFilter => _t('Lọc tách thô 1 µm', 'Coarse filter 1 µm');
  String get fineFilter => _t('Lọc tách tinh 0,01 µm', 'Fine filter 0.01 µm');
  String get advanced => _t('Nâng cao', 'Advanced');
  String get afterCoolerLabel => _t('After cooling', 'After cooling');
  String get tankFilter =>
      _t('Lọc sau bình tích khí', 'Filters after the receiver');
  String get tankFilterHint => _t(
    '1 = tách thô 1 µm · 2 = tách thô 1 µm + tách tinh 0,01 µm',
    '1 = coarse 1 µm · 2 = coarse 1 µm + fine 0.01 µm',
  );
  String get autoDrain => _t('Xả tự động', 'Automatic drain');
  String get sectionTreatment => _t('Xử lý khí', 'Air treatment');
  String get usePressure => _t('Áp suất sử dụng', 'Point-of-use pressure');
  String dryerFor(LinePdp v) => v.isDesiccant
      ? _t('Dùng máy sấy hấp thụ', 'Uses a desiccant dryer')
      : v.isRefrigerated
      ? _t('Dùng máy sấy tác nhân lạnh', 'Uses a refrigerated dryer')
      : _t('Không dùng máy sấy', 'No dryer');
  String get regenLabel => _t('Kiểu tái sinh', 'Regeneration');
  String regenOption(RegenType v, double rate) =>
      '${regen(v)} (${percent(rate)})';
  String get sectionLines => _t('Line sử dụng', 'Consumer lines');
  String get lineName =>
      _t('Thiết bị sử dụng (vd máy tách màu)', 'Equipment (e.g. color sorter)');
  String get pdpLabel => _t('Điểm sương PDP', 'Pressure dew point');
  String get carbon => _t('Lọc than hoạt tính', 'Activated carbon filter');
  String get sterile => _t('Lọc vô trùng', 'Sterile filter');
  String get addLine => _t('Thêm line', 'Add line');
  String get deleteLine => _t('Xóa line', 'Delete line');
  String maxLines(int max) => _t('Tối đa $max line.', 'Up to $max lines.');

  // ── Kết quả ──────────────────────────────────────────────────────────────
  String flowBreakdown(AirResult r) => !r.demandBased
      ? (r.flowFromModel
            ? _t(
                'Theo máy đã chọn: ${_pickName(r)}',
                'Selected: ${_pickName(r)}',
              )
            : _t('Chưa chọn máy', 'No compressor selected'))
      : r.margin == null
      ? _t(
          'Nhu cầu ${flow(r.required)} · chưa có máy, tính tạm',
          'Demand ${flow(r.required)} · no compressor yet, provisional',
        )
      : _t(
          'Nhu cầu ${flow(r.required)} · ${_pickName(r)} · ${margin(r.margin!)}',
          'Demand ${flow(r.required)} · ${_pickName(r)} · ${margin(r.margin!)}',
        );

  /// "2 × ACP-100PV" / "ACP-100PV" / tên nhập tay.
  String _pickName(AirResult r) {
    final pick = r.compressor!;
    final name = pick.model?.modelCode ?? pick.manualName ?? '';
    return pick.units > 1 ? '${pick.units} × $name' : name;
  }

  String get cardPower => _t('Công suất ước tính', 'Estimated power');

  /// Ô công suất: máy đã chọn có công suất thì hiện công suất thật, không
  /// thì ước tính theo hệ số riêng.
  (String, String, String) powerCard(AirResult r) {
    final pick = r.compressor;
    final kw = pick?.powerKw;
    if (pick == null || kw == null) {
      return (cardPower, '~${n0(r.powerEstimate)} kW', motor(r.motorKw));
    }
    return (
      _t('Công suất máy nén', 'Compressor power'),
      '${n2(kw * pick.units)} kW',
      pick.units > 1
          ? '${pick.units} × ${n2(kw)} kW'
          : (pick.model?.modelCode ?? pick.manualName ?? ''),
    );
  }

  /// Dòng phụ ô công suất: lưu lượng máy nén + nguồn (nhu cầu / máy chọn);
  /// thêm công suất từng máy hoặc động cơ chuẩn khi cần.
  String compressorCardSub(AirResult r) {
    final extra = powerCard(r).$3;
    final pick = r.compressor;
    return [
      _t('Lưu lượng: ${flow(r.flow)}', 'Flow: ${flow(r.flow)}'),
      flowBreakdown(r),
      // Chỉ tên model thì đã có trong dòng nguồn.
      if (pick == null || pick.powerKw == null || pick.units > 1) extra,
    ].join('\n');
  }

  String get cardDryer => _t('Máy sấy khí', 'Air dryer');
  (String, String) dryerCard(AirResult r) {
    final g = r.groups.firstOrNull;
    if (g == null || !g.hasDryer) return (noDryer, '');
    final pick = r.dryerPicks[g.kind];
    final dew = _t('Điểm sương ${pdp(g.pdp)}', 'Dew point ${pdp(g.pdp)}');
    if (pick == null) return (dryerTitle(g.kind), dew);
    return (
      '${pick.units > 1 ? '${pick.units} × ' : ''}${pick.spec.model}',
      '${_lowerFirst(dryerTitle(g.kind))} · ${flow(pick.capacity)}\n$dew',
    );
  }

  // ── Thiết bị điện (như màn "Chọn MCCB và dây điện") ─────────────────────
  String get electricalTitle => _t('Thiết bị điện', 'Electrical');
  String get electricalMissing => _t(
    'Chưa có dữ liệu MCCB và dây điện cho máy nén này.',
    'No MCCB and cable data for this compressor.',
  );

  /// (nhãn, giá trị); bỏ ô trống hoặc "-". Dòng máy sấy chỉ khi có máy sấy
  /// lạnh (bảng tính MCB/cáp cho máy sấy lạnh đi kèm).
  List<(String, String)> electricalRows(AirResult r) {
    final e = r.electrical;
    if (e == null) return const [];
    bool has(String key) => (e[key] ?? '').isNotEmpty && e[key] != '-';
    final dryer = r.groups.any((g) => g.kind == DryerKind.refrigerated);
    return [
      if (has('mccbComp')) (_t('Chọn MCCB', 'MCCB'), '${e['mccbComp']} A'),
      if (has('cableComp'))
        (
          _t(
            'Tiết diện dây điện máy nén (cáp đồng)',
            'Compressor cable (copper)',
          ),
          e['cableComp']!,
        ),
      if (dryer && has('mcbDryer'))
        (_t('Chọn MCB máy sấy', 'Dryer MCB'), '${e['mcbDryer']} A'),
      if (dryer && has('cableDryer'))
        (
          _t('Tiết diện dây điện máy sấy (cáp đồng)', 'Dryer cable (copper)'),
          e['cableDryer']!,
        ),
    ];
  }

  String get cardLineFilter => _t('Lọc đường ống', 'Line filters');
  (String, String) lineFilterCard(AirResult r) {
    final f = r.lineFilter;
    if (f == null) return (_t('Không dùng', 'None'), '');
    return (
      '${f.units > 1 ? '${f.units} × ' : ''}Model ${f.spec.model}',
      f.levels.map((l) => '${l.level} ${n2(l.micron)} µm').join(' · '),
    );
  }

  String motor(double? kw) => kw == null
      ? _t('Vượt dãy động cơ chuẩn', 'Beyond standard motor sizes')
      : _t('Động cơ chuẩn ${n2(kw)} kW', 'Standard motor ${n2(kw)} kW');
  String get cardTank => _t('Bình chứa', 'Air receiver');
  String tankCard(TankPick? t) {
    if (t == null) return _t('Không dùng', 'None');
    return '${n2(t.volumeM3)} m³';
  }

  String tankCardSub(TankPick? t) {
    if (t == null) return '';
    final model = t.spec == null ? '' : '${t.spec!.model} · ';
    return _t(
      '$model thiết kế ${n2(t.designPressure)} bar',
      '$model design ${n2(t.designPressure)} bar',
    ).replaceAll('  ', ' ');
  }

  String get tableGroups => _t('Nhóm xử lý khí', 'Air treatment groups');
  String get tableEquipment => _t('Danh mục thiết bị', 'Equipment list');
  String get tableWarnings => _t('Cảnh báo', 'Warnings');
  String get colGroup => _t('Nhóm', 'Group');
  String get colLines => _t('Line', 'Lines');
  String get colDemand => _t('Nhu cầu', 'Demand');
  String get colDryerInlet => _t('Vào máy sấy', 'Dryer inlet');
  String get colPdp => 'PDP';
  String get colFilters => _t('Lọc sau', 'Post filters');
  String get colDrop => _t('Tổn áp', 'Pressure drop');
  String get colFlow => _t('Lưu lượng', 'Flow');
  String get colLevel => _t('Mức', 'Level');
  String get colContent => _t('Nội dung', 'Message');
  String get colNo => _t('STT', 'No.');
  String get colName => _t('Tên thiết bị', 'Equipment');
  String get colSpec => _t('Thông số', 'Specification');
  String get colQty => _t('SL', 'Qty');
  String get colUnitPrice => _t('Đơn giá (VNĐ)', 'Unit price');
  String get colAmount => _t('Thành tiền (VNĐ)', 'Amount');
  String get total => _t('Tổng cộng', 'Total');
  String isoNote(LineQuality q) => q.actualWater == null
      ? ''
      : _t(
          'thực tế nước lớp ${q.actualWater}',
          'actual water class ${q.actualWater}',
        );
  String filters(AirGroup g) {
    final parts = [
      if (g.coarse) _t('Tách thô', 'Coarse'),
      if (g.fine) _t('Tách tinh', 'Fine'),
      if (g.carbon) _t('Than hoạt tính', 'Activated carbon'),
      if (g.sterile) _t('Vô trùng', 'Sterile'),
    ];
    return parts.isEmpty ? '—' : parts.join(' + ');
  }

  String level(WarningLevel v) => switch (v) {
    WarningLevel.error => _t('Lỗi', 'Error'),
    WarningLevel.caution => _t('Lưu ý', 'Caution'),
    WarningLevel.note => _t('Ghi chú', 'Note'),
  };

  // ── Danh mục thiết bị ───────────────────────────────────────────────────
  /// Hậu tố vị trí lọc: sau bình tích khí hoặc theo nhóm máy sấy.
  String _filterSuffix(EquipmentItem e) => e.params['afterTank'] == true
      ? _t(' – sau bình tích khí', ' – after receiver')
      : _groupSuffix(e.group);

  String _groupSuffix(DryerKind? g) => switch (g) {
    DryerKind.desiccant => _t(' – nhóm sấy hấp thụ', ' – desiccant group'),
    DryerKind.refrigerated => _t(' – nhóm sấy lạnh', ' – refrigerated group'),
    DryerKind.none => _t(' – nhóm không sấy', ' – no-dryer group'),
    null => '',
  };
  String _for(Object? lines) {
    final names = (lines as List).join(', ');
    return _t('cho $names', 'for $names');
  }

  String equipmentName(EquipmentItem e) {
    final p = e.params;
    return switch (e.kind) {
      EquipmentKind.compressor => () {
        final pick = p['pick'] as CompressorPick?;
        final name = pick?.model?.modelCode ?? pick?.manualName;
        return name == null
            ? compressorTypeName(p['type'] as CompressorType)
            : _t('Máy nén khí $name', 'Air compressor $name');
      }(),
      EquipmentKind.tank => () {
        final t = p['tank'] as TankPick;
        return t.spec == null
            ? _t('Bình chứa khí', 'Air receiver tank')
            : _t(
                'Bình chứa khí ${t.spec!.model}',
                'Air receiver ${t.spec!.model}',
              );
      }(),
      EquipmentKind.afterCooler =>
        'After cooler ${afterCooler(p['type'] as AfterCoolerType).toLowerCase()}',
      EquipmentKind.waterSeparator => waterSeparator,
      EquipmentKind.desiccantDryer => _t(
        'Máy sấy hấp thụ (${regen(p['regen'] as RegenType).toLowerCase()})',
        'Desiccant dryer (${regen(p['regen'] as RegenType).toLowerCase()})',
      ),
      EquipmentKind.refrigeratedDryer => () {
        final pick = p['pick'] as DryerPick?;
        final model = pick == null ? '' : ' ${pick.spec.model}';
        return _t('Máy sấy tác nhân lạnh$model', 'Refrigerated dryer$model');
      }(),
      EquipmentKind.coarseFilter => '$coarseFilter${_filterSuffix(e)}',
      EquipmentKind.fineFilter => '$fineFilter${_filterSuffix(e)}',
      EquipmentKind.carbonFilter => '$carbon${_groupSuffix(e.group)}',
      EquipmentKind.sterileFilter => '$sterile${_groupSuffix(e.group)}',
      EquipmentKind.autoDrain => _t('Van xả tự động', 'Automatic drain valve'),
      EquipmentKind.oilWaterSeparator => _t(
        'Bộ tách dầu – nước',
        'Oil-water separator',
      ),
      EquipmentKind.mccb => _t(
        'MCCB máy nén ${p['model']}',
        'Compressor MCCB ${p['model']}',
      ),
      EquipmentKind.cable => _t(
        'Cáp điện máy nén ${p['model']}',
        'Compressor power cable ${p['model']}',
      ),
      EquipmentKind.extra => p['name'] as String? ?? '',
    };
  }

  String equipmentSpec(EquipmentItem e) {
    final p = e.params;
    switch (e.kind) {
      case EquipmentKind.compressor:
        final pick = p['pick'] as CompressorPick?;
        final parts = [
          _t(
            'Cần ${flow(p['flow'] as double)} @ ${bar(p['pressure'] as double)}',
            'Required ${flow(p['flow'] as double)} @ ${bar(p['pressure'] as double)}',
          ),
          _t(
            'ước tính ~${n0(p['power'] as double)} kW',
            'est. ~${n0(p['power'] as double)} kW',
          ),
          if (p['motor'] != null)
            _t(
              'động cơ ${n2(p['motor'] as double)} kW',
              'motor ${n2(p['motor'] as double)} kW',
            ),
          if (pick?.model != null || pick?.manualName != null)
            _t('Máy chọn: ', 'Selected: ') +
                [
                  if (pick!.flowAtPressure != null)
                    '${flow(pick.flowAtPressure!)}${_t('/máy', '/unit')}',
                  if (pick.powerKw != null) '${n2(pick.powerKw!)} kW',
                ].join(', '),
          if ((pick?.units ?? 1) > 1)
            _t(
              '${pick!.units} máy chạy song song',
              '${pick.units} units in parallel',
            ),
          compressorType(p['type'] as CompressorType),
        ];
        return parts.join(' · ');
      case EquipmentKind.tank:
        final t = p['tank'] as TankPick;
        final s = t.spec;
        final parts = [
          '${n2(t.volumeM3)} m³',
          if (s != null) ...[
            _t(
              'thiết kế ${n2(s.designPressureKgfCm2)} kgf/cm²',
              'design ${n2(s.designPressureKgfCm2)} kgf/cm²',
            ),
            _t(
              'thử tải ${n2(s.testPressureKgfCm2)} kgf/cm²',
              'test ${n2(s.testPressureKgfCm2)} kgf/cm²',
            ),
            'Ø${n0(s.diameterMm)} mm',
            '${n0(s.weightKg)} kg',
          ],
          if (s == null || t.designInsufficient)
            _t(
              'cần thiết kế ≥ ${n2(t.designPressure)} bar (đặt riêng)',
              'needs design ≥ ${n2(t.designPressure)} bar (custom order)',
            ),
          if (t.tooLarge)
            _t(
              'cần ≥ ${n2(t.requiredM3)} m³',
              'required ≥ ${n2(t.requiredM3)} m³',
            ),
        ];
        return parts.join(' · ');
      case EquipmentKind.afterCooler:
      case EquipmentKind.waterSeparator:
        return flow(p['flow'] as double);
      case EquipmentKind.desiccantDryer:
        return [
          _t(
            'Đầu vào ${flow(p['inlet'] as double)}',
            'Inlet ${flow(p['inlet'] as double)}',
          ),
          'PDP ${pdp(p['pdp'] as int?)}',
          _t(
            'khí xả ${flow(p['purge'] as double)} (${percent(p['rate'] as double)})',
            'purge ${flow(p['purge'] as double)} (${percent(p['rate'] as double)})',
          ),
          _for(p['lines']),
        ].join(' · ');
      case EquipmentKind.refrigeratedDryer:
        final pick = p['pick'] as DryerPick?;
        if (pick == null) {
          return [
            flow(p['inlet'] as double),
            'PDP ${pdp(p['pdp'] as int?)}',
            _for(p['lines']),
          ].join(' · ');
        }
        final d = pick.spec;
        return [
          _t(
            '${flow(d.capacityM3min)}/máy (cần ${flow(pick.inlet)})',
            '${flow(d.capacityM3min)}/unit (needs ${flow(pick.inlet)})',
          ),
          if (pick.compressorKw case final kw?)
            _t(
              'theo máy nén ${n2(kw)} kW',
              'matched to ${n2(kw)} kW compressor',
            ),
          'PDP ${pdp(p['pdp'] as int?)}',
          _t(
            'máy nén lạnh ${n2(d.compressorKw)} kW + quạt ${n0(d.fanW)} W',
            'refrigeration ${n2(d.compressorKw)} kW + fan ${n0(d.fanW)} W',
          ),
          d.airOutlet,
          _for(p['lines']),
        ].join(' · ');
      case EquipmentKind.coarseFilter:
      case EquipmentKind.fineFilter:
      case EquipmentKind.carbonFilter:
      case EquipmentKind.sterileFilter:
        return p['lines'] == null
            ? flow(p['flow'] as double)
            : '${flow(p['flow'] as double)} · ${_for(p['lines'])}';
      case EquipmentKind.autoDrain:
        final sources = p['sources'] as Map<String, int>;
        String label(String key, int n) => switch (key) {
          'tank' => _t('bình chứa', 'receiver'),
          'afterCooler' => 'after cooler',
          'waterSeparator' => _t('lọc tách nước', 'water separator'),
          'tankFilter' => _t('$n lọc sau bình', '$n filter(s) after receiver'),
          'coarseFilter' => _t('$n lọc tách thô', '$n coarse filter(s)'),
          'fineFilter' => _t('$n lọc tách tinh', '$n fine filter(s)'),
          'refrigeratedDryer' => _t(
            '$n máy sấy lạnh',
            '$n refrigerated dryer(s)',
          ),
          _ => key,
        };
        return _t('Cho ', 'For ') +
            [for (final e in sources.entries) label(e.key, e.value)].join(', ');
      case EquipmentKind.oilWaterSeparator:
        return _t(
          'Xử lý nước ngưng lẫn dầu trước khi xả',
          'Treats oily condensate before discharge',
        );
      case EquipmentKind.mccb:
        return '${p['mccb']} A';
      case EquipmentKind.cable:
        return '${p['cable']} mm²';
      case EquipmentKind.extra:
        return p['spec'] as String? ?? '';
    }
  }

  /// Tên/thông số hiển thị: ưu tiên phần người dùng sửa tay.
  String displayName(EquipmentItem e, AirConfig config) {
    final o = config.overrides[e.key]?.name?.trim();
    return o == null || o.isEmpty ? equipmentName(e) : o;
  }

  String displaySpec(EquipmentItem e, AirConfig config) {
    final o = config.overrides[e.key]?.spec?.trim();
    return o == null || o.isEmpty ? equipmentSpec(e) : o;
  }

  String get editEquipment => _t('Sửa thiết bị', 'Edit equipment');
  String get addEquipment => _t('Thêm thiết bị', 'Add equipment');
  String get resetAuto => _t('Về giá trị tự tính', 'Reset to calculated');
  String get autoValueHint => _t('Trống = tự tính', 'Empty = calculated');

  // ── Cảnh báo ─────────────────────────────────────────────────────────────
  String warning(AirWarning w) {
    final p = w.params;
    String num1(String key) => n1(p[key] as num);
    String num2(String key) => n2(p[key] as num);
    return switch (w.code) {
      AirWarningCode.invalidInput => switch (p['field']) {
        'pressure' => _t(
          'Áp suất làm việc phải từ ${num2('min')} đến ${num2('max')} bar.',
          'Working pressure must be ${num2('min')}–${num2('max')} bar.',
        ),
        'demand' => _t(
          'Nhập nhu cầu khách hàng (m³/phút) lớn hơn 0.',
          'Enter a customer demand (m³/min) greater than 0.',
        ),
        'margin' => _t(
          'Lưu lượng máy lớn hơn nhu cầu phải từ 0 đến 100%.',
          'The flow margin over demand must be 0–100%.',
        ),
        'usePressure' => _t(
          'Nhập áp suất sử dụng (bar) ở mục Xử lý khí.',
          'Enter the point-of-use pressure (bar) under Air treatment.',
        ),
        'manualFad' => _t(
          'Nhập lưu lượng máy (FAD) của máy nhập tay.',
          'Enter the unit flow (FAD) of the manual compressor.',
        ),
        'tankVolume' => _t(
          'Thể tích bình chọn tay phải lớn hơn 0.',
          'Manual receiver volume must be greater than 0.',
        ),
        _ => _t('Đầu vào không hợp lệ.', 'Invalid input.'),
      },
      AirWarningCode.oilNoOilFilter => _t(
        'Máy có dầu nhưng có nhánh không có lọc tách tinh 0,01 µm: dầu chỉ đạt ISO 8573-1 lớp 4.',
        'Oil-injected compressor and a branch without a 0.01 µm fine filter: oil only reaches ISO 8573-1 class 4.',
      ),
      AirWarningCode.desiccantNoOilFilter => _t(
        'Máy có dầu + máy sấy hấp thụ: nên thêm lọc tách tinh trước máy sấy (Nâng cao → Lọc sau bình tích khí × 2) để bảo vệ hạt hút ẩm.',
        'Oil-injected compressor + desiccant dryer: add a fine filter before the dryer (Advanced → Filters after the receiver × 2) to protect the desiccant.',
      ),
      AirWarningCode.powerOver => _t(
        'Công suất ước tính ~${n0(p['power'] as num)} kW vượt ${num2('max')} kW: nên chia nhiều máy nén.',
        'Estimated power ~${n0(p['power'] as num)} kW exceeds ${num2('max')} kW: split into several compressors.',
      ),
      AirWarningCode.noTank => _t(
        'Không có bình chứa: máy nén chạy tải/không tải nhiều hơn.',
        'No air receiver: the compressor will load/unload more often.',
      ),
      AirWarningCode.purge => _t(
        'Khí xả tái sinh ${percent(p['rate'] as double)} = ${num1('purge')} $flowUnit đã cộng vào lưu lượng máy nén.',
        'Regeneration purge ${percent(p['rate'] as double)} = ${num1('purge')} $flowUnit is added to the compressor flow.',
      ),
      AirWarningCode.fourInOneIntegrated => _t(
        'Máy 4 trong 1 ${p['model']} đã tích hợp máy sấy lạnh${p['tank'] == null ? '' : ' và bình chứa ${num2('tank')} lít'}: cân nhắc bỏ máy sấy lạnh/bình chứa riêng trong danh mục.',
        '4-in-1 unit ${p['model']} already includes a refrigerated dryer${p['tank'] == null ? '' : ' and a ${num2('tank')} L receiver'}: consider removing the separate dryer/receiver.',
      ),
      AirWarningCode.dryerPressureHigh => _t(
        'Máy sấy lạnh ${p['model']} tiêu chuẩn chịu tới ${num2('max')} bar, áp làm việc ${num2('pressure')} bar: đặt bản áp cao riêng (16/20/30/40 bar).',
        'Refrigerated dryer ${p['model']} is rated up to ${num2('max')} bar; working pressure is ${num2('pressure')} bar: order a high-pressure version (16/20/30/40 bar).',
      ),
      AirWarningCode.noDryerModel => _t(
        'Dữ liệu chưa có máy sấy lạnh phù hợp: thông số máy sấy ghi theo nhu cầu.',
        'No suitable refrigerated dryer in the catalog: dryer data follows the demand.',
      ),
      AirWarningCode.modelFlowLow => _t(
        'Máy nén ${p['model']} cho ${num1('flow')} $flowUnit, nhỏ hơn lưu lượng cần ${num1('need')} $flowUnit.',
        'Compressor ${p['model']} delivers ${num1('flow')} $flowUnit, below the required ${num1('need')} $flowUnit.',
      ),
      AirWarningCode.noCatalogModel => noCatalogFor(
        p['type'] as CompressorType,
      ),
      AirWarningCode.catalogPressure => _t(
        'Dữ liệu model chỉ có lưu lượng tới ${num2('max')} bar: kiểm tra lưu lượng thực tế hoặc nhập tay.',
        'Catalog flows only go up to ${num2('max')} bar: check the actual flow or enter it manually.',
      ),
      AirWarningCode.tankTooLarge => _t(
        'Bình cần ≥ ${num2('required')} m³, vượt bình lớn nhất trong dữ liệu (${num2('max')} m³): dùng nhiều bình hoặc đặt riêng.',
        'Receiver needs ≥ ${num2('required')} m³, above the largest in the catalog (${num2('max')} m³): use several tanks or a custom one.',
      ),
      AirWarningCode.tankDesignHigh => _t(
        'Áp làm việc cần bình thiết kế ${num2('design')} bar, dữ liệu bình chỉ có ${num2('tankDesign')} kgf/cm²: đặt bình áp cao riêng.',
        'The working pressure needs a ${num2('design')} bar receiver; catalog tanks are ${num2('tankDesign')} kgf/cm²: order a high-pressure tank.',
      ),
      AirWarningCode.tankManualNotInCatalog => _t(
        'Thể tích bình chọn tay không trùng cỡ trong dữ liệu: thông số bình ghi theo nhập tay.',
        'Manual receiver volume is not a catalog size: tank data follows your input.',
      ),
    };
  }

  // ── Sơ đồ ────────────────────────────────────────────────────────────────
  String get diagramTitle =>
      _t('Sơ đồ lắp đặt hệ thống khí nén', 'Complete Installation Layout');
  String composition(AirConfig config, AirResult r) {
    final parts = <String>[
      '${r.compressorQty} ${_lowerFirst(compressorTypeName(config.compressor.type))}',
      if (r.tank != null) _t('1 bình chứa', '1 Air Receiver'),
      for (final g in r.groups)
        if (g.hasDryer) '1 ${_lowerFirst(dryerTitle(g.kind))}',
    ];
    return parts.join(' + ');
  }

  String _lowerFirst(String s) =>
      isEn || s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  List<String> diagramCompressor(AirConfig config, AirResult r, String name) =>
      [
        name,
        if (name != compressorTypeName(config.compressor.type))
          compressorType(config.compressor.type),
        _t('Lưu lượng: ${flow(r.flow)}', 'Total flow: ${flow(r.flow)}'),
        _t('Công suất: ${powerCard(r).$2}', 'Power: ${powerCard(r).$2}'),
        _t(
          'Áp suất làm việc: ${bar(r.pressure)}',
          'Working pressure: ${bar(r.pressure)}',
        ),
        if (config.compressor.type.isOilFree) 'ISO 8573-1 Class 0',
        if (r.compressorQty > 1)
          _t('SL: ${r.compressorQty}', 'Qty: ${r.compressorQty}'),
      ];
  String get tankTitle => _t('Bình chứa khí', 'Air Receiver Tank');
  List<String> diagramTank(TankPick t, String model) => [
    // Mỗi ý một dòng ngắn để ô bình chứa trên sơ đồ hẹp lại.
    tankTitle,
    if (model.isNotEmpty) model,
    _t('Thể tích: ${n2(t.volumeM3)} m³', 'Volume: ${n2(t.volumeM3)} m³'),
    _t(
      'Thiết kế: ${n2(t.designPressure)} bar',
      'Design: ${n2(t.designPressure)} bar',
    ),
  ];
  String get pretreatTitle => _t('Lọc đường ống', 'Pipeline Filters');
  String get afterCoolerTitle => _t('After cooling', 'After Cooling');
  String get postFilters => _t('Lọc sau', 'Post filters');

  // Tên lọc trên sơ đồ (ngắn, đơn vị micron).
  String get diagramFilterTitle => _t('Lọc', 'Filters');
  String get diagramWaterSeparator =>
      _t('Tách nước 3 micron', 'Water separator 3 micron');
  String get diagramCoarse => _t('Tách thô 1 micron', 'Coarse 1 micron');
  String get diagramFine => _t('Tách tinh 0,01 micron', 'Fine 0.01 micron');

  /// Tiêu đề + từng lọc, đánh số liên tục trên toàn hệ thống (lọc tuyến chính
  /// trước, [start] là số của lọc sau máy sấy đầu tiên), khớp số vẽ trên đầu
  /// mỗi lọc.
  List<String> diagramPostFilters(
    AirGroup g, {
    int start = 1,
    bool drain = false,
  }) {
    final grades = [
      if (g.coarse) diagramCoarse,
      if (g.fine) diagramFine,
      if (g.carbon) _t('Than hoạt tính', 'Activated carbon'),
      if (g.sterile) _t('Vô trùng', 'Sterile'),
    ];
    return [
      diagramFilterTitle,
      for (var k = 0; k < grades.length; k++) '${start + k}. ${grades[k]}',
      if (drain) autoDrain,
    ];
  }

  /// Ghi chú máy sấy: dòng đầu (in đậm) là model, rồi lưu lượng xử lý, công
  /// suất điện vào (máy nén lạnh + quạt), điểm sương.
  List<String> diagramGroup(
    AirGroup g,
    List<String> lineNames, [
    DryerPick? dryer,
  ]) {
    if (!g.hasDryer) return const [];
    if (dryer == null) {
      return [
        dryerTitle(g.kind),
        _t('Lưu lượng: ${flow(g.dryerInlet)}', 'Flow: ${flow(g.dryerInlet)}'),
        _t('Điểm sương: ${pdp(g.pdp)}', 'Dew point: ${pdp(g.pdp)}'),
      ];
    }
    final d = dryer.spec;
    final kw = dryer.units * (d.compressorKw + d.fanW / 1000);
    return [
      '${dryer.units > 1 ? '${dryer.units} × ' : ''}${d.model}',
      _t('Lưu lượng: ${flow(dryer.capacity)}', 'Flow: ${flow(dryer.capacity)}'),
      _t('Công suất: ${n2(kw)} kW', 'Power: ${n2(kw)} kW'),
      _t('Điểm sương: ${pdp(g.pdp)}', 'Dew point: ${pdp(g.pdp)}'),
    ];
  }

  String get legendMain =>
      _t('Khí nén (tuyến chính)', 'Compressed air (main line)');
  String get legendSupply =>
      _t('Đường tới thiết bị sử dụng', 'To point of use');
  String get legendFilter => _t('Bộ lọc đường ống', 'Pipeline filters');
  String get legendDrain => autoDrain;

  // ── Lưu, xuất ───────────────────────────────────────────────────────────
  String get save => _t('Lưu', 'Save');
  String get saved => _t('Đã lưu cấu hình', 'Configuration saved');
  String get export => _t('Xuất file', 'Export');
  String get duplicate => _t('Nhân bản', 'Duplicate');
  String get exportPdf => _t('PDF (A3 ngang)', 'PDF (A3 landscape)');
  String get exportPng => _t('Ảnh sơ đồ PNG', 'Diagram PNG');
  String get exportSvg => _t('Sơ đồ SVG', 'Diagram SVG');
  String get exportExcel => _t('Excel danh mục thiết bị', 'Equipment Excel');
  String get exportJson => _t('JSON cấu hình', 'Configuration JSON');
  String get createdOn => _t('Ngày lập', 'Date');
  String get untitled => _t('Cấu hình chưa đặt tên', 'Untitled configuration');
  String get summary => _t('Thông số tổng', 'System summary');
  String get page => _t('Trang', 'Page');
}
