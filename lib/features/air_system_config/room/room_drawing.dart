import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import '../diagram/air_diagram.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import 'room_engine.dart';
import 'room_strings.dart';

/// Bản vẽ mặt bằng phòng lắp đặt, dựng bằng các hình cơ bản của sơ đồ
/// ([AirDiagram]) nên màn hình, PNG và PDF vẽ lại giống nhau.
RoomDrawing buildRoomDrawing(AirConfig config, RoomResult room, AirStrings s) =>
    _RoomDrawing(config, room, s).build();

/// Bản vẽ mặt bằng kèm phép đổi tọa độ: [origin] là góc trong tường sau –
/// trái (px), [scale] px trên mm.
class RoomDrawing extends AirDiagram {
  const RoomDrawing(
    super.width,
    super.height,
    super.shapes, {
    required this.origin,
    required this.scale,
  });
  final Offset origin;
  final double scale;

  Offset toPx(Offset mm) => origin + mm * scale;
  Offset toMm(Offset px) => (px - origin) / scale;
}

abstract final class RoomColors {
  static const measure = Color(0xFFC026D3);
  static const wall = Color(0xFF94A3B8);
  static const zone = Color(0xFFF1F5F9);
  static const zoneLine = Color(0xFF94A3B8);
  static const intake = Color(0xFF0EA5E9);
  static const hot = Color(0xFFDC2626);
  static const dimension = Color(0xFF475569);

  static (Color, Color) of(RoomItemKind k) => switch (k) {
    RoomItemKind.compressor => (
      const Color(0xFFDCFCE7),
      const Color(0xFF15803D),
    ),
    RoomItemKind.tank => (const Color(0xFFDBEAFE), AirDiagramColors.main),
    RoomItemKind.dryer => (const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
    RoomItemKind.panel => (const Color(0xFFE2E8F0), const Color(0xFF475569)),
    RoomItemKind.afterCooler => (
      const Color(0xFFEDE9FE),
      const Color(0xFF6D28D9),
    ),
  };
}

class _RoomDrawing {
  _RoomDrawing(this.config, this.room, this.s);

  final AirConfig config;
  final RoomResult room;
  final AirStrings s;

  final _back = <DShape>[];
  final _front = <DShape>[];
  final _texts = <DShape>[];

  static const _m = 28.0;
  static const _titleH = 64.0;
  static const _wallMm = 200.0;

  /// Đủ rộng cho bảng thông tin 3 cột dưới mặt bằng.
  static const _minWidth = 1000.0;

  late double _s; // px / mm
  late Offset _o; // góc trong tường sau – trái (px)

  Offset _p(Offset mm) => _o + mm * _s;
  Offset _xy(double x, double y) => _p(Offset(x, y));
  Rect _r(Rect mm) => Rect.fromPoints(_p(mm.topLeft), _p(mm.bottomRight));

  RoomDrawing build() {
    final L = room.lengthMm;
    final W = room.widthMm;
    final t = _wallMm;
    _s = math
        .min(860 / (L + 2 * t), 560 / (W + 2 * t))
        .clamp(0.03, 0.2)
        .toDouble();
    final top = _m + _titleH + 64;
    _o = Offset(_m + 70 + t * _s, top + t * _s);
    final planRight = _o.dx + (L + t) * _s;
    final planBottom = _o.dy + (W + t) * _s;

    _walls(L, W);
    _zones();
    _hotAir();
    _pipes(L, W);
    _items();
    _filters();
    _dimensions(L, W);
    _measures();

    // Mặt bằng chiếm hết chiều ngang; bảng thông tin 3 cột nằm dưới (kể cả
    // chữ tràn ra ngoài tường như "Ra xưởng").
    final texts = _texts.whereType<DText>();
    final planTextRight = texts.fold(
      planRight,
      (m, t) => math.max(m, t.box.right),
    );
    final planTextBottom = texts.fold(
      planBottom,
      (m, t) => math.max(m, t.box.bottom),
    );
    final width = math.max(planTextRight + _m, _minWidth);
    final panelBottom = _infoPanel(_m, planTextBottom + 36, width - 2 * _m);
    final bottom = _legend(panelBottom + 20, width);
    _title(width);
    return RoomDrawing(
      width,
      bottom + _m,
      [..._back, ..._front, ..._texts],
      origin: _o,
      scale: _s,
    );
  }

