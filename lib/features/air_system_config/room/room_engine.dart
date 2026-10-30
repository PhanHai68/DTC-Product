import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../../core/utils/air_pipe_diameter.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import 'room_constants.dart';

/// Tính phòng lắp đặt máy nén từ cấu hình + kết quả tính khí nén: kích
/// thước phòng tối thiểu, vị trí thiết bị (mm, gốc tọa độ ở góc trong tường
/// sau – trái; x theo chiều dài, y theo chiều rộng), đường ống, cửa, thông
/// gió. Hàm thuần, không chứa chữ hiển thị.

enum RoomItemKind { panel, compressor, afterCooler, tank, dryer }

enum RoomFilterGrade { water, coarse, fine, carbon, sterile }

enum RoomWall { back, front, left, right }

enum RoomWarningCode {
  /// Phòng thực tế nhỏ hơn phòng tối thiểu (params: needL, needW).
  tooSmall,

  /// Phòng thực tế thấp hơn chiều cao cần (params: needH).
  tooLow,

  /// Có kích thước ước tính (params: kinds).
  estimated,

  /// Cửa chuyển sang tường khác vì vướng thiết bị (params: wall).
  doorMoved,

  /// Thiết bị đã kéo chồng lên nhau hoặc lấn vùng bảo trì (params: items —
  /// số thứ tự trên bản vẽ).
  clash,

  /// Thiết bị nằm (một phần) ngoài phòng (params: items).
  outside,

  /// Nhiệt độ thông gió sai: T2 ≤ T1 (params: t1, t2).
  ventTemps,
}

class RoomWarning {
  const RoomWarning(this.code, [this.params = const {}]);
  final RoomWarningCode code;
  final Map<String, Object?> params;
}

/// Một thiết bị đặt trên sàn.
class RoomItem {
  const RoomItem({
    required this.key,
    required this.kind,
    required this.model,
    required this.lengthMm,
    required this.depthMm,
    required this.heightMm,
    required this.rect,
    required this.zone,
    required this.wall,
    this.sizeEstimated = false,
    this.heightEstimated = false,
    this.rotated = false,
    this.moved = false,
  });

  /// Khóa cố định để lưu vị trí chỉnh tay: `compressor_0`, `tank_0`…
  final String key;

  /// Đã kéo sang vị trí khác vị trí tự động.
  final bool moved;

  final RoomItemKind kind;

  /// Mã model (ACP-100PV, V3000, ACD-13…); `null` khi chưa có.
  final String? model;

  /// Dài (dọc tường) × sâu × cao (mm).
  final double lengthMm;
  final double depthMm;
  final double heightMm;

  /// Khối thiết bị và vùng bảo trì (gồm khoảng trống trước, bên, sau).
  final Rect rect;
  final Rect zone;

  /// Tường thiết bị dựa lưng vào (mặt thao tác quay ra giữa phòng).
  final RoomWall wall;
  final bool sizeEstimated;
  final bool heightEstimated;

  /// Đã xoay 90° (cạnh dài vuông góc tường) — phương án 2, 3.
  final bool rotated;

  bool get isRound => kind == RoomItemKind.tank;

  /// Bản dời khối và vùng bảo trì tới góc trên trái [topLeft].
  RoomItem movedTo(Offset topLeft) {
    final d = topLeft - rect.topLeft;
    return RoomItem(
      key: key,
      kind: kind,
      model: model,
      lengthMm: lengthMm,
      depthMm: depthMm,
      heightMm: heightMm,
      rect: rect.shift(d),
      zone: zone.shift(d),
      wall: wall,
      sizeEstimated: sizeEstimated,
      heightEstimated: heightEstimated,
      rotated: rotated,
      moved: true,
    );
  }
}

/// Một phương án lắp đặt: phòng tối thiểu (đã làm tròn) và có lọt phòng
/// thực tế không.
class RoomOption {
  const RoomOption(this.style, this.lengthMm, this.widthMm, this.fits);
  final RoomStyle style;
  final double lengthMm;
  final double widthMm;
  final bool fits;
}

/// Lọc treo trên ống chính, đánh số theo dòng khí như sơ đồ.
class RoomFilter {
  const RoomFilter(this.at, this.number, this.grade);
  final Offset at;
  final int number;
  final RoomFilterGrade grade;
}

/// Cửa ra vào hoặc cửa lấy gió trên một tường: từ [start] dài [width] (mm,
/// đo dọc tường từ góc trái/trên).
class RoomOpening {
  const RoomOpening(this.wall, this.start, this.width);
  final RoomWall wall;
  final double start;
  final double width;
}

class RoomVentilation {
  const RoomVentilation({
    required this.compressorKw,
    required this.dryerKw,
    required this.outsideTempC,
    required this.inletMaxTempC,
    required this.airflowM3s,
    required this.openingM2,
  });

