part of 'air_diagram.dart';

/// Sơ đồ tuỳ chỉnh kiểu bản vẽ hãng: thiết bị đứng chung một mặt nền, ống
/// chính chạy trên cao. Máy nén ra ống thấp vào hông bình; bình ra ống ở vai
/// bình lên ống cao; lọc treo trên ống cao, các lọc liền nhau đứng sát nhau
/// (chung một khối ghi chú); ống xuống đỉnh máy sấy và lên lại từ đỉnh máy
/// sấy. Máy trong một tầng xếp thành các hàng dưới nhau; giữa hai tầng: gộp
/// ống chung, nối riêng hoặc từng ống chọn tay ([CustomLayout.linksFor]).
AirDiagram buildCustomAirDiagram(
  AirConfig config,
  AirResult r,
  AirStrings s,
  CustomEquipment equipment,
) => _CustomDiagramBuilder(config, r, s, equipment).build();

/// Đầu nối ống: [vertical] = ra lên trên / vào từ trên xuống (đỉnh máy
/// sấy); không thì ra / vào theo phương ngang.
class _Port {
  const _Port(this.p, {this.vertical = false});
  final Offset p;
  final bool vertical;
}

class _Unit {
  _Unit(this.rect, this.inlet, this.outlet, this.high);
  final Rect rect;
  final _Port inlet;
  final _Port outlet;

  /// Cao độ ống chính của hàng.
  final double high;
}

class _CustomDiagramBuilder extends _AirDiagramBuilder {
  _CustomDiagramBuilder(super.config, super.r, super.s, this.eq);

  final CustomEquipment eq;

  /// Ống chính cách mặt nền.
  static const _highAbove = 150.0;

  /// Bước giữa các lọc liền nhau.
  static const _filterPitch = 46.0;

  CustomLayout get _layout => config.custom;

  /// Kích thước ảnh (rộng, cao) đứng trên nền; lọc treo trên ống.
  static (double, double) _size(CustomKind k) => switch (k) {
    CustomKind.compressor => (130, 123),
    CustomKind.tank => (67, 205),
    CustomKind.afterCooler => (86, 70),
    CustomKind.refrigeratedDryer => (57, 100),
    CustomKind.desiccantDryer => (69, 120),
    _ => (_AirDiagramBuilder._filterW, _AirDiagramBuilder._filterH),
  };

  /// Tên ngắn trên sơ đồ (lọc ghi cấp lọc micron như sơ đồ tự động).
  String _short(CustomKind k) => switch (k) {
    CustomKind.waterSeparator => s.diagramWaterSeparator,
    CustomKind.coarseFilter => s.diagramCoarse,
    CustomKind.fineFilter => s.diagramFine,
    CustomKind.ultraFineFilter => s.diagramUltraFine,
    CustomKind.carbonFilter => s.diagramCarbon,
    _ => eq.kindName(k),
  };

  /// Vị trí ảnh và đầu nối của một máy: [left] mép trái cột, [floor] mặt
  /// nền của hàng.
  _Unit _place(CustomKind k, double left, double floor) {
    final (w, h) = _size(k);
    final high = floor - _highAbove;
    if (k.isFilter) {
      final rect = _filterAt(left + w / 2, high);
      return _Unit(
        rect,
        _Port(Offset(rect.left, high)),
        _Port(Offset(rect.right, high)),
        high,
      );
    }
    final rect = Rect.fromLTWH(left, floor - h, w, h);
    return switch (k) {
      // Ra ống ở hông phải, khoảng giữa thân máy.
      CustomKind.compressor => _Unit(
        rect,
        _Port(Offset(rect.left, rect.top + h * 0.55)),
        _Port(Offset(rect.right, rect.top + h * 0.55)),
        high,
      ),
      // Vào ở hông thấp, ra ở vai bình ngang ống chính.
      CustomKind.tank => _Unit(
        rect,
        _Port(Offset(rect.left, rect.top + h * 0.68)),
        _Port(Offset(rect.right, high)),
        high,
      ),
      // Máy sấy: vào / ra ở đỉnh máy.
      CustomKind.refrigeratedDryer || CustomKind.desiccantDryer => _Unit(
        rect,
        _Port(Offset(rect.left + w * 0.25, rect.top), vertical: true),
        _Port(Offset(rect.right - w * 0.25, rect.top), vertical: true),
        high,
      ),
      _ => _Unit(
        rect,
        _Port(Offset(rect.left, rect.center.dy)),
        _Port(Offset(rect.right, rect.center.dy)),
        high,
      ),
    };
  }