  // ── Tường, cửa, cửa lấy gió ─────────────────────────────────────────────
  void _walls(double L, double W) {
    final t = _wallMm;
    _back.add(
      DRect(_r(Rect.fromLTRB(-t, -t, L + t, W + t)), fill: RoomColors.wall),
    );
    _back.add(
      DRect(_r(Rect.fromLTWH(0, 0, L, W)), fill: AirDiagramColors.white),
    );
    _text(
      s.roomBackWall,
      _xy(0, -t) + const Offset(0, -6),
      size: 11,
      color: RoomColors.dimension,
      anchor: DAnchor.start,
    );

    // Cửa ra vào: khoét tường + cánh cửa và cung mở vào trong.
    final door = room.door;
    final (hinge, closed, open) = switch (door.wall) {
      RoomWall.front => (
        Offset(door.start, W),
        Offset(door.start + door.width, W),
        Offset(door.start, W - door.width),
      ),
      RoomWall.left => (
        Offset(0, door.start),
        Offset(0, door.start + door.width),
        Offset(door.width, door.start),
      ),
      RoomWall.right || RoomWall.back => (
        Offset(L, door.start),
        Offset(L, door.start + door.width),
        Offset(L - door.width, door.start),
      ),
    };
    _back.add(
      DRect(
        _r(_wallBand(door.wall, door.start, door.width, L, W)),
        fill: AirDiagramColors.white,
      ),
    );
    final arc = <Offset>[
      for (var k = 0; k <= 16; k++)
        hinge + _rotate(closed - hinge, open - hinge, k / 16),
    ];
    _front.add(
      DPath(
        [for (final q in arc) _p(q)],
        stroke: RoomColors.dimension,
        strokeWidth: 1,
        dashed: true,
      ),
    );
    _front.add(
      DPath(
        [_p(hinge), _p(open)],
        stroke: RoomColors.dimension,
        strokeWidth: 2,
      ),
    );

    // Cửa lấy gió: dải xanh có gạch chéo trên tường, mũi tên vào phòng.
    final intake = room.intake;
    final band = _r(_wallBand(intake.wall, intake.start, intake.width, L, W));
    _front.add(
      DRect(
        band,
        fill: AirDiagramColors.tint(RoomColors.intake, 0.25),
        stroke: RoomColors.intake,
      ),
    );
    final horizontal = band.width > band.height;
    final step = 10.0;
    final count = ((horizontal ? band.width : band.height) / step).floor();
    for (var k = 1; k < count; k++) {
      final a = horizontal
          ? Offset(band.left + k * step, band.bottom)
          : Offset(band.left, band.top + k * step);
      final b = horizontal
          ? a + Offset(-band.height, -band.height)
          : a + Offset(band.width, -band.width);
      final clippedB = Offset(
        b.dx.clamp(band.left, band.right),
        b.dy.clamp(band.top, band.bottom),
      );
      _front.add(
        DPath([a, clippedB], stroke: RoomColors.intake, strokeWidth: 0.8),
      );
    }
    final inward = switch (intake.wall) {
      RoomWall.front => const Offset(0, -1),
      RoomWall.back => const Offset(0, 1),
      RoomWall.left => const Offset(1, 0),
      RoomWall.right => const Offset(-1, 0),
    };
    final c = band.center;
    final edge =
        c + Offset(inward.dx * band.width / 2, inward.dy * band.height / 2);
    _arrow(edge, edge + inward * 26, RoomColors.intake, width: 2);
  }

  /// Đoạn tường (mm) chứa một khoảng mở.
  Rect _wallBand(
    RoomWall wall,
    double start,
    double width,
    double L,
    double W,
  ) {
    final t = _wallMm;
    return switch (wall) {
      RoomWall.front => Rect.fromLTWH(start, W, width, t),
      RoomWall.back => Rect.fromLTWH(start, -t, width, t),
      RoomWall.left => Rect.fromLTWH(-t, start, t, width),
      RoomWall.right => Rect.fromLTWH(L, start, t, width),
    };
  }

  /// Quay vectơ [from] về phía [to] theo tỉ lệ [k] (cung 90°).
  Offset _rotate(Offset from, Offset to, double k) {
    final a0 = math.atan2(from.dy, from.dx);
    var a1 = math.atan2(to.dy, to.dx);
    var d = a1 - a0;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    a1 = a0 + d * k;
    final r = from.distance;
    return Offset(math.cos(a1) * r, math.sin(a1) * r);
  }