  /// N, D (kW).
  final double compressorKw;
  final double dryerKw;

  /// T1, T2 (°C).
  final double outsideTempC;
  final double inletMaxTempC;
  final double airflowM3s;
  final double openingM2;

  double get deltaT => inletMaxTempC - outsideTempC;
  double get airflowM3h => airflowM3s * 3600;

  /// Lưu lượng đề xuất: m³/s làm tròn số nguyên, m³/h quy đổi từ đó
  /// (vd 7,6 → 8 m³/s → 28.800 m³/h).
  double get suggestedM3s => airflowM3s.roundToDouble();
  double get suggestedM3h => suggestedM3s * 3600;
  bool get valid => deltaT > 0;
}

class RoomResult {
  const RoomResult({
    required this.style,
    required this.options,
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    required this.minLengthMm,
    required this.minWidthMm,
    required this.minHeightMm,
    required this.actual,
    required this.fits,
    required this.items,
    required this.filters,
    required this.mainPipe,
    required this.supplyPipe,
    required this.branches,
    required this.door,
    required this.intake,
    required this.ventilation,
    required this.pipeDiameterMm,
    required this.pipeDn,
    required this.filterModel,
    required this.filterSizeMm,
    required this.filterEstimated,
    required this.warnings,
  });

  /// Phương án đang chọn.
  final RoomStyle style;

  /// Cả 3 phương án để so sánh.
  final List<RoomOption> options;

  /// Phòng trên bản vẽ: phòng thực tế nếu đã nhập và lọt, không thì phòng
  /// tối thiểu.
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  final double minLengthMm;
  final double minWidthMm;
  final double minHeightMm;

  /// Đã nhập phòng thực tế.
  final bool actual;

  /// Thiết bị lọt phòng thực tế (luôn `true` khi chưa nhập).
  final bool fits;
  final List<RoomItem> items;
  final List<RoomFilter> filters;

  /// Ống chính: màu tuyến chính tới hết lọc cuối, sau đó tới điểm ra xưởng.
  final List<Offset> mainPipe;
  final List<Offset> supplyPipe;

  /// Nhánh ngắn (ống chính → lưng thiết bị).
  final List<(Offset, Offset)> branches;
  final RoomOpening door;
  final RoomOpening intake;
  final RoomVentilation ventilation;
  final double pipeDiameterMm;

  /// Cỡ ống tiêu chuẩn (DN), `null` khi vượt bảng.
  final String? pipeDn;

  /// Lọc trên ống chính: model lọc đường ống đã chọn và kích thước thân lọc
  /// (dài, rộng, cao mm); [filterEstimated] khi chưa có dữ liệu.
  final String? filterModel;
  final (double, double, double) filterSizeMm;
  final bool filterEstimated;
  final List<RoomWarning> warnings;

  Iterable<RoomItem> of(RoomItemKind kind) =>
      items.where((i) => i.kind == kind);
}

class RoomEngine {
  const RoomEngine({required this.constants, this.pipes = const []});

  final RoomConstants constants;

  /// `pipe_standard.json` (DN ↔ mm).
  final List<Map<String, dynamic>> pipes;

