import '../../../data/product_data.dart';
import '../engine/air_engine.dart';
import '../models/air_config.dart';
import '../models/catalog_compressor.dart';
import '../pipe/pipe_engine.dart';
import '../room/room_engine.dart';

/// Bộ tính dùng dữ liệu đã nạp của app (model máy nén ACP/ACA và AFR, bình,
/// MCCB, hằng số).
AirEngine appAirEngine() => AirEngine(
  constants: airSystemConstants,
  compressors: [
    for (final m in acompSpecData) CatalogCompressor.fromAcomp(m),
    for (final m in oilFreeSpecs) CatalogCompressor.fromOilFree(m),
  ],
  tanks: airTankSpecs,
  mccb: acompMccbData,
  refrigeratedDryers: refrigeratedDryers,
  lineFilters: lineFilters,
);

/// Bộ tính phòng lắp đặt dùng hằng số và bảng ống của app.
RoomEngine appRoomEngine() =>
    RoomEngine(constants: roomLayoutConstants, pipes: pipeStandardData);

/// Bộ tính vật tư từ cụm máy đến thiết bị sử dụng khí nén (định mức 15 m).
PipeMaterialEngine appPipeEngine() =>
    PipeMaterialEngine(kit: pipeRunKit, installKits: installKits);

enum AirConfigTemplate {
  food('Thực phẩm 3 line'),
  workshop('Xưởng cơ khí'),
  pharma('Nhà máy dược');

  const AirConfigTemplate(this.title);
  final String title;

  /// Cấu hình mẫu (dùng cho test): line chỉ là tên nơi dùng khí.
  AirConfig build() => switch (this) {
    food => AirConfig(
      project: AirProject(name: 'Thực phẩm 3 line'),
      compressor: CompressorConfig(
        type: CompressorType.oilFree,
        pressure: 8,
        demand: 15.5,
      ),
      pretreat: PretreatConfig(afterCooler: AfterCoolerType.air),
      treatment: AirTreatment(pdp: LinePdp.m40, usePressure: 7),
      regen: RegenType.heatless,
      lines: [
        AirLine(name: 'Máy chiết rót'),
        AirLine(name: 'Máy đóng gói'),
        AirLine(name: 'Máy tách màu'),
      ],
    ),
    workshop => AirConfig(
      project: AirProject(name: 'Xưởng cơ khí'),
      compressor: CompressorConfig(
        type: CompressorType.pmVsd,
        pressure: 7.5,
        demand: 9.5,
      ),
      pretreat: PretreatConfig(afterCooler: AfterCoolerType.none),
      treatment: AirTreatment(usePressure: 6.5),
      lines: [
        AirLine(name: 'Sơn tĩnh điện'),
        AirLine(name: 'Máy CNC'),
        AirLine(name: 'Dụng cụ cầm tay'),
      ],
    ),
    pharma => AirConfig(
      project: AirProject(name: 'Nhà máy dược'),
      compressor: CompressorConfig(
        type: CompressorType.oilFree,
        pressure: 8,
        demand: 10,
      ),
      pretreat: PretreatConfig(afterCooler: AfterCoolerType.water),
      treatment: AirTreatment(pdp: LinePdp.m70, usePressure: 7),
      regen: RegenType.blower,
      lines: [
        AirLine(name: 'Đóng gói'),
        AirLine(name: 'Phòng sạch'),
        AirLine(name: 'Tiện ích'),
      ],
    ),
  };
}
