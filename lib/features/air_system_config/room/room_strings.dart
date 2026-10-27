import 'dart:math' as math;

import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import 'room_engine.dart';

/// Chữ của tab "Phòng lắp đặt" (màn hình, bản vẽ, file xuất), VI/EN.
extension RoomStrings on AirStrings {
  String _r(String vi, String en) => isEn ? en : vi;

  String get tabRoom => _r('Phòng lắp đặt', 'Room layout');
  String get roomMenuTitle =>
      _r('Tính toán phòng lắp đặt', 'Compressor room layout');
  String get roomDrawingTitle =>
      _r('Mặt bằng phòng lắp đặt', 'Compressor Room Layout');

  /// Mét, 1 chữ số thập phân: 10,5 m.
  String m(double mm) => '${n1(mm / 1000)} m';
  String mm(double v) => '${n0(v)} mm';
  String roomSize(RoomResult r) =>
      '${n1(r.lengthMm / 1000)} × ${n1(r.widthMm / 1000)} × '
      '${n1(r.heightMm / 1000)} m';

  // ── Nhập liệu ───────────────────────────────────────────────────────────
  String get roomInputTitle =>
      _r('Phòng thực tế (tuỳ chọn)', 'Actual room (optional)');
  String get roomInputHint => _r(
    'Để trống: app tính phòng tối thiểu. Nhập dài × rộng: app kiểm tra thiết bị có lọt không.',
    'Leave empty for the minimum room. Enter length × width to check the fit.',
  );
  String get roomLength => _r('Dài (m)', 'Length (m)');
  String get roomWidth => _r('Rộng (m)', 'Width (m)');
  String get roomHeight => _r('Cao (m)', 'Height (m)');
  String get roomStyleLabel => _r('Cách xếp thiết bị', 'Arrangement');
  String roomStyle(RoomStyle s) => switch (s) {
    RoomStyle.option1 => _r('Phương án 1', 'Option 1'),
    RoomStyle.option2 => _r('Phương án 2', 'Option 2'),
    RoomStyle.option3 => _r('Phương án 3', 'Option 3'),
  };
  String roomStyleHint(RoomStyle s) => switch (s) {
    RoomStyle.option1 => _r(
      'Máy nén, máy sấy đặt dọc tường',
      'Compressor and dryer along the wall',
    ),
    RoomStyle.option2 => _r('Máy sấy xoay 90°', 'Dryer turned 90°'),
    RoomStyle.option3 => _r(
      'Máy nén và máy sấy xoay 90°',
      'Compressor and dryer turned 90°',
    ),
  };

  /// Tên ngắn trong hình minh hoạ phương án.
  String roomSketchLabel(RoomItemKind k) => switch (k) {
    RoomItemKind.compressor => _r('Máy nén', 'Compressor'),
    RoomItemKind.tank => _r('Bình tích', 'Receiver'),
    RoomItemKind.dryer => _r('Máy sấy', 'Dryer'),
    RoomItemKind.afterCooler => _r('After cooling', 'After cooler'),
    RoomItemKind.panel => _r('Tủ điện', 'Panel'),
  };
  String roomOptionSize(RoomOption o) =>
      '${n1(o.lengthMm / 1000)} × ${n1(o.widthMm / 1000)} m';
  String get roomFits => _r('Lọt phòng', 'Fits');
  String get roomNotFit => _r('Không lọt', 'Too big');
  String get roomDoorLabel => _r('Cửa ra vào', 'Door');
  String roomDoorWall(RoomDoorWall w) => switch (w) {
    RoomDoorWall.front => _r('Tường trước', 'Front wall'),
    RoomDoorWall.left => _r('Tường trái', 'Left wall'),
    RoomDoorWall.right => _r('Tường phải', 'Right wall'),
  };
  String roomWall(RoomWall w) => switch (w) {
    RoomWall.back => _r('tường sau', 'back wall'),
    RoomWall.front => _r('tường trước', 'front wall'),
    RoomWall.left => _r('tường trái', 'left wall'),
    RoomWall.right => _r('tường phải', 'right wall'),
  };