  // ── Thiết bị ────────────────────────────────────────────────────────────
  void _zones() {
    for (final i in room.items) {
      _back.add(
        DRect(
          _r(i.zone),
          fill: RoomColors.zone,
          stroke: RoomColors.zoneLine,
          strokeWidth: 0.8,
          dashed: true,
        ),
      );
    }
  }

  void _items() {
    for (var k = 0; k < room.items.length; k++) {
      final i = room.items[k];
      final (fill, stroke) = RoomColors.of(i.kind);
      final rect = _r(i.rect);
      if (i.isRound) {
        _front.add(
          DCircle(
            rect.center,
            rect.shortestSide / 2,
            fill: fill,
            stroke: stroke,
            strokeWidth: 1.6,
          ),
        );
      } else {
        _front.add(
          DRect(rect, radius: 2, fill: fill, stroke: stroke, strokeWidth: 1.6),
        );
      }
      // Số thứ tự (khớp bảng thiết bị) + model nếu đủ chỗ.
      final model = i.model;
      final inner = i.isRound ? rect.width * 0.7 : rect.width - 6;
      final showModel =
          model != null &&
          estimateTextWidth(model, 10) < inner &&
          rect.height > 30;
      _text(
        '${k + 1}',
        rect.center + Offset(0, showModel ? -2 : 5),
        size: 13,
        bold: true,
        color: stroke,
        anchor: DAnchor.middle,
      );
      if (showModel) {
        _text(
          model,
          rect.center + const Offset(0, 12),
          size: 10,
          color: AirDiagramColors.text,
          anchor: DAnchor.middle,
        );
      }
      _itemDimensions(i, rect);
    }
  }

  /// Kích thước thiết bị bên ngoài khối, như kích thước phòng: đường dưới
  /// khối = cạnh dọc tường, đường bên trái = cạnh sâu; bình tròn ghi Ø.
  void _itemDimensions(RoomItem i, Rect rect) {
    const gap = 9.0;
    const size = 10.0;
    final y = rect.bottom + gap;
    _dimLine(Offset(rect.left, y), Offset(rect.right, y));
    _text(
      i.isRound ? 'Ø ${s.n0(i.lengthMm)}' : s.n0(i.lengthMm),
      Offset(rect.center.dx, y + 13),
      size: size,
      color: RoomColors.dimension,
      anchor: DAnchor.middle,
    );
    if (i.isRound) return;
    final x = rect.left - gap;
    _dimLine(Offset(x, rect.top), Offset(x, rect.bottom));
    _text(
      s.n0(i.depthMm),
      Offset(x - 5, rect.center.dy + 4),
      size: size,
      color: RoomColors.dimension,
      anchor: DAnchor.end,
    );
  }

  /// Gió nóng: mũi tên đứt từ máy nén xuyên tường sau ra ngoài.
  void _hotAir() {
    for (final i in room.of(RoomItemKind.compressor)) {
      final from = _p(Offset(i.rect.center.dx, i.rect.top));
      final to = _p(Offset(i.rect.center.dx, -_wallMm)) + const Offset(0, -18);
      _front.add(
        DPath(
          [from, to],
          stroke: RoomColors.hot,
          strokeWidth: 1.6,
          dashed: true,
        ),
      );
      _arrowHead(to, const Offset(0, -1), RoomColors.hot);
    }
  }

  // ── Ống ─────────────────────────────────────────────────────────────────
  void _pipes(double L, double W) {
    for (final (a, b) in room.branches) {
      _front.add(
        DPath([_p(a), _p(b)], stroke: AirDiagramColors.main, strokeWidth: 2),
      );
    }
    if (room.mainPipe.length > 1) {
      _front.add(
        DPath(
          [for (final q in room.mainPipe) _p(q)],
          stroke: AirDiagramColors.main,
          strokeWidth: 3,
        ),
      );
    }
    final supply = room.supplyPipe;
    if (supply.length > 1 && (supply.last - supply.first).distance > 1) {
      // Kéo xuyên tường thêm một đoạn, mũi tên chỉ hướng ra xưởng.
      final last = supply.last;
      final prev = supply[supply.length - 2];
      final dir = (last - prev) / (last - prev).distance;
      final outside = last + dir * (_wallMm + 350);
      _front.add(
        DPath(
          [
            for (final q in [...supply, outside]) _p(q),
          ],
          stroke: AirDiagramColors.supply,
          strokeWidth: 3,
        ),
      );
      _arrowHead(_p(outside), dir, AirDiagramColors.supply);
      final label = '${s.roomOutlet} · ${room.pipeDn ?? ''}'.trim();
      final at = _p(outside) + dir * 8;
      _text(
        label,
        dir.dx.abs() > 0.5
            ? at + Offset(dir.dx > 0 ? 4 : -4, 4)
            : at + Offset(6, dir.dy > 0 ? 12 : -4),
        size: 11,
        bold: true,
        color: AirDiagramColors.supply,
        anchor: dir.dx < -0.5 ? DAnchor.end : DAnchor.start,
      );
    }
  }

