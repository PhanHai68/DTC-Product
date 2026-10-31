import 'dart:convert';
import 'dart:ui' show Offset, Rect;

import '../../air_system_config/engine/air_engine.dart';
import '../../air_system_config/models/air_config.dart' show RoomStyle;
import '../../air_system_config/room/room_engine.dart';
import '../models/pipe_survey.dart';

/// Cụm máy theo kích thước thật trên sơ đồ khảo sát: dùng bộ tính phòng lắp
/// đặt (phòng tối thiểu theo phương án), rồi đặt sao cho điểm ống ra khỏi
/// phòng trùng điểm Cụm máy, xoay theo hướng ống. Toạ độ m trên sơ đồ.

/// Một thiết bị của cụm máy.
class SurveyPlantItem {
  const SurveyPlantItem({
    required this.kind,
    required this.number,
    required this.model,
    required this.rect,
    required this.lengthMm,
    required this.depthMm,
    required this.estimated,
  });

  final RoomItemKind kind;

  /// Số thứ tự như mặt bằng phòng lắp đặt (1 = tủ điện…).
  final int number;
  final String? model;
  final Rect rect;

  /// Dài (dọc tường) × sâu (mm), chưa xoay theo sơ đồ.
  final double lengthMm;
  final double depthMm;
  final bool estimated;

  bool get isRound => kind == RoomItemKind.tank;
}

class SurveyPlantLayout {
  const SurveyPlantLayout({
    required this.items,
    required this.mainPipe,
    required this.supplyPipe,
    required this.branches,
    required this.filters,
    required this.filterSizeM,
    required this.room,
    required this.roomLengthM,
    required this.roomWidthM,
    required this.options,
    required this.style,
    required this.compressorModel,
    required this.outDir,
  });

  final List<SurveyPlantItem> items;

  /// Ống trong phòng máy (m): tuyến chính tới hết lọc cuối, phần sau đó ra
  /// điểm Cụm máy, nhánh vào lưng thiết bị.
  final List<Offset> mainPipe;
  final List<Offset> supplyPipe;
  final List<(Offset, Offset)> branches;

  /// Lọc treo trên ống: tâm và số L1, L2…
  final List<(Offset, int)> filters;
  final double filterSizeM;

  /// Phòng tối thiểu (kể cả khoảng bảo trì) trên sơ đồ.
  final Rect room;
  final double roomLengthM;
  final double roomWidthM;

  /// Cả 3 phương án (kích thước phòng tối thiểu, mm) để so sánh.
  final List<RoomOption> options;
  final RoomStyle style;
  final String? compressorModel;

  /// Hướng ống ra (vectơ đơn vị trên sơ đồ).
  final Offset outDir;

  Rect get bounds => items.fold(room, (r, i) => r.expandToInclude(i.rect));
}

/// Hướng ống ra đã chọn, hoặc theo đoạn ống đầu tiên nối vào điểm (mặc định
/// sang phải).
Offset surveyPlantDirection(PipeSurvey s, SurveyNode node) {
  switch (node.plant?.dir ?? SurveyPlantDir.auto) {
    case SurveyPlantDir.right:
      return const Offset(1, 0);
    case SurveyPlantDir.down:
      return const Offset(0, 1);
    case SurveyPlantDir.left:
      return const Offset(-1, 0);
    case SurveyPlantDir.up:
      return const Offset(0, -1);
    case SurveyPlantDir.auto:
      for (final seg in s.segmentsAt(node.id)) {
        final other = s.node(seg.a == node.id ? seg.b : seg.a);
        if (other == null) continue;
        final dx = other.x - node.x, dy = other.y - node.y;
        if (dx.abs() < 1e-9 && dy.abs() < 1e-9) continue;
        return dx.abs() >= dy.abs() ? Offset(dx.sign, 0) : Offset(0, dy.sign);
      }
      return const Offset(1, 0);
  }
}

/// Tính phòng lắp đặt cho cụm máy (bộ nhớ đệm theo dữ liệu thiết bị +
/// phương án: đổi hướng / vị trí không phải tính lại).
class SurveyPlantEngine {
  SurveyPlantEngine({required this.air, required this.room});

  final AirEngine air;
  final RoomEngine room;
  final _cache = <String, RoomResult?>{};

  /// Phòng lắp đặt tối thiểu của [plant]; `null` khi chưa đủ dữ liệu.
  RoomResult? roomFor(SurveyPlant plant) {
    final key = jsonEncode({...plant.toJson(), 'dir': null, 'flip': null});
    return _cache.putIfAbsent(key, () {
      final config = plant.airConfig();
      if (config == null) return null;
      final r = air.compute(config);
      if (r.compressor == null) return null;
      return room.compute(config, r);
    });
  }

  /// Bố trí cụm máy của [node] trên sơ đồ; `null` khi điểm không có
  /// [SurveyNode.plant] hoặc chưa đủ dữ liệu (chưa chọn model…).
  SurveyPlantLayout? layout(PipeSurvey s, SurveyNode node) {
    final plant = node.plant;
    if (plant == null || !plant.ready) return null;
    final rr = roomFor(plant);
    if (rr == null) return null;
    final dir = surveyPlantDirection(s, node);
    final supply = rr.supplyPipe;
    final exit = supply.length > 1
        ? supply.last
        : rr.mainPipe.lastOrNull ?? Offset(rr.lengthMm, 0);
    final origin = Offset(node.x, node.y);
    // Phòng: x dọc dãy (ống ra ở cuối, hướng +x), y từ tường sau ra lối đi.
    Offset map(Offset mm) {
      var d = (mm - exit) / 1000;
      if (plant.flip) d = Offset(d.dx, -d.dy);
      final r = dir.dx > 0.5
          ? d
          : dir.dy > 0.5
          ? Offset(-d.dy, d.dx)
          : dir.dx < -0.5
          ? Offset(-d.dx, -d.dy)
          : Offset(d.dy, -d.dx);
      return origin + r;
    }

    Rect rect(Rect mm) => Rect.fromPoints(map(mm.topLeft), map(mm.bottomRight));
    return SurveyPlantLayout(
      items: [
        for (final (k, i) in rr.items.indexed)
          SurveyPlantItem(
            kind: i.kind,
            number: k + 1,
            model: i.model,
            rect: rect(i.rect),
            lengthMm: i.lengthMm,
            depthMm: i.depthMm,
            estimated: i.sizeEstimated,
          ),
      ],
      mainPipe: [for (final q in rr.mainPipe) map(q)],
      supplyPipe: supply.length > 1
          ? [for (final q in supply) map(q)]
          : const [],
      branches: [for (final (a, b) in rr.branches) (map(a), map(b))],
      filters: [for (final f in rr.filters) (map(f.at), f.number)],
      filterSizeM: rr.filterSizeMm.$1 / 1000,
      room: rect(Rect.fromLTWH(0, 0, rr.lengthMm, rr.widthMm)),
      roomLengthM: rr.lengthMm / 1000,
      roomWidthM: rr.widthMm / 1000,
      options: rr.options,
      style: rr.style,
      compressorModel: rr.of(RoomItemKind.compressor).firstOrNull?.model,
      outDir: dir,
    );
  }
}