  // ── Kết quả ─────────────────────────────────────────────────────────────
  String get roomCardSize => _r('Kích thước phòng', 'Room size');
  String roomCardSizeSub(RoomResult r) => r.actual
      ? (r.fits
            ? _r(
                'Phòng thực tế · tối thiểu ${n1(r.minLengthMm / 1000)} × ${n1(r.minWidthMm / 1000)} m',
                'Actual room · minimum ${n1(r.minLengthMm / 1000)} × ${n1(r.minWidthMm / 1000)} m',
              )
            : _r(
                'Phòng thực tế không đủ — xem cảnh báo',
                'Actual room too small — see warnings',
              ))
      : _r(
          'Phòng tối thiểu · ${roomStyleHint(r.style).toLowerCase()}',
          'Minimum room · ${roomStyleHint(r.style).toLowerCase()}',
        );
  String get roomCardVent =>
      _r('Đề xuất thông gió phòng máy', 'Suggested ventilation');
  String roomVentValue(RoomResult r) =>
      r.ventilation.valid ? '${n0(r.ventilation.suggestedM3h)} m³/h' : '—';
  String roomVentSub(RoomResult r) {
    final v = r.ventilation;
    return _r(
      'ΔT ${n1(v.deltaT)} °C · cửa lấy gió ≥ ${n2(v.openingM2)} m²',
      'ΔT ${n1(v.deltaT)} °C · air inlet ≥ ${n2(v.openingM2)} m²',
    );
  }

  String get roomVentFormula => 'Qv = (1,06·N + 1,2·D) / (T2 − T1)';
  String get roomOutsideTemp =>
      _r('T1 – nhiệt độ ngoài phòng (°C)', 'T1 – outside temperature (°C)');
  String get roomInletTemp => _r(
    'T2 – nhiệt độ khí vào máy nén tối đa (°C)',
    'T2 – max compressor inlet temperature (°C)',
  );
  String get roomVentInputTitle =>
      _r('Thông gió phòng máy', 'Room ventilation');
  String get roomCardPipe => _r('Ống chính ra xưởng', 'Main pipe to plant');
  String roomPipeValue(RoomResult r) => r.pipeDn ?? '—';
  String roomPipeSub(RoomResult r) => _r(
    'Đường kính trong ≥ ${n1(r.pipeDiameterMm)} mm',
    'Inner diameter ≥ ${n1(r.pipeDiameterMm)} mm',
  );
  String get roomCardDoor => _r('Cửa ra vào', 'Door');
  String roomDoorValue(RoomResult r) => '≥ ${m(r.door.width)}';
  String roomDoorSub(RoomResult r) =>
      _r('Đặt ở ${roomWall(r.door.wall)}', 'On the ${roomWall(r.door.wall)}');

  /// "Phương án 2, 3 lọt phòng này. " khi có phương án khác lọt.
  String _fitting(Map<String, Object?> p, bool vi) {
    final styles = (p['fitting'] as List?)?.cast<RoomStyle>() ?? const [];
    if (styles.isEmpty) return '';
    final names = styles.map((s) => roomStyle(s)).join(', ');
    return vi ? '$names lọt phòng này. ' : '$names fit this room. ';
  }