  /// Lọc vẽ đúng kích thước thân lọc (tối thiểu 10 px), số L1, L2… to, đặt
  /// ngay dưới lọc.
  void _filters() {
    final (fw, fd, _) = room.filterSizeMm;
    final w = math.max(10.0, fw * _s);
    final h = math.max(10.0, fd * _s);
    for (final f in room.filters) {
      final c = _p(f.at);
      final rect = Rect.fromCenter(center: c, width: w, height: h);
      _front.add(
        DRect(
          rect,
          radius: 2,
          fill: AirDiagramColors.filterBowl,
          stroke: AirDiagramColors.filterHead,
          strokeWidth: 1.4,
        ),
      );
      _text(
        'L${f.number}',
        Offset(c.dx, rect.bottom + 16),
        size: 14,
        bold: true,
        color: AirDiagramColors.filterHead,
        anchor: DAnchor.middle,
      );
    }
  }

  // ── Kích thước ──────────────────────────────────────────────────────────
  void _dimensions(double L, double W) {
    final t = _wallMm * _s;
    // Chiều dài phía trên tường sau.
    final y = _o.dy - t - 26;
    final x0 = _o.dx;
    final x1 = _o.dx + L * _s;
    _dimLine(Offset(x0, y), Offset(x1, y));
    _text(
      s.n0(L),
      Offset((x0 + x1) / 2, y - 5),
      size: 12,
      bold: true,
      color: RoomColors.dimension,
      anchor: DAnchor.middle,
    );
    // Chiều rộng bên trái tường trái.
    final x = _o.dx - t - 26;
    final y0 = _o.dy;
    final y1 = _o.dy + W * _s;
    _dimLine(Offset(x, y0), Offset(x, y1));
    _text(
      s.n0(W),
      Offset(x - 6, (y0 + y1) / 2 + 4),
      size: 12,
      bold: true,
      color: RoomColors.dimension,
      anchor: DAnchor.end,
    );
  }

  /// Phép đo của người dùng: đường kích thước màu tím, vạch chặn vuông góc,
  /// nhãn khoảng cách (kèm ΔX × ΔY khi đo xiên) trên nền trắng.
  void _measures() {
    for (final m in config.room.measures) {
      final a = _xy(m.ax, m.ay);
      final b = _xy(m.bx, m.by);
      final d = b - a;
      if (d.distance < 1) continue;
      final u = d / d.distance;
      final n = Offset(-u.dy, u.dx);
      _front.add(DPath([a, b], stroke: RoomColors.measure, strokeWidth: 1.6));
      for (final q in [a, b]) {
        _front
          ..add(
            DPath(
              [q - n * 6, q + n * 6],
              stroke: RoomColors.measure,
              strokeWidth: 1.6,
            ),
          )
          ..add(DCircle(q, 2.5, fill: RoomColors.measure));
      }
      final label = s.roomMeasureLabel(m.bx - m.ax, m.by - m.ay);
      // Nhãn phía trên đường (hoặc bên trái khi đo dọc).
      final side = n.dy > 0 ? -n : n;
      final at = (a + b) / 2 + side * 12;
      final w = estimateTextWidth(label, 11, bold: true);
      _front.add(
        DRect(
          Rect.fromCenter(
            center: at + const Offset(0, -4),
            width: w + 8,
            height: 16,
          ),
          radius: 3,
          fill: AirDiagramColors.white,
          stroke: RoomColors.measure,
          strokeWidth: 0.8,
        ),
      );
      _text(
        label,
        at + const Offset(0, 0),
        size: 11,
        bold: true,
        color: RoomColors.measure,
        anchor: DAnchor.middle,
      );
    }
  }