  RoomResult compute(AirConfig config, AirResult r) {
    final c = constants;
    final room = config.room;
    final specs = _specs(config, r);
    final mainFilters = _mainFilters(config, r);
    final postFilters = _postFilters(r);
    final estimated = <String>{
      for (final s in specs)
        if (s.sizeEstimated || s.heightEstimated) s.kind.name,
    };

    final filter = _filterSize(r);
    if (filter.$4) estimated.add('filter');

    // 3 phương án một hàng dọc tường sau: 1 = máy nén, máy sấy dọc tường;
    // 2 = máy sấy xoay 90°; 3 = máy nén và máy sấy xoay 90°.
    final layouts = <RoomStyle, _Layout>{
      for (final style in RoomStyle.values)
        style: _row(
          _orient(specs, style, room.turned),
          mainFilters,
          postFilters,
          filter,
        ),
    };

    final actualL = room.hasActual ? room.lengthM! * 1000 : null;
    final actualW = room.hasActual ? room.widthM! * 1000 : null;
    double up(double v) => (v / c.roundToMm - 1e-9).ceil() * c.roundToMm;
    bool fitsIn(_Layout l) =>
        actualL == null ||
        (up(l.minL) <= actualL + 1e-6 && up(l.minW) <= actualW! + 1e-6);
    final options = [
      for (final e in layouts.entries)
        RoomOption(e.key, up(e.value.minL), up(e.value.minW), fitsIn(e.value)),
    ];

    final style = room.style;
    final layout = layouts[style]!;
    final fits = fitsIn(layout);
    final minL = up(layout.minL);
    final minW = up(layout.minW);
    final tallest = specs.fold(0.0, (m, s) => math.max(m, s.h));
    final minH = up(math.max(c.minRoomHeightMm, tallest + c.headroomMm));
    // Phòng có sẵn: luôn vẽ đúng kích thước nhập (kể cả khi chưa lọt) để
    // người dùng kéo / xoay thiết bị cho vừa.
    final useActual = actualL != null;
    final L = useActual ? actualL : minL;
    final W = useActual ? actualW! : minW;
    final H = room.hasActual && (room.heightM ?? 0) > 0
        ? room.heightM! * 1000
        : minH;

    final placed = layout.place(L, W);
    _applyMoves(placed, room.positions, L, W);
    final warnings = <RoomWarning>[
      if (!fits)
        RoomWarning(RoomWarningCode.tooSmall, {
          'style': style,
          'needL': minL,
          'needW': minW,
          'fitting': [
            for (final o in options)
              if (o.fits) o.style,
          ],
        }),
      if (room.hasActual && (room.heightM ?? 0) > 0 && H + 1e-6 < minH)
        RoomWarning(RoomWarningCode.tooLow, {'needH': minH}),
      if (estimated.isNotEmpty)
        RoomWarning(RoomWarningCode.estimated, {'kinds': estimated.toList()}),
      if (_clashes(placed.items) case final clash when clash.isNotEmpty)
        RoomWarning(RoomWarningCode.clash, {'items': clash}),
      if (_outside(placed.items, L, W) case final out when out.isNotEmpty)
        RoomWarning(RoomWarningCode.outside, {'items': out}),
    ];

    // Cửa: đủ rộng để đưa thiết bị lớn nhất qua (cạnh ngắn + khoảng hở).
    final doorW = math.max(
      c.doorMinWidthMm,
      specs.fold(0.0, (m, s) => math.max(m, math.min(s.w, s.d))) +
          c.doorMarginMm,
    );
    final door = _door(room.door, doorW, L, W, placed, warnings);

    final vent = _ventilation(r, room);
    if (!vent.valid) {
      warnings.add(
        RoomWarning(RoomWarningCode.ventTemps, {
          't1': vent.outsideTempC,
          't2': vent.inletMaxTempC,
        }),
      );
    }
    final intake = _intake(vent, L, W, placed, door);

    final diameter = r.flow > 0
        ? airPipeDiameterMm(
            flow: r.flow,
            lengthM: c.pipeLengthM,
            dropBar: c.pipeDropBar,
            maxPressureBar: r.pressure > 0
                ? r.pressure
                : airPipeDefaultPressureBar,
          )
        : 0.0;
    final pipe = diameter > 0 ? standardPipeFor(diameter, pipes) : null;

    return RoomResult(
      style: style,
      options: options,
      lengthMm: L,
      widthMm: W,
      heightMm: H,
      minLengthMm: minL,
      minWidthMm: minW,
      minHeightMm: minH,
      actual: room.hasActual,
      fits: fits,
      items: placed.items,
      filters: placed.filters,
      mainPipe: placed.mainPipe,
      supplyPipe: placed.supplyPipe,
      branches: placed.branches,
      door: door,
      intake: intake,
      ventilation: vent,
      pipeDiameterMm: diameter,
      pipeDn: pipe == null ? null : 'DN${pipe['dn']}',
      filterModel: r.lineFilter?.spec.model,
      filterSizeMm: (filter.$1, filter.$2, filter.$3),
      filterEstimated: filter.$4,
      warnings: warnings,
    );
  }

