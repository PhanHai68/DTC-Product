import 'dart:convert';

import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/room/room_engine.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_plant.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = SurveyPlantEngine(air: appAirEngine(), room: appRoomEngine());

  /// Cụm máy tại (20, 10), ống sang phải tới (30, 10).
  (PipeSurvey, SurveyNode) sample(SurveyPlant plant) {
    final s = PipeSurvey();
    final mn = SurveyNode(
      x: 20,
      y: 10,
      kind: SurveyNodeKind.compressor,
      plant: plant,
    );
    final end = SurveyNode(x: 30, y: 10);
    s.nodes.addAll([mn, end]);
    s.segments.add(SurveySegment(a: mn.id, b: end.id));
    return (s, mn);
  }

  SurveyPlant quick({RoomStyle style = RoomStyle.option1}) =>
      SurveyPlant(modelCode: 'ACP-100PV', style: style);

  test('chọn nhanh: thiết bị đúng model, phòng tối thiểu kết thúc ở điểm '
      'Cụm máy, ống ra theo hướng đoạn ống', () {
    final (s, mn) = sample(quick());
    final layout = engine.layout(s, mn)!;
    expect(layout.compressorModel, 'ACP-100PV');
    final kinds = layout.items.map((i) => i.kind).toList();
    expect(kinds, containsAll([RoomItemKind.compressor, RoomItemKind.tank]));
    expect(kinds, contains(RoomItemKind.dryer));
    // Ống ra sang phải: phòng nằm bên trái điểm Cụm máy, cạnh phải trùng.
    expect(layout.outDir, const Offset(1, 0));
    expect(layout.room.right, closeTo(20, 1e-6));
    expect(layout.room.width, closeTo(layout.roomLengthM, 1e-6));
    expect(layout.supplyPipe.last.dx, closeTo(20, 1e-6));
    expect(layout.supplyPipe.last.dy, closeTo(10, 1e-6));
    // Kích thước thật: máy nén = kích thước catalog (m).
    final comp = layout.items.firstWhere(
      (i) => i.kind == RoomItemKind.compressor,
    );
    expect(comp.rect.width, closeTo(comp.lengthMm / 1000, 1e-6));
    expect(comp.rect.height, closeTo(comp.depthMm / 1000, 1e-6));
    // Thiết bị ở phía dưới ống (phía lối đi).
    expect(comp.rect.top, greaterThan(10));
  });

  test('3 phương án: kích thước phòng như tab Phòng lắp đặt', () {
    final (s, mn) = sample(quick());
    final options = engine.layout(s, mn)!.options;
    expect(options.map((o) => o.style), RoomStyle.values);
    mn.plant = quick(style: RoomStyle.option3);
    final third = engine.layout(s, mn)!;
    final o3 = options.firstWhere((o) => o.style == RoomStyle.option3);
    expect(third.roomLengthM, closeTo(o3.lengthMm / 1000, 1e-6));
    expect(third.roomWidthM, closeTo(o3.widthMm / 1000, 1e-6));
    // Phương án 3 xoay máy nén 90°.
    final comp = third.items.firstWhere(
      (i) => i.kind == RoomItemKind.compressor,
    );
    expect(comp.rect.width, closeTo(comp.lengthMm / 1000, 1e-6));
    expect(comp.lengthMm, lessThan(comp.depthMm));
  });

  test('hướng ống xuống, đổi phía thiết bị', () {
    final (s, mn) = sample(quick()..dir = SurveyPlantDir.down);
    final down = engine.layout(s, mn)!;
    expect(down.room.bottom, closeTo(10, 1e-6));
    expect(down.room.height, closeTo(down.roomLengthM, 1e-6));
    // Thiết bị bên trái ống (ống đi xuống).
    expect(down.room.left, lessThan(20));
    expect(down.room.right, closeTo(20 + 0.1, 0.5));
    mn.plant!.flip = true;
    final flipped = engine.layout(s, mn)!;
    expect(flipped.room.left, closeTo(20 - 0.1, 0.5));
    expect(flipped.room.right, greaterThan(20));
  });

  test('cấu hình đã lưu: dùng bản chụp; lưu / đọc JSON', () {
    final config = AirConfigTemplate.workshop.build();
    final plant = SurveyPlant(
      source: SurveyPlantSource.config,
      configId: config.id,
      configName: config.project.name,
      configJson:
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      style: RoomStyle.option2,
    );
    final (s, mn) = sample(plant);
    expect(engine.layout(s, mn), isNotNull);
    final back = PipeSurvey.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    final p = back.node(mn.id)!.plant!;
    expect(p.source, SurveyPlantSource.config);
    expect(p.style, RoomStyle.option2);
    expect(p.configName, 'Xưởng cơ khí');
    expect(
      engine.layout(back, back.node(mn.id)!)!.roomLengthM,
      engine.layout(s, mn)!.roomLengthM,
    );
    // Chưa chọn model: không vẽ kích thước thật.
    mn.plant = SurveyPlant();
    expect(engine.layout(s, mn), isNull);
  });
}