  /// Đường ống vuông góc từ đầu ra [a] (hàng có ống chính [ha]) tới đầu vào
  /// [b] (ống chính [hb]), đoạn đứng chuyển hàng tại [xc].
  List<Offset> _route(_Port a, double ha, _Port b, double hb, double xc) {
    final pts = <Offset>[a.p];
    var y = a.p.dy;
    if (a.vertical) {
      y = ha;
      pts.add(Offset(a.p.dx, y));
    }
    final target = b.vertical ? hb : b.p.dy;
    if ((y - target).abs() > 0.5) {
      pts
        ..add(Offset(xc, y))
        ..add(Offset(xc, target));
    }
    if (b.vertical) pts.add(Offset(b.p.dx, target));
    pts.add(b.p);
    // Bỏ điểm trùng / thẳng hàng.
    final out = <Offset>[];
    for (final p in pts) {
      if (out.isNotEmpty && (out.last - p).distance < 0.5) continue;
      if (out.length >= 2) {
        final a0 = out[out.length - 2], a1 = out.last;
        final straight =
            ((a0.dx - a1.dx).abs() < 0.5 && (a1.dx - p.dx).abs() < 0.5) ||
            ((a0.dy - a1.dy).abs() < 0.5 && (a1.dy - p.dy).abs() < 0.5);
        if (straight) out.removeLast();
      }
      out.add(p);
    }
    return out;
  }

  /// Ống có mũi tên theo hướng đoạn cuối (ngang → sang phải, đứng → xuống).
  void _flow(List<Offset> pts, Color color, {required bool arrow}) {
    _pipes.add(
      DPath(pts, stroke: color, strokeWidth: _AirDiagramBuilder._pipeW),
    );
    if (!arrow || pts.length < 2) return;
    final tip = pts.last, prev = pts[pts.length - 2];
    if ((tip.dx - prev.dx).abs() > (tip.dy - prev.dy).abs()) {
      _arrowHead(tip, color);
    } else {
      _pipes.add(
        DPath(
          [tip, tip.translate(-8, -14), tip.translate(8, -14)],
          fill: color,
          closed: true,
        ),
      );
    }
  }