  // ── Thiết bị và kích thước ──────────────────────────────────────────────
  List<_Spec> _specs(AirConfig config, AirResult r) {
    final c = constants;
    final out = <_Spec>[];
    _Spec spec(
      RoomItemKind kind,
      String? model,
      (double, double, double) size, {
      String clearance = '',
      bool sizeEstimated = false,
      bool heightEstimated = false,
    }) => _Spec(
      kind: kind,
      model: model,
      w: size.$1,
      d: size.$2,
      h: size.$3,
      c: c.clearance(clearance.isEmpty ? kind.name : clearance),
      sizeEstimated: sizeEstimated,
      heightEstimated: heightEstimated,
    );

    out.add(
      spec(
        RoomItemKind.panel,
        null,
        c.standardSize('panel'),
        // Tủ điện 500 × 400 × 300 mm (DTC).
      ),
    );
    final pick = r.compressor;
    final dims = pick?.model?.dimensionsMm;
    final name = pick?.model?.modelCode ?? pick?.manualName;
    for (var k = 0; k < math.max(1, r.compressorQty); k++) {
      out.add(
        spec(
          RoomItemKind.compressor,
          name,
          dims ?? c.standardSize('unknownCompressor'),
          sizeEstimated: dims == null,
        ),
      );
    }
    if (config.pretreat.afterCooler != AfterCoolerType.none) {
      out.add(
        spec(
          RoomItemKind.afterCooler,
          null,
          c.standardSize('afterCooler'),
          sizeEstimated: true,
        ),
      );
    }
    final tank = r.tank;
    if (tank != null) {
      // Bình đứng: lấy đường kính catalog (không có thì ước theo H/D = 2,5),
      // chiều cao ước tính từ thể tích.
      final volumeMm3 = tank.volumeM3 * 1e9;
      final d =
          tank.spec?.diameterMm ??
          math.pow(4 * volumeMm3 / (math.pi * 2.5), 1 / 3).toDouble();
      final body = volumeMm3 / (math.pi * d * d / 4);
      final h = body + c.tankHeadFactor * d + c.tankLegsMm;
      out.add(
        spec(
          RoomItemKind.tank,
          tank.spec?.model,
          (d, d, h),
          sizeEstimated: tank.spec == null,
          heightEstimated: true,
        ),
      );
    }
    final group = r.groups.firstOrNull;
    if (group != null && group.hasDryer) {
      final dryer = r.dryerPicks[group.kind];
      if (dryer != null) {
        for (var k = 0; k < dryer.units; k++) {
          final d = dryer.spec;
          out.add(
            spec(RoomItemKind.dryer, d.model, (
              d.lengthMm,
              d.widthMm,
              d.heightMm,
            )),
          );
        }
      } else {
        out.add(
          spec(
            RoomItemKind.dryer,
            null,
            c.standardSize(
              group.kind == DryerKind.desiccant
                  ? 'desiccantDryer'
                  : 'unknownDryer',
            ),
            sizeEstimated: true,
          ),
        );
      }
    }
    return out;
  }

  /// Lọc tuyến chính theo dòng khí: tách nước.
  List<RoomFilterGrade> _mainFilters(AirConfig config, AirResult r) => [
    if (config.pretreat.hasWaterSeparator) RoomFilterGrade.water,
  ];

  List<RoomFilterGrade> _postFilters(AirResult r) {
    final g = r.groups.firstOrNull;
    if (g == null) return const [];
    return [
      if (g.coarse) RoomFilterGrade.coarse,
      if (g.fine) RoomFilterGrade.fine,
      if (g.carbon) RoomFilterGrade.carbon,
      if (g.sterile) RoomFilterGrade.sterile,
    ];
  }

  // ── Xếp dãy ─────────────────────────────────────────────────────────────
  /// Xếp một dãy dọc tường: vị trí dọc tường của từng thiết bị và lọc, tổng
  /// chiều dài dãy. Khoảng giữa hai thiết bị = khoảng bảo trì bên lớn hơn
  /// (dùng chung), đủ chỗ cho lọc treo trên ống nằm giữa.
  /// [filterW]: bề rộng thân lọc (bước lọc trên ống không nhỏ hơn lọc + 100).
  _Run _run(List<_Entry> entries, double filterW) {
    final c = constants;
    final pitch = math.max(c.filterPitchMm, filterW + 100);
    double filtersNeed(int n) => n == 0 ? 0 : n * pitch + 2 * 150;
    var pos = 0.0;
    var prevSide = c.wallGapMm;
    final pending = <RoomFilterGrade>[];
    final items = <(_Spec, double)>[];
    final filters = <(RoomFilterGrade, double)>[];
    void placePending(double from, double to) {
      final mid = (from + to) / 2;
      for (var k = 0; k < pending.length; k++) {
        filters.add((pending[k], mid + (k - (pending.length - 1) / 2) * pitch));
      }
      pending.clear();
    }

    for (final e in entries) {
      if (e.filter != null) {
        pending.add(e.filter!);
        continue;
      }
      final s = e.spec!;
      final gap = [
        prevSide,
        s.c.side,
        filtersNeed(pending.length),
        if (items.isEmpty) c.wallGapMm,
      ].reduce(math.max);
      placePending(pos, pos + gap);
      pos += gap;
      items.add((s, pos));
      pos += s.w;
      prevSide = s.c.side;
    }
    final end = [
      prevSide,
      c.wallGapMm,
      filtersNeed(pending.length),
    ].reduce(math.max);
    placePending(pos, pos + end);
    pos += end;
    final depth = items.fold(0.0, (m, i) => math.max(m, i.$1.c.rear + i.$1.d));
    final front = items.fold(0.0, (m, i) => math.max(m, i.$1.c.front));
    return _Run(items, filters, pos, depth, front);
  }

