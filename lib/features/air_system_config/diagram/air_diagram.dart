import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import '../engine/air_engine.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';

/// Sơ đồ lắp đặt dựng thành danh sách hình cơ bản. Màn hình (Canvas), SVG,
/// PNG và PDF đều vẽ lại từ cùng một [AirDiagram] nên luôn giống nhau.

sealed class DShape {
  const DShape();
}

class DRect extends DShape {
  const DRect(
    this.rect, {
    this.radius = 0,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.dashed = false,
  });
  final Rect rect;
  final double radius;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final bool dashed;
}

class DCircle extends DShape {
  const DCircle(
    this.center,
    this.radius, {
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });
  final Offset center;
  final double radius;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
}

class DPath extends DShape {
  const DPath(
    this.points, {
    this.stroke,
    this.strokeWidth = 1,
    this.fill,
    this.closed = false,
    this.dashed = false,
  });
  final List<Offset> points;
  final Color? stroke;
  final double strokeWidth;
  final Color? fill;
  final bool closed;
  final bool dashed;
}

enum DAnchor { start, middle, end }

/// Một dòng chữ; [baseline] là điểm neo trên đường chân chữ.
class DText extends DShape {
  const DText(
    this.text,
    this.baseline, {
    required this.size,
    this.color = AirDiagramColors.text,
    this.bold = false,
    this.anchor = DAnchor.start,
  });
  final String text;
  final Offset baseline;
  final double size;
  final Color color;
  final bool bold;
  final DAnchor anchor;

  /// Khung chữ ước lượng (dùng cho bố cục và kiểm tra chồng chữ).
  Rect get box {
    final w = estimateTextWidth(text, size, bold: bold);
    final left = switch (anchor) {
      DAnchor.start => baseline.dx,
      DAnchor.middle => baseline.dx - w / 2,
      DAnchor.end => baseline.dx - w,
    };
    return Rect.fromLTWH(left, baseline.dy - size * 0.95, w, size * 1.2);
  }
}

/// Ảnh thiết bị (asset PNG) vẽ khít vào [rect] (đã đúng tỉ lệ ảnh).
class DImage extends DShape {
  const DImage(this.asset, this.rect);
  final String asset;
  final Rect rect;
}

/// Ảnh thiết bị thật trên sơ đồ — `assets/images/air_diagram/`.
abstract final class AirDiagramAssets {
  static const _dir = 'assets/images/air_diagram';
  static const compressor = '$_dir/air_compressor.png';
  static const tank = '$_dir/air_tank.png';
  static const filter = '$_dir/air_filter.png';
  static const refrigeratedDryer = '$_dir/air_dryer_refrigerated.png';
  static const desiccantDryer = '$_dir/air_dryer_desiccant.png';
  static const all = [
    compressor,
    tank,
    filter,
    refrigeratedDryer,
    desiccantDryer,
  ];
}

class AirDiagram {
  const AirDiagram(this.width, this.height, this.shapes);
  final double width;
  final double height;
  final List<DShape> shapes;

  Iterable<DText> get texts => shapes.whereType<DText>();
}

abstract final class AirDiagramColors {
  static const main = Color(0xFF1F4E9D);

  /// Xanh lá thương hiệu DTC (dải tiêu đề, như file PDF máy tách màu).
  static const brand = Color(0xFF148147);
  static const desiccant = Color(0xFF2E9E4F);
  static const refrigerated = Color(0xFF39A0E5);
  static const none = Color(0xFF8A94A6);