  String roomWarning(RoomWarning w) {
    final p = w.params;
    return switch (w.code) {
      RoomWarningCode.tooSmall => _r(
        'Phòng thực tế không đủ chỗ cho ${roomStyle(p['style'] as RoomStyle).toLowerCase()}: cần tối thiểu ${m(p['needL'] as double)} × ${m(p['needW'] as double)} (kể cả khoảng bảo trì). ${_fitting(p, true)}Có thể kéo, xoay thiết bị trong màn chỉnh sửa cho vừa phòng.',
        'The actual room is too small for ${roomStyle(p['style'] as RoomStyle).toLowerCase()}: at least ${m(p['needL'] as double)} × ${m(p['needW'] as double)} is needed (incl. service space). ${_fitting(p, false)}Move or rotate units in the layout editor to fit.',
      ),
      RoomWarningCode.tooLow => _r(
        'Phòng thấp hơn chiều cao cần ${m(p['needH'] as double)} (thiết bị cao nhất + 1 m).',
        'The room is lower than the required ${m(p['needH'] as double)} (tallest unit + 1 m).',
      ),
      RoomWarningCode.estimated => _r(
        'Kích thước ước tính (chưa có dữ liệu): ${[for (final k in p['kinds'] as List) _estimatedName(k as String)].join(', ')}.',
        'Estimated sizes (no data yet): ${[for (final k in p['kinds'] as List) _estimatedName(k as String)].join(', ')}.',
      ),
      RoomWarningCode.ventTemps => _r(
        'T2 (${n1(p['t2'] as double)} °C) phải lớn hơn T1 (${n1(p['t1'] as double)} °C) mới tính được thông gió.',
        'T2 (${n1(p['t2'] as double)} °C) must be higher than T1 (${n1(p['t1'] as double)} °C) to size ventilation.',
      ),
      RoomWarningCode.outside => _r(
        'Thiết bị số ${(p['items'] as List).join(', ')} nằm ngoài phòng — kéo, xoay thiết bị hoặc chọn phương án khác.',
        'Units ${(p['items'] as List).join(', ')} are outside the room — move or rotate them, or pick another option.',
      ),
      RoomWarningCode.clash => _r(
        'Thiết bị số ${(p['items'] as List).join(', ')} chồng lên nhau hoặc lấn vùng bảo trì sau khi di chuyển.',
        'Units ${(p['items'] as List).join(', ')} overlap or block service space after moving.',
      ),
      RoomWarningCode.doorMoved => _r(
        'Cửa ra vào vướng thiết bị, đã chuyển sang ${roomWall(p['wall'] as RoomWall)}.',
        'The door was blocked by equipment and moved to the ${roomWall(p['wall'] as RoomWall)}.',
      ),
    };
  }

  // ── Bản vẽ ──────────────────────────────────────────────────────────────
  /// Tên trong cảnh báo kích thước ước tính: loại thiết bị hoặc `filter`.
  String _estimatedName(String kind) => kind == 'filter'
      ? _r('lọc trên ống chính', 'in-line filters')
      : roomKind(RoomItemKind.values.byName(kind));

  String roomKind(RoomItemKind k) => switch (k) {
    RoomItemKind.panel => _r('Tủ điện', 'Electrical panel'),
    RoomItemKind.compressor => _r('Máy nén khí', 'Air compressor'),
    RoomItemKind.afterCooler => _r('After cooling', 'After cooler'),
    RoomItemKind.tank => _r('Bình chứa khí', 'Air receiver'),
    RoomItemKind.dryer => _r('Máy sấy khí', 'Air dryer'),
  };
  String roomFilterGrade(RoomFilterGrade g) => switch (g) {
    RoomFilterGrade.water => diagramWaterSeparator,
    RoomFilterGrade.coarse => diagramCoarse,
    RoomFilterGrade.fine => diagramFine,
    RoomFilterGrade.carbon => _r('Than hoạt tính', 'Activated carbon'),
    RoomFilterGrade.sterile => _r('Vô trùng', 'Sterile'),
  };

  /// "Model 013 · 160 × 160 × 500 mm *" — model lọc đường ống và kích thước
  /// thân lọc (D × R × C).
  String roomFilterModel(RoomResult r) {
    final (l, w, h) = r.filterSizeMm;
    final model = r.filterModel == null ? '' : 'Model ${r.filterModel} · ';
    return '$model${n0(l)} × ${n0(w)} × ${n0(h)} mm'
        '${r.filterEstimated ? ' *' : ''}';
  }

  String get roomEquipment => _r('Thiết bị', 'Equipment');
  String get roomSizeCol => _r('D × R × C (mm)', 'L × W × H (mm)');
  String get roomEstimatedMark => _r('* ước tính', '* estimated');
  String get roomFiltersTitle => _r('Lọc trên ống chính', 'In-line filters');
  String get roomVentTitle =>
      _r('Đề xuất thông gió phòng máy', 'Suggested room ventilation');

  /// Phần thông gió trên bản vẽ: chỉ kết quả (không hiện công thức), m³/h
  /// quy đổi từ m³/s đã làm tròn.
  String roomVentLines(RoomResult r) {
    final v = r.ventilation;
    final flow = v.valid ? '${n0(v.suggestedM3h)} m³/h' : '—';
    return _r(
      'Lưu lượng gió: $flow\nCửa lấy gió ≥ ${n2(v.openingM2)} m² (gió 2,5 m/s)',
      'Airflow: $flow\nAir inlet ≥ ${n2(v.openingM2)} m² (2.5 m/s)',
    );
  }