  List<_Entry> _entries(
    List<_Spec> specs, {
    List<RoomFilterGrade> afterTank = const [],
    List<RoomFilterGrade> afterDryer = const [],
  }) {
    final out = <_Entry>[];
    // Lọc tuyến chính sau bình (không có bình: sau máy nén / after cooler).
    final mainAnchor = specs.lastIndexWhere(
      (s) =>
          s.kind == RoomItemKind.tank ||
          s.kind == RoomItemKind.compressor ||
          s.kind == RoomItemKind.afterCooler,
    );
    final dryerAnchor = specs.lastIndexWhere(
      (s) => s.kind == RoomItemKind.dryer,
    );
    for (var k = 0; k < specs.length; k++) {
      out.add(_Entry.spec(specs[k]));
      if (k == mainAnchor) out.addAll(afterTank.map(_Entry.filter));
      if (k == dryerAnchor) out.addAll(afterDryer.map(_Entry.filter));
    }
    if (mainAnchor < 0) out.insertAll(0, afterTank.map(_Entry.filter));
    if (dryerAnchor < 0) out.addAll(afterDryer.map(_Entry.filter));
    return out;
  }

  double get _pipeOffset =>
      math.min(constants.clearance('tank').rear, constants.wallGapMm) / 2;

  /// Phương án 2 xoay máy sấy 90° (cạnh dài vuông góc tường); phương án 3
  /// xoay cả máy nén và máy sấy. Thiết bị trong [turned] (xoay tay) đảo
  /// thêm 90° so với phương án.
  List<_Spec> _orient(List<_Spec> specs, RoomStyle style, Set<String> turned) {
    final counts = <RoomItemKind, int>{};
    return [
      for (final s in specs)
        if (((s.kind == RoomItemKind.dryer && style != RoomStyle.option1) ||
                (s.kind == RoomItemKind.compressor &&
                    style == RoomStyle.option3)) !=
            turned.contains(_key(s.kind, counts)))
          s.turned()
        else
          s,
    ];
  }

  /// Khóa thiết bị `<loại>_<thứ tự trong loại>` theo thứ tự xếp dãy.
  static String _key(RoomItemKind kind, Map<RoomItemKind, int> counts) {
    final index = counts[kind] ?? 0;
    counts[kind] = index + 1;
    return '${kind.name}_$index';
  }

  /// Kích thước thân lọc (dài, rộng, cao, ước tính) theo model lọc đường ống
  /// đã chọn; chưa có dữ liệu thì dùng cỡ chuẩn `filter`.
  (double, double, double, bool) _filterSize(AirResult r) {
    final dims = r.lineFilter?.spec.dimensionsMm;
    if (dims != null) return (dims.$1, dims.$2, dims.$3, false);
    final s = constants.standardSize('filter');
    return (s.$1, s.$2, s.$3, true);
  }

  /// Một hàng dọc tường sau; ống chính chạy sau lưng thiết bị, ra tường phải.
  _Layout _row(
    List<_Spec> specs,
    List<RoomFilterGrade> mainFilters,
    List<RoomFilterGrade> postFilters,
    (double, double, double, bool) filter,
  ) {
    final run = _run(
      _entries(specs, afterTank: mainFilters, afterDryer: postFilters),
      filter.$1,
    );
    final minL = run.span;
    final minW = run.depth + math.max(constants.aisleMm, run.front);
    return _Layout(minL, minW, (L, W) {
      final p = _pipeOffset;
      final placed = _Placed();
      _placeRun(run, _WallMap.back(L, W), placed);
      final firstAir = placed.airItems.firstOrNull;
      final points = <Offset>[
        Offset(firstAir?.rect.center.dx ?? constants.wallGapMm, p),
        // Thiết bị tràn ra ngoài phòng có sẵn: ống vẫn chạy tới hết dãy.
        Offset(math.max(L, run.span), p),
      ];
      _pipes(placed, points);
      return placed;
    });
  }

  /// Áp vị trí chỉnh tay (giữ khối trong phòng), rồi vẽ lại nhánh ống từ ống
  /// chính vào các thiết bị trên đường khí.
  void _applyMoves(
    _Placed placed,
    Map<String, (double, double)> positions,
    double L,
    double W,
  ) {
    if (positions.isEmpty) return;
    for (var k = 0; k < placed.items.length; k++) {
      final i = placed.items[k];
      final pos = positions[i.key];
      if (pos == null) continue;
      final x = pos.$1.clamp(0.0, math.max(0.0, L - i.rect.width)).toDouble();
      final y = pos.$2.clamp(0.0, math.max(0.0, W - i.rect.height)).toDouble();
      placed.items[k] = i.movedTo(Offset(x, y));
    }
    final p = _pipeOffset;
    placed.branches
      ..clear()
      ..addAll([
        for (final i in placed.airItems)
          (
            Offset(i.rect.center.dx, p),
            Offset(
              i.rect.center.dx,
              i.rect.top >= p ? i.rect.top : i.rect.bottom,
            ),
          ),
      ]);
    // Ống chính bắt đầu từ thiết bị trên đường khí xa nhất bên trái.
    final firstX = placed.airItems
        .map((i) => i.rect.center.dx)
        .fold(
          placed.mainPipe.isEmpty ? double.infinity : placed.mainPipe.first.dx,
          math.min,
        );
    if (placed.mainPipe.isNotEmpty && firstX.isFinite) {
      placed.mainPipe[0] = Offset(firstX, placed.mainPipe.first.dy);
    }
  }