  void _dimLine(Offset a, Offset b) {
    _front.add(DPath([a, b], stroke: RoomColors.dimension, strokeWidth: 1));
    final n = (b - a).dx.abs() > 0.5 ? const Offset(0, 5) : const Offset(5, 0);
    for (final q in [a, b]) {
      _front.add(
        DPath([q - n, q + n], stroke: RoomColors.dimension, strokeWidth: 1),
      );
    }
  }

  // ── Bảng bên phải ───────────────────────────────────────────────────────
  /// Bảng thông tin dưới mặt bằng, 3 cột: thiết bị | lọc + thông số khác |
  /// thông gió + cảnh báo. Trả về đáy bảng.
  double _infoPanel(double left, double top, double width) {
    const gap = 32.0;
    final cw = (width - 2 * gap) / 3;

    // Mỗi cột có con trỏ y riêng.
    // Tiêu đề mục: vạch xanh lá bên trái + gạch chân (như PDF máy tách màu).
    double heading(double x, double y, String text) {
      _front
        ..add(
          DRect(Rect.fromLTWH(x, y + 1, 4, 17), fill: AirDiagramColors.brand),
        )
        ..add(
          DPath([
            Offset(x, y + 22),
            Offset(x + cw, y + 22),
          ], stroke: AirDiagramColors.steel),
        );
      _text(text, Offset(x + 10, y + 14), size: 14, bold: true);
      return y + 40;
    }

    double lines(
      double x,
      double y,
      List<String> rows, {
      double size = 12,
      Color? color,
    }) {
      for (final row in rows) {
        for (final part in wrapText(row, cw, size)) {
          _text(
            part,
            Offset(x, y),
            size: size,
            color: color ?? AirDiagramColors.muted,
          );
          y += size + 5;
        }
      }
      return y;
    }

    // Cột 1: thiết bị.
    var x = left;
    var y = heading(x, top, s.roomEquipment);
    for (var k = 0; k < room.items.length; k++) {
      final i = room.items[k];
      final name = [s.roomKind(i.kind), ?i.model].join(' – ');
      final (_, stroke) = RoomColors.of(i.kind);
      _text(
        '${k + 1}',
        Offset(x + 8, y),
        size: 12,
        bold: true,
        color: stroke,
        anchor: DAnchor.middle,
      );
      for (final part in wrapText(name, cw - 24, 12, bold: true)) {
        _text(part, Offset(x + 22, y), size: 12, bold: true);
        y += 17;
      }
      final size =
          '${s.n0(i.lengthMm)} × ${s.n0(i.depthMm)} × ${s.n0(i.heightMm)} mm'
          '${i.sizeEstimated || i.heightEstimated ? ' *' : ''}';
      _text(size, Offset(x + 22, y), size: 11, color: AirDiagramColors.muted);
      y += 19;
    }
    if (room.items.any((i) => i.sizeEstimated || i.heightEstimated)) {
      _text(
        s.roomEstimatedMark,
        Offset(x, y),
        size: 10.5,
        color: AirDiagramColors.muted,
      );
      y += 18;
    }
    var bottom = y;

    // Cột 2: lọc trên ống chính + thông số khác.
    x = left + cw + gap;
    y = top;
    if (room.filters.isNotEmpty) {
      y = heading(x, y, s.roomFiltersTitle);
      y = lines(x, y, [
        s.roomFilterModel(room),
        for (final f in room.filters)
          'L${f.number}. ${s.roomFilterGrade(f.grade)}',
      ]);
      y += 10;
    }
    y = heading(x, y, s.roomOtherTitle);
    y = lines(x, y, s.roomOtherLines(room).split('\n'));
    bottom = math.max(bottom, y);

    // Cột 3: thông gió + cảnh báo.
    x = left + 2 * (cw + gap);
    y = heading(x, top, s.roomVentTitle);
    y = lines(x, y, s.roomVentLines(room).split('\n'));
    final warnings = [
      for (final w in room.warnings)
        if (w.code != RoomWarningCode.estimated) s.roomWarning(w),
    ];
    if (warnings.isNotEmpty) {
      y += 8;
      y = lines(x, y, warnings, size: 11.5, color: RoomColors.hot);
    }
    return math.max(bottom, y);
  }