  @override
  AirDiagram build() {
    final stages = [
      for (final st in _layout.stages)
        if (st.qty > 0) st,
    ];
    final view = CustomLayout(stages: stages);
    CustomConnection conn(int k) => view.connection(k);

    // ── Hàng: máy thứ i của tầng n máy nằm giữa các hàng ──────────────────
    final rows = stages.fold(1, (m, st) => math.max(m, st.qty));
    final tallest = stages.fold(
      _highAbove + 24,
      (m, st) => math.max(m, _size(st.kind).$2),
    );
    final rowGap = tallest + 60;
    final top = _AirDiagramBuilder._titleTop + _AirDiagramBuilder._titleH + 34;
    final floor0 = top + tallest + 10;
    double floorOf(int i, int n) => floor0 + (i + (rows - n) / 2) * rowGap;
    final lastFloor = floor0 + (rows - 1) * rowGap;
    final labelTop = lastFloor + 34;

    // ── Nhóm cột: mỗi thiết bị một nhóm, các lọc liền nhau chung nhóm ─────
    final groups = <List<int>>[];
    for (var k = 0; k < stages.length; k++) {
      final filter = stages[k].kind.isFilter;
      if (filter &&
          groups.isNotEmpty &&
          stages[groups.last.last].kind.isFilter) {
        groups.last.add(k);
      } else {
        groups.add([k]);
      }
    }
    var filterNo = 0;
    final numbers = <int, int>{};
    for (var k = 0; k < stages.length; k++) {
      if (stages[k].kind.isFilter) numbers[k] = ++filterNo;
    }
    String models(CustomStage st) =>
        {for (final u in st.units) eq.modelOf(st, u) ?? '—'}.join(', ');
    List<String> labelOf(List<int> g) {
      final st = stages[g.first];
      if (!st.kind.isFilter) {
        return [
          [eq.kindName(st.kind), if (st.qty > 1) '×${st.qty}'].join(' '),
          for (var i = 0; i < st.qty; i++)
            () {
              final model = eq.modelOf(st, st.units[i]);
              final text = [
                model ?? '—',
                ?eq.detail(st.kind, model),
              ].join(' · ');
              return st.qty > 1 ? '${i + 1}) $text' : text;
            }(),
        ];
      }
      return [
        s.diagramFilterTitle,
        for (final k in g)
          [
            '${numbers[k]}. ${_short(stages[k].kind)}',
            if (stages[k].qty > 1) '×${stages[k].qty}',
            '(${models(stages[k])})',
          ].join(' '),
        if (_drain) s.autoDrain,
      ];
    }

    // Khoảng sau tầng k (ống nối sang tầng k + 1).
    double gapAfter(int k) {
      if (k + 1 >= stages.length) return 40;
      final n = stages[k + 1].qty;
      return switch (conn(k + 1)) {
        CustomConnection.paired => 40,
        CustomConnection.custom => 44 + 12.0 * n,
        CustomConnection.merged => stages[k].qty > 1 || n > 1 ? 60 : 40,
      };
    }

    const labelMax = 175.0;
    final xs = List<double>.filled(stages.length, 0);
    final labelLeft = <double>[];
    final labelWidth = <double>[];
    final labels = <List<String>>[];
    var x = _AirDiagramBuilder._m;
    for (final g in groups) {
      final lines = labelOf(g);
      final textW =
          [
                for (var j = 0; j < lines.length; j++)
                  estimateTextWidth(
                    lines[j],
                    j == 0 ? 14.0 : 12.5,
                    bold: j == 0,
                  ),
              ]
              .fold(0.0, math.max)
              .clamp(
                0.0,
                // Ghi chú lọc hẹp hơn (xuống dòng) để các cụm đứng gần nhau.
                stages[g.first].kind.isFilter ? 125.0 : labelMax,
              );
      final start = x;
      for (final k in g) {
        xs[k] = x;
        final (w, _) = _size(stages[k].kind);
        final last = k == g.last;
        x += stages[k].kind.isFilter
            ? (last ? w + gapAfter(k) : _filterPitch)
            : w + gapAfter(k);
      }
      // Nhóm đủ rộng cho ghi chú (chữ xuống dòng khi quá [labelMax]).
      final need = textW + 16;
      if (x - start < need) x = start + need;
      labels.add(lines);
      labelLeft.add(start);
      labelWidth.add(x - start - 14);
    }

    final lastFilter = stages.lastIndexWhere((st) => st.kind.isFilter);
    Color colorAfter(int k) => lastFilter >= 0 && k >= lastFilter
        ? AirDiagramColors.supply
        : AirDiagramColors.main;

    // ── Thiết bị ──────────────────────────────────────────────────────────
    final units = <List<_Unit>>[];
    for (var k = 0; k < stages.length; k++) {
      final st = stages[k];
      final placed = <_Unit>[];
      for (var i = 0; i < st.qty; i++) {
        final u = _place(st.kind, xs[k], floorOf(i, st.qty));
        placed.add(u);
        if (st.kind.isFilter) {
          // Ống chính chạy qua đầu lọc.
          _pipe([u.inlet.p, u.outlet.p], colorAfter(k));
        }
        _drawUnit(st.kind, u.rect, u.high);
        final no = numbers[k];
        if (no != null) {
          _text(
            '$no',
            Offset(
              u.rect.center.dx,
              u.high - _AirDiagramBuilder._filterHead - 6,
            ),
            size: 12,
            bold: true,
            color: AirDiagramColors.muted,
            anchor: DAnchor.middle,
          );
        } else if (st.qty > 1) {
          _text(
            '${i + 1}',
            Offset(u.rect.left - 4, u.rect.top + 12),
            size: 12,
            bold: true,
            color: AirDiagramColors.muted,
            anchor: DAnchor.end,
          );
        }
        if (_drain && st.kind.drains) {
          _drainIcon(Offset(u.rect.center.dx, u.rect.bottom));
        }
      }
      units.add(placed);
    }

    // ── Ống nối giữa các tầng ─────────────────────────────────────────────
    for (var k = 1; k < stages.length; k++) {
      final color = colorAfter(k - 1);
      final arrow = !stages[k].kind.isFilter;
      final from = units[k - 1], to = units[k];
      final x0 = from.first.outlet.p.dx;
      final x1 = to.first.inlet.p.dx;
      final mode = conn(k);
      for (final (i, j) in view.linksFor(k)) {
        final a = from[i], b = to[j];
        // Đoạn đứng: giữa khoảng (gộp chung dùng chung một ống góp); tuỳ
        // chỉnh: mỗi máy đích một cột riêng; vào đỉnh máy sấy: ngay trên.
        final xc = mode == CustomConnection.custom
            ? x0 + 8 + (x1 - x0 - 24) * (j + 1) / (to.length + 1)
            : x0 + (x1 - x0) / 2;
        _flow(
          _route(a.outlet, a.high, b.inlet, b.high, xc),
          color,
          arrow: arrow,
        );
      }
    }

    // ── Thanh góp tới các line sử dụng ────────────────────────────────────
    const supply = AirDiagramColors.supply;
    final lastUnits = units.isEmpty ? <_Unit>[] : units.last;
    final lastRight = lastUnits.isEmpty
        ? _AirDiagramBuilder._m
        : lastUnits.map((u) => u.rect.right).reduce(math.max);
    final busX = lastRight + 40;
    final lineX = busX + 46;
    final outYs = <double>[];
    for (final u in lastUnits) {
      final pts = <Offset>[u.outlet.p];
      if (u.outlet.vertical) pts.add(Offset(u.outlet.p.dx, u.high));
      final y = pts.last.dy;
      pts.add(Offset(busX, y));
      _pipe(pts, supply);
      outYs.add(y);
    }
    final n = config.lines.length;
    final blockH =
        n * _AirDiagramBuilder._lineH + (n - 1) * _AirDiagramBuilder._lineGap;
    final midY = outYs.isEmpty
        ? floor0 - _highAbove
        : (outYs.reduce(math.min) + outYs.reduce(math.max)) / 2;
    final linesTop = midY - blockH / 2;
    final centers = [
      for (var k = 0; k < n; k++)
        linesTop +
            k * (_AirDiagramBuilder._lineH + _AirDiagramBuilder._lineGap) +
            _AirDiagramBuilder._lineH / 2,
    ];
    final busYs = [...centers, ...outYs];
    if (busYs.isNotEmpty) {
      final y0 = busYs.reduce(math.min), y1 = busYs.reduce(math.max);
      if (y1 - y0 > 0.5) _pipe([Offset(busX, y0), Offset(busX, y1)], supply);
    }
    for (var k = 0; k < n; k++) {
      _pipe(
        [Offset(busX, centers[k]), Offset(lineX, centers[k])],
        supply,
        arrow: true,
      );
      _lineBox(
        Rect.fromLTWH(
          lineX,
          centers[k] - _AirDiagramBuilder._lineH / 2,
          _AirDiagramBuilder._lineW,
          _AirDiagramBuilder._lineH,
        ),
        k,
        supply,
      );
    }

    // ── Ghi chú dưới mặt nền ──────────────────────────────────────────────
    var contentBottom = labelTop;
    for (var gi = 0; gi < groups.length; gi++) {
      final last = gi == groups.length - 1;
      contentBottom = math.max(
        contentBottom,
        _block(
          labels[gi],
          left: labelLeft[gi],
          top: labelTop,
          // Nhóm cuối: tràn tới thanh góp.
          width: last ? labelMax : labelWidth[gi],
          size: 12.5,
          firstBold: true,
        ),
      );
    }
    if (n > 0) contentBottom = math.max(contentBottom, linesTop + blockH);

    final width = math.max(
      math.max(
        lineX + _AirDiagramBuilder._lineW + _AirDiagramBuilder._m,
        960.0,
      ),
      _AirDiagramBuilder._m * 2 +
          estimateTextWidth(_titleLine, 20, bold: true) +
          40,
    );
    final legendBottom = _legend(contentBottom + 40, width);
    _customTitle(width, stages);
    return AirDiagram(width, legendBottom + _AirDiagramBuilder._m, [
      ..._pipes,
      ..._icons,
      ..._texts,
    ]);
  }