  /// Thiết bị chồng lên nhau hoặc nằm trong vùng bảo trì của thiết bị khác
  /// (số thứ tự 1, 2… như trên bản vẽ).
  /// Thiết bị (số thứ tự) có khối vượt ra ngoài phòng L × W.
  List<int> _outside(List<RoomItem> items, double L, double W) {
    final room = Rect.fromLTWH(0, 0, L, W).inflate(1);
    return [
      for (var k = 0; k < items.length; k++)
        if (!(room.contains(items[k].rect.topLeft) &&
            room.contains(items[k].rect.bottomRight)))
          k + 1,
    ];
  }

  List<int> _clashes(List<RoomItem> items) {
    final out = <int>{};
    for (var a = 0; a < items.length; a++) {
      for (var b = 0; b < items.length; b++) {
        if (a == b) continue;
        final hit = b > a && items[a].rect.overlaps(items[b].rect);
        // Vùng bảo trì: chỉ phần trước + hai bên (phía sau có thể sát tường).
        final zone = items[b].zone;
        final inZone =
            items[a].rect.overlaps(zone.deflate(1)) &&
            !items[a].rect.overlaps(items[b].rect);
        if (hit || (inZone && (items[a].moved || items[b].moved))) {
          out
            ..add(a + 1)
            ..add(b + 1);
        }
      }
    }
    return out.toList()..sort();
  }

  void _placeRun(_Run run, _WallMap wall, _Placed placed) {
    final counts = <RoomItemKind, int>{};
    for (final (s, a) in run.items) {
      final index = counts[s.kind] ?? 0;
      counts[s.kind] = index + 1;
      final rect = wall.rect(a, s.c.rear, s.w, s.d);
      final zone = wall.rect(
        a - s.c.side,
        0,
        s.w + 2 * s.c.side,
        s.c.rear + s.d + s.c.front,
      );
      placed.items.add(
        RoomItem(
          key: '${s.kind.name}_$index',
          kind: s.kind,
          model: s.model,
          lengthMm: s.w,
          depthMm: s.d,
          heightMm: s.h,
          rect: rect,
          zone: zone,
          wall: wall.wall,
          sizeEstimated: s.sizeEstimated,
          heightEstimated: s.heightEstimated,
          rotated: s.rotated,
        ),
      );
      // Nhánh từ ống chính (sau lưng thiết bị) vào thiết bị trên đường khí.
      if (s.onAir) {
        placed.branches.add((
          wall.at(a + s.w / 2, _pipeOffset),
          wall.at(a + s.w / 2, s.c.rear),
        ));
      }
    }
    for (final (grade, a) in run.filters) {
      placed.filterSpots.add((grade, wall.at(a, _pipeOffset)));
    }
  }

  /// Ống chính theo [points]; nhánh ngắn từ ống vào lưng từng thiết bị trên
  /// đường khí; đánh số lọc theo dòng khí; tách phần sau lọc cuối thành
  /// đường tới thiết bị sử dụng.
  void _pipes(_Placed placed, List<Offset> points) {
    // Thứ tự dọc theo ống = khoảng cách dọc polyline.
    double along(Offset q) {
      var acc = 0.0;
      var best = double.infinity;
      var bestAt = 0.0;
      for (var k = 0; k + 1 < points.length; k++) {
        final a = points[k];
        final b = points[k + 1];
        final ab = b - a;
        final len = ab.distance;
        final t = len == 0
            ? 0.0
            : (((q - a).dx * ab.dx + (q - a).dy * ab.dy) / (len * len)).clamp(
                0.0,
                1.0,
              );
        final proj = a + ab * t;
        final dist = (q - proj).distance;
        if (dist < best - 1e-6) {
          best = dist;
          bestAt = acc + len * t;
        }
        acc += len;
      }
      return bestAt;
    }

    final spots = [...placed.filterSpots]
      ..sort((a, b) => along(a.$2).compareTo(along(b.$2)));
    for (var k = 0; k < spots.length; k++) {
      placed.filters.add(RoomFilter(spots[k].$2, k + 1, spots[k].$1));
    }
    // Đường tới thiết bị sử dụng bắt đầu sau lọc cuối, hoặc sau thiết bị
    // cuối trên đường khí nếu không có lọc.
    final lastAir = placed.airItems.lastOrNull;
    final splitAt = spots.isNotEmpty
        ? along(spots.last.$2) + constants.filterSizeMm
        : lastAir == null
        ? 0.0
        : along(lastAir.rect.center) + 0.0;
    final (main, supply) = _split(points, splitAt);
    placed.mainPipe.addAll(main);
    placed.supplyPipe.addAll(supply);
  }

