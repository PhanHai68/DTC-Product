/// Khoảng trống bảo trì quanh một thiết bị (mm): trước (mặt thao tác), hai
/// bên, sau (phía tường).
class RoomClearance {
  const RoomClearance({
    required this.front,
    required this.side,
    required this.rear,
  });
  final double front;
  final double side;
  final double rear;

  factory RoomClearance.fromJson(Map<String, dynamic> j) => RoomClearance(
    front: (j['front'] as num).toDouble(),
    side: (j['side'] as num).toDouble(),
    rear: (j['rear'] as num).toDouble(),
  );
}

/// Hằng số tính phòng lắp đặt — `air_compressor/room_layout_constants.json`.
/// Sửa file JSON là đổi được, không cần sửa code.
class RoomConstants {
  const RoomConstants({
    required this.clearances,
    required this.aisleMm,
    required this.wallGapMm,
    required this.roundToMm,
    required this.headroomMm,
    required this.minRoomHeightMm,
    required this.filterPitchMm,
    required this.filterSizeMm,
    required this.standardSizesMm,
    required this.tankHeadFactor,
    required this.tankLegsMm,
    required this.doorMinWidthMm,
    required this.doorMarginMm,
    required this.doorHeightMm,
    required this.compressorFactor,
    required this.dryerFactor,
    required this.outsideTempC,
    required this.inletMaxTempC,
    required this.openingVelocity,
    required this.pipeLengthM,
    required this.pipeDropBar,
  });

  /// Theo loại: `compressor`, `dryer`, `tank`, `afterCooler`, `panel`,
  /// `separator`.
  final Map<String, RoomClearance> clearances;

  /// Lối đi chính trước dãy thiết bị.
  final double aisleMm;

  /// Khoảng cách tối thiểu từ thiết bị tới tường (đầu/cuối dãy).
  final double wallGapMm;

  /// Kích thước phòng làm tròn lên bội số này.
  final double roundToMm;

  /// Khoảng trống trên thiết bị cao nhất.
  final double headroomMm;
  final double minRoomHeightMm;

  /// Bước lọc treo trên ống và cạnh khối vẽ một lọc.
  final double filterPitchMm;
  final double filterSizeMm;

  /// Kích thước chuẩn (dài, rộng, cao) cho thiết bị chưa có dữ liệu.
  final Map<String, (double, double, double)> standardSizesMm;

  /// Ước tính chiều cao bình đứng: thân trụ + [tankHeadFactor] × đường kính
  /// (hai chỏm) + chân đế [tankLegsMm].
  final double tankHeadFactor;
  final double tankLegsMm;

  final double doorMinWidthMm;
  final double doorMarginMm;
  final double doorHeightMm;

  /// Lưu lượng gió làm mát Qv (m³/s) = (k_N · N + k_D · D) / (T2 − T1):
  /// N công suất máy nén, D công suất máy sấy (kW).
  final double compressorFactor;
  final double dryerFactor;

  /// Mặc định T1 nhiệt độ ngoài phòng và T2 nhiệt độ khí vào máy nén tối đa
  /// (°C) — người dùng nhập tay được.
  final double outsideTempC;
  final double inletMaxTempC;

  /// Vận tốc gió qua cửa lấy gió (m/s).
  final double openingVelocity;

  /// Ống chính ra xưởng: chiều dài và độ sụt áp dùng để chọn cỡ.
  final double pipeLengthM;
  final double pipeDropBar;

  RoomClearance clearance(String kind) =>
      clearances[kind] ?? const RoomClearance(front: 800, side: 600, rear: 600);

  (double, double, double) standardSize(String kind) =>
      standardSizesMm[kind] ?? (1000, 700, 1200);

  factory RoomConstants.fromJson(Map<String, dynamic> j) {
    final door = (j['door'] as Map).cast<String, dynamic>();
    final vent = (j['ventilation'] as Map).cast<String, dynamic>();
    final pipe = (j['pipe'] as Map).cast<String, dynamic>();
    double n(Object? v) => (v as num).toDouble();
    return RoomConstants(
      clearances: {
        for (final e in (j['clearancesMm'] as Map).entries)
          e.key as String: RoomClearance.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
      aisleMm: n(j['aisleMm']),
      wallGapMm: n(j['wallGapMm']),
      roundToMm: n(j['roundToMm']),
      headroomMm: n(j['headroomMm']),
      minRoomHeightMm: n(j['minRoomHeightMm']),
      filterPitchMm: n(j['filterPitchMm']),
      filterSizeMm: n(j['filterSizeMm']),
      standardSizesMm: {
        for (final e in (j['standardSizesMm'] as Map).entries)
          e.key as String: (
            n((e.value as List)[0]),
            n((e.value as List)[1]),
            n((e.value as List)[2]),
          ),
      },
      tankHeadFactor: n(j['tankHeadFactor']),
      tankLegsMm: n(j['tankLegsMm']),
      doorMinWidthMm: n(door['minWidthMm']),
      doorMarginMm: n(door['marginMm']),
      doorHeightMm: n(door['heightMm']),
      compressorFactor: n(vent['compressorFactor']),
      dryerFactor: n(vent['dryerFactor']),
      outsideTempC: n(vent['outsideTempC']),
      inletMaxTempC: n(vent['inletMaxTempC']),
      openingVelocity: n(vent['openingVelocityMs']),
      pipeLengthM: n(pipe['lengthM']),
      pipeDropBar: n(pipe['dropBar']),
    );
  }
}