  String get roomOtherTitle => _r('Thông số khác', 'Other');
  String roomOtherLines(RoomResult r) => _r(
    'Chiều cao phòng ≥ ${m(r.minHeightMm)}\nCửa ra vào ≥ ${m(r.door.width)} (${roomWall(r.door.wall)})\nỐng chính ra xưởng: ${r.pipeDn ?? '—'}',
    'Room height ≥ ${m(r.minHeightMm)}\nDoor ≥ ${m(r.door.width)} (${roomWall(r.door.wall)})\nMain pipe to plant: ${r.pipeDn ?? '—'}',
  );
  String get roomLegendZone => _r('Vùng bảo trì', 'Service space');
  String get roomLegendIntake => _r('Cửa lấy gió', 'Air inlet');
  String get roomLegendHot => _r('Gió nóng ra ngoài', 'Hot air out');
  String get roomLegendDoor => _r('Cửa ra vào', 'Door');
  String get roomOutlet => _r('Ra xưởng', 'To plant');
  String get roomBackWall => _r('Tường sau', 'Back wall');
  // ── Chỉnh sửa mặt bằng (toàn màn hình) ──────────────────────────────────
  String get roomEditTooltip => _r(
    'Phóng to · đo kích thước · di chuyển thiết bị',
    'Zoom · measure · move units',
  );
  String get roomModeView => _r('Xem', 'View');
  String get roomModeMeasure => _r('Đo kích thước', 'Measure');
  String get roomModeMove => _r('Di chuyển', 'Move');
  String get roomHintView => _r(
    'Kéo / chụm hai ngón để xem, phóng to.',
    'Drag / pinch to pan and zoom.',
  );
  String get roomHintMeasure => _r(
    'Chạm chọn điểm 1 (tự bắt vào góc, cạnh, tâm thiết bị, góc phòng).',
    'Tap point 1 (snaps to unit corners, edges, centres, room corners).',
  );
  String get roomHintMeasureSecond => _r(
    'Chạm chọn điểm 2. Chọn nhầm thì kéo điểm 1 tới chỗ đúng.',
    'Tap point 2. Wrong spot? Drag point 1 to fix it.',
  );
  String get roomHintMeasureDone => _r(
    'Đã đủ 2 điểm. Kéo điểm 1 / 2 để chỉnh, bấm Đo lại để chọn lại.',
    'Both points set. Drag point 1 / 2 to adjust, press Measure again to restart.',
  );
  String get roomHintMove => _r(
    'Chạm chọn thiết bị, kéo tới vị trí mới (bước 50 mm), bấm Xoay 90° để xoay.',
    'Tap a unit to select it, drag to move (50 mm steps), press Rotate 90° to turn it.',
  );
  String get roomRotate => _r('Xoay 90°', 'Rotate 90°');
  String get roomSizeMenu => _r('Kích thước phòng…', 'Room size…');
  String get roomVentMenu =>
      _r('Nhiệt độ thông gió (T1, T2)…', 'Ventilation temperatures (T1, T2)…');
  String get roomSizeTitle =>
      _r('Kích thước phòng có sẵn', 'Existing room size');
  String get roomSizeClear => _r('Tự tính', 'Auto');
  String get cancel => _r('Huỷ', 'Cancel');
  String get apply => _r('Áp dụng', 'Apply');
  String get roomRemeasure => _r('Đo lại', 'Measure again');
  String get roomResetPositions =>
      _r('Đặt lại vị trí tự động', 'Reset to auto layout');
  String roomMeasureLabel(double dx, double dy) {
    final d = math.sqrt(dx * dx + dy * dy);
    if (dx.abs() < 1 || dy.abs() < 1) return n0(d);
    return '${n0(d)} (${n0(dx.abs())} × ${n0(dy.abs())})';
  }

  String get exportRoomPng => _r('Ảnh mặt bằng PNG', 'Layout PNG');
  String get exportRoomPdf => _r('Mặt bằng PDF (A3)', 'Layout PDF (A3)');
}