  (List<Offset>, List<Offset>) _split(List<Offset> points, double at) {
    final main = <Offset>[points.first];
    var acc = 0.0;
    for (var k = 0; k + 1 < points.length; k++) {
      final a = points[k];
      final b = points[k + 1];
      final len = (b - a).distance;
      if (acc + len >= at) {
        final t = len == 0 ? 0.0 : (at - acc) / len;
        final cut = a + (b - a) * t.clamp(0.0, 1.0);
        main.add(cut);
        return (main, [cut, ...points.sublist(k + 1)]);
      }
      main.add(b);
      acc += len;
    }
    return (main, [points.last, points.last]);
  }

  // ── Cửa, thông gió ──────────────────────────────────────────────────────
  RoomOpening _door(
    RoomDoorWall want,
    double width,
    double L,
    double W,
    _Placed placed,
    List<RoomWarning> warnings,
  ) {
    final c = constants;
    // Vùng cánh cửa quét (vuông cạnh = bề rộng cửa) không được chạm thiết bị.
    bool clear(RoomOpening o) {
      final band = _openingRect(o, L, W, depth: width);
      return !placed.items.any((i) => i.rect.inflate(100).overlaps(band));
    }

    /// Vị trí trống đầu tiên dọc tường (bước 100 mm), ưu tiên gần góc như
    /// trước: tường trước tính từ trái, tường bên tính từ dưới lên.
    RoomOpening? on(RoomWall wall) {
      final span = wall == RoomWall.front ? L : W;
      final max = span - width;
      if (max < 0) return null;
      final starts = <double>[
        for (var a = math.min(c.wallGapMm, max); a <= max + 1e-6; a += 100) a,
      ];
      final ordered = wall == RoomWall.front ? starts : starts.reversed;
      for (final a in ordered) {
        final o = RoomOpening(wall, a, width);
        if (clear(o)) return o;
      }
      return null;
    }

    final wanted = switch (want) {
      RoomDoorWall.front => RoomWall.front,
      RoomDoorWall.left => RoomWall.left,
      RoomDoorWall.right => RoomWall.right,
    };
    final first = on(wanted);
    if (first != null) return first;
    for (final wall in [RoomWall.front, RoomWall.left, RoomWall.right]) {
      if (wall == wanted) continue;
      final o = on(wall);
      if (o != null) {
        warnings.add(RoomWarning(RoomWarningCode.doorMoved, {'wall': wall}));
        return o;
      }
    }
    final span = wanted == RoomWall.front ? L : W;
    return RoomOpening(
      wanted,
      math.max(0, math.min(c.wallGapMm, span - width)),
      width,
    );
  }

  /// Lưu lượng gió làm mát phòng máy:
  /// Qv (m³/s) = (1,06 · N + 1,2 · D) / (T2 − T1) — N công suất máy nén,
  /// D công suất máy sấy (kW), T1 nhiệt độ ngoài phòng, T2 nhiệt độ khí vào
  /// máy nén tối đa (°C). T2 ≤ T1 thì không tính được (lưu lượng 0).
  RoomVentilation _ventilation(AirResult r, RoomConfig room) {
    final c = constants;
    final pick = r.compressor;
    final kw = pick?.powerKw != null
        ? pick!.powerKw! * pick.units
        : (r.motorKw ?? r.powerEstimate);
    final dryer = r.dryerPicks.values.firstOrNull;
    final dryerKw = dryer == null
        ? 0.0
        : dryer.units * (dryer.spec.compressorKw + dryer.spec.fanW / 1000);
    final t1 = room.outsideTempC ?? c.outsideTempC;
    final t2 = room.inletMaxTempC ?? c.inletMaxTempC;
    final deltaT = t2 - t1;
    final m3s = deltaT > 0
        ? (c.compressorFactor * kw + c.dryerFactor * dryerKw) / deltaT
        : 0.0;
    return RoomVentilation(
      compressorKw: kw,
      dryerKw: dryerKw,
      outsideTempC: t1,
      inletMaxTempC: t2,
      airflowM3s: m3s,
      // Cửa lấy gió theo lưu lượng đề xuất (đã làm tròn m³/s).
      openingM2: m3s.roundToDouble() / c.openingVelocity,
    );
  }