  void _drawUnit(CustomKind k, Rect rect, double high) {
    switch (k) {
      case CustomKind.compressor:
        _compressor(rect);
      case CustomKind.tank:
        _tank(rect);
      case CustomKind.afterCooler:
        _afterCooler(rect);
      case CustomKind.refrigeratedDryer:
        _refrigeratedDryer(rect);
      case CustomKind.desiccantDryer:
        _desiccantDryer(rect);
      case CustomKind.waterSeparator ||
          CustomKind.coarseFilter ||
          CustomKind.fineFilter ||
          CustomKind.ultraFineFilter ||
          CustomKind.carbonFilter:
        _filter(rect);
    }
  }

  /// Tiêu đề + thành phần theo sơ đồ tuỳ chỉnh (vd 2 máy nén + 2 bình chứa).
  void _customTitle(double width, List<CustomStage> stages) {
    const m = _AirDiagramBuilder._m;
    final band = Rect.fromLTWH(
      m,
      _AirDiagramBuilder._titleTop,
      width - m * 2,
      _AirDiagramBuilder._titleH,
    );
    _text(
      ellipsize(_titleLine, band.width, 20, bold: true),
      Offset(band.center.dx, band.top + 30),
      size: 20,
      bold: true,
      color: AirDiagramColors.text,
      anchor: DAnchor.middle,
    );
    final counts = <CustomKind, int>{};
    for (final st in stages) {
      if (st.kind.isFilter) continue;
      counts.update(st.kind, (v) => v + st.qty, ifAbsent: () => st.qty);
    }
    final composition = [
      for (final e in counts.entries)
        '${e.value} ${eq.kindName(e.key).toLowerCase()}',
    ].join(' + ');
    _text(
      ellipsize(composition, band.width, 14),
      Offset(band.center.dx, band.top + 54),
      size: 14,
      color: AirDiagramColors.muted,
      anchor: DAnchor.middle,
    );
  }
}