  /// Đường tới thiết bị sử dụng (sau lọc cuối).
  static const supply = Color(0xFFE67E22);
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF475569);
  static const white = Color(0xFFFFFFFF);
  static const steel = Color(0xFFC9D0D9);
  static const steelDark = Color(0xFF8C96A3);
  static const machine = Color(0xFF2F5DA8);
  static const machineLight = Color(0xFFE6ECF5);
  static const filterHead = Color(0xFF1F3F8A);
  static const filterBowl = Color(0xFF3C6FD1);
  static const dark = Color(0xFF334155);

  static Color of(DryerKind kind) => switch (kind) {
    DryerKind.desiccant => desiccant,
    DryerKind.refrigerated => refrigerated,
    DryerKind.none => none,
  };

  /// Màu nhạt (pha trắng) cho nền ô line.
  static Color tint(Color c, double amount) => Color.fromARGB(
    255,
    (255 - (255 - (c.r * 255)) * amount).round(),
    (255 - (255 - (c.g * 255)) * amount).round(),
    (255 - (255 - (c.b * 255)) * amount).round(),
  );
}

/// Độ rộng chữ ước lượng (Roboto), hơi rộng tay để không chồng chữ.
double estimateTextWidth(String text, double size, {bool bold = false}) =>
    text.length * size * (bold ? 0.57 : 0.52);