  // ── Chú giải, tiêu đề ───────────────────────────────────────────────────
  double _legend(double top, double width) {
    final items = <(void Function(Offset), String)>[
      (
        (o) => _front.add(
          DPath(
            [o, o + const Offset(36, 0)],
            stroke: AirDiagramColors.main,
            strokeWidth: 3,
          ),
        ),
        s.legendMain,
      ),
      (
        (o) {
          _front.add(
            DPath(
              [o, o + const Offset(30, 0)],
              stroke: AirDiagramColors.supply,
              strokeWidth: 3,
            ),
          );
          _arrowHead(
            o + const Offset(36, 0),
            const Offset(1, 0),
            AirDiagramColors.supply,
          );
        },
        s.legendSupply,
      ),
      (
        (o) => _front.add(
          DRect(
            Rect.fromLTWH(o.dx, o.dy - 8, 36, 16),
            fill: RoomColors.zone,
            stroke: RoomColors.zoneLine,
            strokeWidth: 0.8,
            dashed: true,
          ),
        ),
        s.roomLegendZone,
      ),
      (
        (o) => _front.add(
          DRect(
            Rect.fromLTWH(o.dx, o.dy - 5, 36, 10),
            fill: AirDiagramColors.tint(RoomColors.intake, 0.25),
            stroke: RoomColors.intake,
          ),
        ),
        s.roomLegendIntake,
      ),
      (
        (o) {
          _front.add(
            DPath(
              [o, o + const Offset(30, 0)],
              stroke: RoomColors.hot,
              strokeWidth: 1.6,
              dashed: true,
            ),
          );
          _arrowHead(
            o + const Offset(36, 0),
            const Offset(1, 0),
            RoomColors.hot,
          );
        },
        s.roomLegendHot,
      ),
      (
        (o) => _front.add(
          DRect(
            Rect.fromCenter(
              center: o + const Offset(18, 0),
              width: 12,
              height: 12,
            ),
            radius: 2,
            fill: AirDiagramColors.filterBowl,
            stroke: AirDiagramColors.filterHead,
          ),
        ),
        s.legendFilter,
      ),
    ];
    var x = _m;
    var y = top + 12;
    for (final (draw, label) in items) {
      final w = 36 + 10 + estimateTextWidth(label, 12) + 30;
      if (x > _m && x + w > width - _m) {
        x = _m;
        y += 30;
      }
      draw(Offset(x, y));
      _text(
        label,
        Offset(x + 46, y + 4),
        size: 12,
        color: AirDiagramColors.muted,
      );
      x += w;
    }
    return y + 16;
  }

  void _title(double width) {
    // Tiêu đề không nền, căn giữa.
    final band = Rect.fromLTWH(_m, _m, width - 2 * _m, _titleH);
    final name = config.project.name.trim();
    _text(
      name.isEmpty ? s.roomDrawingTitle : '${s.roomDrawingTitle} – $name',
      Offset(band.center.dx, band.top + 28),
      size: 20,
      bold: true,
      color: AirDiagramColors.text,
      anchor: DAnchor.middle,
    );
    _text(
      '${s.roomCardSize}: ${s.roomSize(room)} · ${s.roomStyle(room.style)}',
      Offset(band.center.dx, band.top + 50),
      size: 13,
      color: AirDiagramColors.muted,
      anchor: DAnchor.middle,
    );
  }

  // ── Bút vẽ ──────────────────────────────────────────────────────────────
  void _text(
    String text,
    Offset baseline, {
    double size = 12,
    bool bold = false,
    Color color = AirDiagramColors.text,
    DAnchor anchor = DAnchor.start,
  }) => _texts.add(
    DText(text, baseline, size: size, bold: bold, color: color, anchor: anchor),
  );

  void _arrow(Offset from, Offset to, Color color, {double width = 1.6}) {
    _front.add(DPath([from, to], stroke: color, strokeWidth: width));
    _arrowHead(to, (to - from) / (to - from).distance, color);
  }

  /// Mũi tên tam giác, đỉnh tại [tip], hướng [dir] (vectơ đơn vị).
  void _arrowHead(Offset tip, Offset dir, Color color) {
    final n = Offset(-dir.dy, dir.dx);
    _front.add(
      DPath(
        [tip, tip - dir * 10 + n * 5, tip - dir * 10 - n * 5],
        fill: color,
        closed: true,
      ),
    );
  }
}