  /// Cửa lấy gió trên tường trước, đối diện máy nén (cao 1 m nên dài = diện
  /// tích); vướng cửa ra vào hoặc thiết bị thì chuyển sang tường trái.
  RoomOpening _intake(
    RoomVentilation vent,
    double L,
    double W,
    _Placed placed,
    RoomOpening door,
  ) {
    final width = math.max(600.0, vent.openingM2 * 1000);
    final comps = placed.items.where((i) => i.kind == RoomItemKind.compressor);
    final center = comps.isEmpty
        ? L / 2
        : comps.map((i) => i.rect.center.dx).reduce((a, b) => a + b) /
              comps.length;
    final front = RoomOpening(
      RoomWall.front,
      (center - width / 2).clamp(0, math.max(0, L - width)).toDouble(),
      math.min(width, L),
    );
    bool clear(RoomOpening o) {
      final band = _openingRect(o, L, W, depth: 600);
      final doorBand = _openingRect(door, L, W, depth: 600);
      return !band.overlaps(doorBand) &&
          !placed.items.any((i) => i.rect.overlaps(band));
    }

    if (clear(front)) return front;
    // Trùng cửa ra vào trên tường trước: dời sang ngay sau cửa.
    if (door.wall == RoomWall.front) {
      final shifted = RoomOpening(
        RoomWall.front,
        door.start + door.width + 300,
        front.width,
      );
      if (shifted.start + shifted.width <= L && clear(shifted)) return shifted;
    }
    final left = RoomOpening(
      RoomWall.left,
      ((W - width) / 2).clamp(0, math.max(0, W - width)).toDouble(),
      math.min(width, W),
    );
    return clear(left) ? left : front;
  }
}

/// Dải trong phòng sát một khoảng mở trên tường (kiểm tra vướng).
Rect _openingRect(RoomOpening o, double L, double W, {required double depth}) =>
    switch (o.wall) {
      RoomWall.front => Rect.fromLTWH(o.start, W - depth, o.width, depth),
      RoomWall.back => Rect.fromLTWH(o.start, 0, o.width, depth),
      RoomWall.left => Rect.fromLTWH(0, o.start, depth, o.width),
      RoomWall.right => Rect.fromLTWH(L - depth, o.start, depth, o.width),
    };

class _Spec {
  const _Spec({
    required this.kind,
    required this.model,
    required this.w,
    required this.d,
    required this.h,
    required this.c,
    this.sizeEstimated = false,
    this.heightEstimated = false,
    this.rotated = false,
  });
  final RoomItemKind kind;
  final String? model;

  /// Dọc tường × sâu (vuông góc tường) × cao.
  final double w;
  final double d;
  final double h;
  final RoomClearance c;
  final bool sizeEstimated;
  final bool heightEstimated;

  /// Đã xoay 90°: cạnh dài vuông góc tường.
  final bool rotated;

  /// Thiết bị nằm trên đường khí (nối nhánh từ ống chính).
  bool get onAir => kind != RoomItemKind.panel;

  _Spec turned() => _Spec(
    kind: kind,
    model: model,
    w: d,
    d: w,
    h: h,
    c: c,
    sizeEstimated: sizeEstimated,
    heightEstimated: heightEstimated,
    rotated: !rotated,
  );
}

class _Entry {
  _Entry.spec(_Spec this.spec) : filter = null;
  _Entry.filter(RoomFilterGrade this.filter) : spec = null;
  final _Spec? spec;
  final RoomFilterGrade? filter;
}

class _Run {
  const _Run(this.items, this.filters, this.span, this.depth, this.front);

  /// (thiết bị, vị trí dọc tường mép đầu).
  final List<(_Spec, double)> items;
  final List<(RoomFilterGrade, double)> filters;

  /// Tổng chiều dài dãy (kể cả khoảng tới hai tường).
  final double span;

  /// Sâu nhất: khoảng sau + thân thiết bị.
  final double depth;

  /// Khoảng bảo trì trước lớn nhất.
  final double front;
}

class _Placed {
  final items = <RoomItem>[];
  final filterSpots = <(RoomFilterGrade, Offset)>[];
  final filters = <RoomFilter>[];
  final mainPipe = <Offset>[];
  final supplyPipe = <Offset>[];
  final branches = <(Offset, Offset)>[];

  Iterable<RoomItem> get airItems =>
      items.where((i) => i.kind != RoomItemKind.panel);
}

class _Layout {
  const _Layout(this.minL, this.minW, this.place);
  final double minL;
  final double minW;
  final _Placed Function(double L, double W) place;
}

/// Đổi tọa độ dãy (dọc tường a, cách tường n) sang tọa độ phòng.
class _WallMap {
  const _WallMap(this.wall, this.at);

  factory _WallMap.back(double L, double W) =>
      _WallMap(RoomWall.back, (a, n) => Offset(a, n));

  final RoomWall wall;
  final Offset Function(double along, double normal) at;

  Rect rect(double a, double n, double w, double d) =>
      Rect.fromPoints(at(a, n), at(a + w, n + d));
}