/// Ngắt dòng theo từ cho vừa [maxWidth].
List<String> wrapText(
  String text,
  double maxWidth,
  double size, {
  bool bold = false,
}) {
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (current.isNotEmpty &&
        estimateTextWidth(candidate, size, bold: bold) > maxWidth) {
      lines.add(current);
      current = word;
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? [''] : lines;
}

/// Cắt chữ thêm "…" cho vừa [maxWidth].
String ellipsize(
  String text,
  double maxWidth,
  double size, {
  bool bold = false,
}) {
  if (estimateTextWidth(text, size, bold: bold) <= maxWidth) return text;
  var end = text.length;
  while (end > 1 &&
      estimateTextWidth('${text.substring(0, end)}…', size, bold: bold) >
          maxWidth) {
    end--;
  }
  return '${text.substring(0, end).trimRight()}…';
}

AirDiagram buildAirDiagram(AirConfig config, AirResult r, AirStrings s) =>
    _AirDiagramBuilder(config, r, s).build();

class _AirDiagramBuilder {
  _AirDiagramBuilder(this.config, this.r, this.s);

  final AirConfig config;
  final AirResult r;
  final AirStrings s;

  final _pipes = <DShape>[];
  final _icons = <DShape>[];
  final _texts = <DShape>[];

  static const _m = 28.0;
  static const _titleTop = 16.0;
  static const _titleH = 70.0;
  static const _pipeW = 4.0;
  static const _labelSize = 13.0;
  static const _labelStep = 18.0;

  /// Mọi khối ghi chú (tuyến chính, máy sấy, lọc) bắt đầu cùng một hàng:
  /// dưới ảnh cao nhất (bình chứa) và van xả dưới lọc.
  static const _labelDy = 106.0;

  /// Từ mép phải thiết bị cuối tuyến chính tới mép trái máy sấy.
  static const _manifoldGap = 32.0;

  static const _frameW = 150.0;
  static const _frameH = 150.0;
  static const _filterW = 21.0;
  static const _filterH = 74.0;

  /// Khoảng từ đỉnh ảnh lọc tới đầu nối ống (đầu lọc).
  static const _filterHead = 8.0;
  static const _filterStep = 36.0;
  static const _lineW = 220.0;
  static const _lineH = 50.0;
  static const _lineGap = 16.0;

  bool get _drain => config.pretreat.autoDrain;

  AirDiagram build() {
    final top = _titleTop + _titleH + 34;

    // ── Tuyến chính: chỉ đo kích thước trước, vẽ sau khi biết mainY ───────
    final nodes = _mainNodes();
    // Ô mỗi thiết bị vừa đủ cho ghi chú dài nhất (không quá [_MainNode.slot],
    // ghi chú dài thì xuống dòng), để các thiết bị đứng gần nhau. Ghi chú
    // của thiết bị cuối được tràn sang khoảng ống góp (tới mép máy sấy).
    for (final n in nodes) {
      final labelW = [
        for (var k = 0; k < n.label.length; k++)
          estimateTextWidth(
            n.label[k],
            k == 0 ? _labelSize + 1.5 : _labelSize,
            bold: k == 0,
          ),
      ].fold(0.0, math.max);
      // Cột chữ = ô − 12 (cách cột kế 12 px); thiết bị cuối được dùng hết ô
      // vì sau nó còn khoảng ống góp trước máy sấy.
      final spill = identical(n, nodes.last) ? 12.0 : 0.0;
      n.slot = (labelW + 14 - spill).clamp(
        n.iconW + n.minGap,
        math.max(n.slot, n.iconW + n.minGap),
      );
    }
    final mainEnd = _m + nodes.fold(0.0, (sum, n) => sum + n.slot) - 20;
    final manifoldX = mainEnd + 8;
    final groupX = mainEnd + _manifoldGap;
    final filtersX = groupX + _frameW + 24;
    final busX = filtersX + 190;
    final lineX = busX + 46;

    // ── Các nhóm xếp dọc bên phải ────────────────────────────────────────
    var rowTop = top;
    final pipeYs = <double>[];
    for (final g in r.groups) {
      final names = [
        for (final i in g.lineIndexes) AirEngine.lineName(r.lines, i),
      ];
      // Màu loại máy sấy cho khung máy sấy; ống trước lọc cuối theo tuyến
      // chính, sau lọc cuối theo đường tới thiết bị sử dụng.
      final color = AirDiagramColors.of(g.kind);
      const supply = AirDiagramColors.supply;
      final pipeY = rowTop + 78;
      pipeYs.add(pipeY);
      var bottom = rowTop + _frameH;

      // Khung máy sấy (nét đứt) hoặc nhãn "Không sấy".
      if (g.hasDryer) {
        final frame = Rect.fromLTWH(groupX, rowTop, _frameW, _frameH);
        _icons.add(
          DRect(
            frame,
            radius: 6,
            stroke: color,
            strokeWidth: 1.6,
            dashed: true,
          ),
        );
        _text(
          _dryerTitle(g),
          Offset(frame.center.dx, rowTop + 20),
          size: 14,
          bold: true,
          color: color,
          anchor: DAnchor.middle,
        );
        _pipe([
          Offset(groupX, pipeY),
          Offset(groupX + _frameW, pipeY),
        ], AirDiagramColors.main);
        // Ảnh thật giữ đúng tỉ lệ; nằm gọn giữa tiêu đề và đáy khung.
        final desiccant = g.kind == DryerKind.desiccant;
        final iconRect = Rect.fromCenter(
          center: Offset(frame.center.dx, pipeY + (desiccant ? 8 : 2)),
          width: desiccant ? 69 : 57,
          height: desiccant ? 120 : 100,
        );
        if (desiccant) {
          _desiccantDryer(iconRect);
        } else {
          _refrigeratedDryer(iconRect);
          if (_drain) _drainIcon(Offset(iconRect.center.dx, iconRect.bottom));
        }
      } else {
        _text(
          s.noDryer,
          Offset(groupX + 6, pipeY - 14),
          size: 14,
          bold: true,
          color: color,
        );
        _pipe([
          Offset(groupX, pipeY),
          Offset(groupX + _frameW, pipeY),
        ], AirDiagramColors.main);
        bottom = pipeY + 10;
      }
      // Cùng hàng với ghi chú tuyến chính (tuyến chính nằm ngang ống nhóm).
      final groupLabelTop = math.max(
        g.hasDryer ? rowTop + _frameH + 20 : pipeY + 30,
        pipeY + _labelDy,
      );
      bottom = math.max(
        bottom,
        _block(
          s.diagramGroup(g, names, r.dryerPicks[g.kind]),
          left: groupX,
          top: groupLabelTop,
          width: _frameW + 20,
          firstBold: true,
        ),
      );

      // Lọc sau máy sấy. Ống còn màu tuyến chính tới hết lọc cuối; sau lọc
      // cuối là đường tới thiết bị sử dụng.
      final supplyX = g.hasPostFilters
          ? filtersX + 18 + (g.postFilterCount - 1) * _filterStep + _filterW
          : groupX + _frameW;
      _pipe([
        Offset(groupX + _frameW, pipeY),
        Offset(supplyX, pipeY),
      ], AirDiagramColors.main);
      _pipe([Offset(supplyX, pipeY), Offset(busX, pipeY)], supply);
      if (g.hasPostFilters) {
        // Thứ tự: tách thô (gần máy sấy), tách tinh, than, vô trùng. Số đánh
        // tiếp sau lọc tuyến chính, khớp danh sách cấp lọc bên dưới.
        final start = _mainFilters.length + 1;
        for (var k = 0; k < g.postFilterCount; k++) {
          _numberedFilter(filtersX + 18 + k * _filterStep, pipeY, start + k);
        }
        bottom = math.max(
          bottom,
          _block(
            s.diagramPostFilters(g, start: start, drain: _drain),
            left: filtersX,
            top: pipeY + _labelDy,
            width: 175,
            size: 12.5,
            firstBold: true,
          ),
        );
      }

      // Thanh góp và các ô line.
      final n = g.lineIndexes.length;
      final blockH = n * _lineH + (n - 1) * _lineGap;
      final linesTop = math.max(rowTop, pipeY - blockH / 2);
      final centers = [
        for (var k = 0; k < n; k++)
          linesTop + k * (_lineH + _lineGap) + _lineH / 2,
      ];
      final busTop = math.min(pipeY, centers.first);
      final busBottom = math.max(pipeY, centers.last);
      if (busBottom - busTop > 0.5) {
        _pipe([Offset(busX, busTop), Offset(busX, busBottom)], supply);
      }
      for (var k = 0; k < n; k++) {
        _pipe(
          [Offset(busX, centers[k]), Offset(lineX, centers[k])],
          supply,
          arrow: true,
        );
        _lineBox(
          Rect.fromLTWH(lineX, centers[k] - _lineH / 2, _lineW, _lineH),
          g.lineIndexes[k],
          supply,
        );
      }
      bottom = math.max(bottom, linesTop + blockH);
      rowTop = bottom + 40;
    }
    final groupsBottom = r.groups.isEmpty ? top + 160 : rowTop - 40;

    // ── Vẽ tuyến chính ở giữa vùng các nhóm ──────────────────────────────
    final mainY = pipeYs.isEmpty
        ? top + 70
        : math.max(top + 70, (pipeYs.first + pipeYs.last) / 2);
    _pipe([
      Offset(_m + nodes.first.iconW, mainY),
      Offset(manifoldX, mainY),
    ], AirDiagramColors.main);
    var x = _m;
    var mainBottom = mainY;
    for (final node in nodes) {
      final cx = x + node.iconW / 2;
      final icon = Rect.fromCenter(
        center: Offset(cx, mainY),
        width: node.iconW,
        height: node.iconH,
      );
      if (node != nodes.first) {
        _arrowHead(Offset(icon.left - 2, mainY), AirDiagramColors.main);
      }
      node.draw(icon);
      mainBottom = math.max(
        mainBottom,
        _block(
          node.label,
          left: x,
          top: mainY + _labelDy,
          width: node.slot - (identical(node, nodes.last) ? 0 : 12),
          firstBold: true,
        ),
      );
      x += node.slot;
    }

    // Ống góp chia nhánh tới từng nhóm.
    if (pipeYs.isNotEmpty) {
      final yTop = math.min(mainY, pipeYs.first);
      final yBottom = math.max(mainY, pipeYs.last);
      if (yBottom - yTop > 0.5) {
        _pipe([
          Offset(manifoldX, yTop),
          Offset(manifoldX, yBottom),
        ], AirDiagramColors.main);
      }
      for (var k = 0; k < r.groups.length; k++) {
        _pipe(
          [Offset(manifoldX, pipeYs[k]), Offset(groupX, pipeYs[k])],
          AirDiagramColors.main,
          arrow: true,
        );
      }
    }

    // ── Chú giải ─────────────────────────────────────────────────────────
    final width = math.max(
      math.max(lineX + _lineW + _m, 960.0),
      _m * 2 + estimateTextWidth(_titleLine, 20, bold: true) + 40,
    );
    final contentBottom = math.max(groupsBottom, mainBottom);
    final legendBottom = _legend(contentBottom + 40, width);
    _title(width);

    return AirDiagram(width, legendBottom + _m, [
      ..._pipes,
      ..._icons,
      ..._texts,
    ]);
  }

  // ── Nút tuyến chính ─────────────────────────────────────────────────────
  List<_MainNode> _mainNodes() {
    final pre = config.pretreat;
    final compressorName = _name('compressor', () {
      final pick = r.compressor;
      return pick?.model?.modelCode ??
          pick?.manualName ??
          s.compressorTypeName(config.compressor.type);
    });
    final nodes = <_MainNode>[
      _MainNode(
        slot: 190,
        iconW: 130,
        iconH: 123,
        minGap: 60,
        label: s.diagramCompressor(config, r, compressorName),
        draw: (rect) {
          if (r.compressorQty > 1) _compressor(rect.translate(12, -12));
          _compressor(rect);
        },
      ),
    ];
    final tank = r.tank;
    if (tank != null) {
      nodes.add(
        _MainNode(
          slot: 130,
          iconW: 47,
          iconH: 130,
          label: s.diagramTank(
            tank,
            _name('tank', () => tank.spec?.model ?? ''),
          ),
          draw: (rect) {
            _tank(rect);
            if (_drain) _drainIcon(Offset(rect.center.dx, rect.bottom));
          },
        ),
      );
    }
    if (pre.afterCooler != AfterCoolerType.none) {
      nodes.add(
        _MainNode(
          slot: 130,
          iconW: 86,
          iconH: 70,
          label: [s.afterCoolerTitle, s.afterCooler(pre.afterCooler)],
          draw: (rect) {
            _afterCooler(rect);
            if (_drain) _drainIcon(Offset(rect.center.dx, rect.bottom));
          },
        ),
      );
    }
    // Tuyến chính: lọc tách nước + lọc sau bình (Nâng cao); đánh số từ 1.
    final filters = _mainFilters;
    if (filters.isNotEmpty) {
      nodes.add(
        _MainNode(
          slot: 150,
          iconW: filters.length * _filterStep - 15,
          iconH: _filterH,
          label: [
            s.diagramFilterTitle,
            for (var k = 0; k < filters.length; k++) '${k + 1}. ${filters[k]}',
            if (_drain) s.autoDrain,
          ],
          draw: (rect) {
            for (var k = 0; k < filters.length; k++) {
              _numberedFilter(
                rect.left + _filterW / 2 + k * _filterStep,
                rect.center.dy,
                k + 1,
              );
            }
          },
        ),
      );
    }
    return nodes;
  }

  /// Lọc trên tuyến chính theo thứ tự dòng khí.
  List<String> get _mainFilters {
    final pre = config.pretreat;
    final tankFilters = r.tank == null ? 0 : pre.tankFilters;
    return [
      if (pre.hasWaterSeparator) s.diagramWaterSeparator,
      if (tankFilters >= 1) s.diagramCoarse,
      if (tankFilters >= 2) s.diagramFine,
    ];
  }

  /// Lọc treo trên ống kèm số thứ tự trên đầu và van xả tự động bên dưới.
  void _numberedFilter(double cx, double pipeY, int number) {
    final rect = _filterAt(cx, pipeY);
    _filter(rect);
    _text(
      '$number',
      Offset(cx, pipeY - _filterHead - 6),
      size: 12,
      bold: true,
      color: AirDiagramColors.muted,
      anchor: DAnchor.middle,
    );
    if (_drain) _drainIcon(Offset(cx, rect.bottom));
  }

  String _name(String key, String Function() fallback) {
    final o = config.overrides[key]?.name?.trim();
    return o == null || o.isEmpty ? fallback() : o;
  }

  String _dryerTitle(AirGroup g) =>
      _name('dryer_${g.kind.name}', () => s.dryerTitle(g.kind));

  // ── Ô line ──────────────────────────────────────────────────────────────
  /// Ô line chỉ ghi tên; PDP và ISO 8573-1 xem ở bảng kết quả.
  void _lineBox(Rect box, int index, Color color) {
    _icons.add(
      DRect(
        box,
        radius: 8,
        fill: AirDiagramColors.tint(color, 0.14),
        stroke: color,
        strokeWidth: 1.4,
      ),
    );
    _text(
      ellipsize(
        AirEngine.lineName(r.lines, index),
        box.width - 28,
        16,
        bold: true,
      ),
      Offset(box.left + 14, box.center.dy + 6),
      size: 16,
      bold: true,
    );
  }

  // ── Tiêu đề, chú giải ───────────────────────────────────────────────────
  String get _titleLine {
    final name = config.project.name.trim();
    return name.isEmpty ? s.diagramTitle : '${s.diagramTitle} – $name';
  }

  void _title(double width) {
    // Tiêu đề không nền, căn giữa.
    final band = Rect.fromLTWH(_m, _titleTop, width - _m * 2, _titleH);
    _text(
      ellipsize(_titleLine, band.width, 20, bold: true),
      Offset(band.center.dx, band.top + 30),
      size: 20,
      bold: true,
      color: AirDiagramColors.text,
      anchor: DAnchor.middle,
    );
    _text(
      ellipsize(s.composition(config, r), band.width, 14),
      Offset(band.center.dx, band.top + 54),
      size: 14,
      color: AirDiagramColors.muted,
      anchor: DAnchor.middle,
    );
  }

  double _legend(double top, double width) {
    final items = <(void Function(Offset), String, double)>[
      (
        (o) =>
            _pipe([o, o.translate(40, 0)], AirDiagramColors.main, arrow: true),
        s.legendMain,
        48,
      ),
      (
        (o) => _pipe(
          [o, o.translate(40, 0)],
          AirDiagramColors.supply,
          arrow: true,
        ),
        s.legendSupply,
        48,
      ),
      (
        (o) => _filter(
          Rect.fromCenter(center: o.translate(10, 0), width: 10.2, height: 36),
        ),
        s.legendFilter,
        26,
      ),
      if (_drain) ((o) => _drainIcon(o.translate(10, -8)), s.legendDrain, 26),
    ];
    var x = _m;
    var y = top + 20;
    for (final (draw, label, iconW) in items) {
      final w = iconW + 10 + estimateTextWidth(label, 13) + 32;
      if (x > _m && x + w > width - _m) {
        x = _m;
        y += 46;
      }
      draw(Offset(x, y));
      _text(
        label,
        Offset(x + iconW + 10, y + 5),
        size: 13,
        color: AirDiagramColors.muted,
      );
      x += w;
    }
    return y + 24;
  }

  // ── Bút vẽ cơ bản ───────────────────────────────────────────────────────
  void _text(
    String text,
    Offset baseline, {
    double size = _labelSize,
    bool bold = false,
    Color color = AirDiagramColors.text,
    DAnchor anchor = DAnchor.start,
  }) => _texts.add(
    DText(text, baseline, size: size, bold: bold, color: color, anchor: anchor),
  );

  /// Khối chữ nhiều dòng, tự ngắt; trả về đáy khối.
  double _block(
    List<String> lines, {
    required double left,
    required double top,
    required double width,
    bool firstBold = false,
    double size = _labelSize,
  }) {
    var y = top;
    for (var k = 0; k < lines.length; k++) {
      final bold = firstBold && k == 0;
      final fontSize = bold ? size + 1.5 : size;
      for (final part in wrapText(lines[k], width, fontSize, bold: bold)) {
        _text(
          part,
          Offset(left, y),
          size: fontSize,
          bold: bold,
          color: bold ? AirDiagramColors.text : AirDiagramColors.muted,
        );
        y += _labelStep;
      }
    }
    return y - _labelStep + 6;
  }

  void _pipe(List<Offset> points, Color color, {bool arrow = false}) {
    _pipes.add(DPath(points, stroke: color, strokeWidth: _pipeW));
    if (arrow) _arrowHead(points.last, color);
  }

  /// Mũi tên hướng sang phải, đỉnh tại [tip].
  void _arrowHead(Offset tip, Color color) => _pipes.add(
    DPath(
      [tip, tip.translate(-14, -8), tip.translate(-14, 8)],
      fill: color,
      closed: true,
    ),
  );

  // ── Biểu tượng thiết bị ─────────────────────────────────────────────────
  void _image(String asset, Rect r) => _icons.add(DImage(asset, r));

  void _compressor(Rect r) => _image(AirDiagramAssets.compressor, r);

  void _tank(Rect r) => _image(AirDiagramAssets.tank, r);

  void _afterCooler(Rect r) {
    _icons.add(
      DRect(
        r,
        radius: 4,
        fill: AirDiagramColors.machineLight,
        stroke: AirDiagramColors.steelDark,
        strokeWidth: 1.4,
      ),
    );
    final fan = Offset(r.left + r.height / 2, r.center.dy);
    final radius = r.height / 2 - 8;
    _icons.add(
      DCircle(
        fan,
        radius,
        stroke: AirDiagramColors.steelDark,
        strokeWidth: 1.4,
      ),
    );
    for (var k = 0; k < 3; k++) {
      final a = k * 2 * math.pi / 3;
      _icons.add(
        DPath(
          [fan, fan + Offset(math.cos(a), math.sin(a)) * (radius - 2)],
          stroke: AirDiagramColors.machine,
          strokeWidth: 3,
        ),
      );
    }
    for (var x = fan.dx + radius + 8; x < r.right - 6; x += 6) {
      _icons.add(
        DPath(
          [Offset(x, r.top + 8), Offset(x, r.bottom - 8)],
          stroke: AirDiagramColors.steelDark,
          strokeWidth: 1.2,
        ),
      );
    }
  }

  /// Ảnh lọc (đã có cốc xả), [r] từ [_filterAt].
  void _filter(Rect r) => _image(AirDiagramAssets.filter, r);

  /// Lọc treo trên ống: đầu lọc ngang ống tại ([cx], [pipeY]).
  Rect _filterAt(double cx, double pipeY) =>
      Rect.fromLTWH(cx - _filterW / 2, pipeY - _filterHead, _filterW, _filterH);

  /// Van xả tự động treo dưới thiết bị, [top] là điểm nối.
  void _drainIcon(Offset top) {
    final c = top.translate(0, 12);
    _icons
      ..add(
        DPath(
          [top, top.translate(0, 6)],
          stroke: AirDiagramColors.dark,
          strokeWidth: 2,
        ),
      )
      ..add(
        DPath(
          [
            c.translate(-7, -5),
            c.translate(7, 5),
            c.translate(7, -5),
            c.translate(-7, 5),
          ],
          fill: AirDiagramColors.dark,
          closed: true,
        ),
      );
  }

  void _refrigeratedDryer(Rect r) =>
      _image(AirDiagramAssets.refrigeratedDryer, r);

  void _desiccantDryer(Rect r) => _image(AirDiagramAssets.desiccantDryer, r);
}

class _MainNode {
  _MainNode({
    required this.slot,
    required this.iconW,
    required this.iconH,
    required this.label,
    required this.draw,
    this.minGap = 30,
  });

  /// Độ rộng tối đa của ô; bố cục thu lại theo ghi chú.
  double slot;

  /// Khoảng ống tối thiểu từ mép phải ảnh tới thiết bị kế tiếp.
  final double minGap;
  final double iconW;
  final double iconH;
  final List<String> label;
  final void Function(Rect icon) draw;
}
