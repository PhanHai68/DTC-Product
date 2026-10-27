import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:dtc_product/features/air_system_config/room/room_drawing.dart';
import 'package:dtc_product/features/air_system_config/room/room_engine.dart';
import 'package:dtc_product/features/air_system_config/room/room_strings.dart';
import 'package:flutter/material.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';

RoomResult _room(AirConfig c) =>
    appRoomEngine().compute(c, appAirEngine().compute(c));

/// Các cặp chữ chồng lên nhau (khung ước lượng thu nhỏ 1 px mỗi cạnh).
List<String> _overlaps(AirDiagram d) {
  final texts = d.texts.toList();
  final hits = <String>[];
  for (var i = 0; i < texts.length; i++) {
    for (var j = i + 1; j < texts.length; j++) {
      final a = texts[i].box.deflate(1);
      final b = texts[j].box.deflate(1);
      if (a.overlaps(b)) hits.add('"${texts[i].text}" × "${texts[j].text}"');
    }
  }
  return hits;
}

void main() {
  test(
    'hằng số phòng đọc từ room_layout_constants.json (theo đề xuất đã duyệt)',
    () {
      final c = roomLayoutConstants;
      expect(c.clearance('compressor').front, 1000);
      expect(c.clearance('compressor').side, 800);
      expect(c.clearance('compressor').rear, 800);
      expect(c.clearance('dryer').front, 800);
      expect(c.clearance('dryer').side, 600);
      expect(c.clearance('tank').side, 500);
      expect(c.aisleMm, 1000);
      expect(c.wallGapMm, 800);
      expect([c.compressorFactor, c.dryerFactor], [1.06, 1.2]);
      expect([c.outsideTempC, c.inletMaxTempC], [35, 46]);
      expect(c.openingVelocity, 2.5);
    },
  );

  group('Mẫu xưởng cơ khí (ACP-100PV, V3000, ACD-13)', () {
    late RoomResult r;
    setUp(() => r = _room(AirConfigTemplate.workshop.build()));

    test('một hàng: đủ thiết bị theo dòng khí, phòng làm tròn 0,5 m', () {
      expect(r.style, RoomStyle.option1);
      expect(r.items.map((i) => i.kind), [
        RoomItemKind.panel,
        RoomItemKind.compressor,
        RoomItemKind.tank,
        RoomItemKind.dryer,
      ]);
      final comp = r.of(RoomItemKind.compressor).single;
      expect(comp.model, 'ACP-100PV');
      expect([comp.lengthMm, comp.depthMm], [1720, 1220]);
      for (final v in [r.lengthMm, r.widthMm, r.heightMm]) {
        expect(v % 500, 0);
      }
      // Sâu: sau 800 + máy 1220 + trước 1000 → 3.020 → 3,5 m.
      expect(r.widthMm, 3500);
      expect(r.heightMm, greaterThanOrEqualTo(3000));
      expect(r.fits, isTrue);
    });

    test('thiết bị và vùng bảo trì không chồng nhau, nằm trong phòng', () {
      final room = Rect.fromLTWH(0, 0, r.lengthMm, r.widthMm);
      for (var i = 0; i < r.items.length; i++) {
        final a = r.items[i];
        expect(room.contains(a.rect.topLeft), isTrue);
        expect(room.contains(a.rect.bottomRight - const Offset(1, 1)), isTrue);
        for (var j = i + 1; j < r.items.length; j++) {
          expect(a.rect.overlaps(r.items[j].rect), isFalse);
        }
      }
    });

    test('lọc đánh số 1 → 3 theo dòng khí; ống sau lọc cuối ra xưởng', () {
      expect(r.filters.map((f) => (f.number, f.grade)), [
        (1, RoomFilterGrade.water),
        (2, RoomFilterGrade.coarse),
        (3, RoomFilterGrade.fine),
      ]);
      // Đường tới thiết bị sử dụng bắt đầu sau lọc 3 và ra tới tường.
      expect(r.supplyPipe.first.dx, greaterThan(r.filters.last.at.dx));
      expect(r.supplyPipe.last.dx, r.lengthMm);
      expect(r.pipeDn, 'DN50');
    });

    test(
      'thông gió: Qv = (1,06·N + 1,2·D) / (T2 − T1), mặc định 35 / 46 °C',
      () {
        final v = r.ventilation;
        expect(v.compressorKw, 75);
        // ACD-13: 3 kW + quạt 420 W.
        expect(v.dryerKw, closeTo(3.42, 1e-9));
        expect([v.outsideTempC, v.inletMaxTempC, v.deltaT], [35, 46, 11]);
        expect(v.airflowM3s, closeTo((1.06 * 75 + 1.2 * 3.42) / 11, 1e-9));
        expect(v.airflowM3h, closeTo(v.airflowM3s * 3600, 1e-6));
        // Bản vẽ: không hiện công thức, lưu lượng làm tròn số nguyên.
        final lines = AirStrings(AirLang.vi).roomVentLines(r);
        expect(lines, isNot(contains('Qv')));
        expect(lines, isNot(contains('T1')));
        expect(lines, contains('Lưu lượng gió: 28.800 m³/h'));
        expect(lines, isNot(contains('m³/s')));
        expect(v.suggestedM3s, 8);
        expect(v.suggestedM3h, 28800);
        expect(v.openingM2, closeTo(8 / 2.5, 1e-9));
      },
    );

    test('thông gió: nhập tay T1, T2; T2 ≤ T1 thì cảnh báo', () {
      final c = AirConfigTemplate.workshop.build()
        ..room.outsideTempC = 25
        ..room.inletMaxTempC = 46;
      final v = _room(c).ventilation;
      expect(v.deltaT, 21);
      expect(v.airflowM3s, closeTo((1.06 * 75 + 1.2 * 3.42) / 21, 1e-9));
      c.room.outsideTempC = 50;
      final bad = _room(c);
      expect(bad.ventilation.valid, isFalse);
      expect(bad.ventilation.airflowM3s, 0);
      expect(
        bad.warnings.map((w) => w.code),
        contains(RoomWarningCode.ventTemps),
      );
      final back = AirConfig.fromJson(c.toJson());
      expect([back.room.outsideTempC, back.room.inletMaxTempC], [50, 46]);
    });

    test('cửa đủ rộng cho thiết bị lớn nhất, không vướng thiết bị', () {
      expect(r.door.width, greaterThanOrEqualTo(1200));
      expect(r.door.width, greaterThanOrEqualTo(1220 + 200));
      expect(r.door.wall, RoomWall.front);
    });
  });

  test('3 phương án: máy sấy xoay (PA2), máy nén + máy sấy xoay (PA3)', () {
    final r = _room(AirConfigTemplate.workshop.build());
    expect(r.options.map((o) => o.style), RoomStyle.values);
    final o1 = r.options[0];
    final o2 = r.options[1];
    final o3 = r.options[2];
    // Máy sấy ACD-13 1.280 × 650 xoay: dọc tường còn 650 → phòng ngắn lại.
    expect(o2.lengthMm, lessThanOrEqualTo(o1.lengthMm));
    expect(o3.lengthMm, lessThanOrEqualTo(o2.lengthMm));
    // Máy nén 1.720 × 1.220 xoay: sâu 800 + 1.720 + 1.000 → phòng rộng hơn.
    expect(o3.widthMm, greaterThan(o1.widthMm));
    final pa2 = _room(
      AirConfigTemplate.workshop.build()..room.style = RoomStyle.option2,
    );
    final dryer = pa2.of(RoomItemKind.dryer).single;
    expect([dryer.lengthMm, dryer.depthMm], [650, 1280]);
    expect(dryer.rotated, isTrue);
    expect(pa2.of(RoomItemKind.compressor).single.rotated, isFalse);
    final pa3 = _room(
      AirConfigTemplate.workshop.build()..room.style = RoomStyle.option3,
    );
    final comp = pa3.of(RoomItemKind.compressor).single;
    expect([comp.lengthMm, comp.depthMm], [1220, 1720]);
    expect(pa3.lengthMm, o3.lengthMm);
  });

  test('phòng thực tế: báo phương án nào lọt; không lọt thì cảnh báo', () {
    final o3 = _room(AirConfigTemplate.workshop.build()).options[2];
    // Phòng vừa đúng phương án 3: PA3 lọt, PA1 (dài hơn) không lọt.
    final c = AirConfigTemplate.workshop.build()
      ..room.lengthM = o3.lengthMm / 1000
      ..room.widthM = o3.widthMm / 1000;
    final r = _room(c);
    expect(r.options[2].fits, isTrue);
    expect(r.options[0].fits, isFalse);
    expect(r.fits, isFalse);
    final w = r.warnings.firstWhere((w) => w.code == RoomWarningCode.tooSmall);
    expect(w.params['fitting'], contains(RoomStyle.option3));
    c.room.style = RoomStyle.option3;
    final ok = _room(c);
    expect(ok.fits, isTrue);
    expect([ok.lengthMm, ok.widthMm], [o3.lengthMm, o3.widthMm]);
    final small = _room(
      AirConfigTemplate.workshop.build()
        ..room.lengthM = 4
        ..room.widthM = 3
        ..room.heightM = 3,
    );
    expect(
      small.warnings.map((w) => w.code),
      containsAll([RoomWarningCode.tooSmall, RoomWarningCode.tooLow]),
    );
    // Phòng có sẵn: vẽ đúng kích thước nhập, báo thiết bị ngoài phòng.
    expect([small.lengthMm, small.widthMm, small.heightMm], [4000, 3000, 3000]);
    expect(
      small.warnings.map((w) => w.code),
      contains(RoomWarningCode.outside),
    );
  });

  test('lọc theo model lọc đường ống; tủ điện 500 × 400 × 300', () {
    final r = _room(AirConfigTemplate.workshop.build());
    expect(r.filterModel, '013');
    final panel = r.of(RoomItemKind.panel).single;
    expect([panel.lengthMm, panel.depthMm, panel.heightMm], [500, 400, 300]);
    expect(panel.sizeEstimated, isFalse);
  });

  test('thông số phòng lưu cùng cấu hình (JSON)', () {
    final c = AirConfigTemplate.workshop.build()
      ..room.lengthM = 9
      ..room.widthM = 6
      ..room.style = RoomStyle.option2
      ..room.door = RoomDoorWall.left;
    c.room.positions['tank_0'] = (4000, 1500);
    c.room.measures.add(const RoomMeasure(0, 0, 1200, 0));
    final back = AirConfig.fromJson(c.toJson());
    expect(back.room.toJson(), c.room.toJson());
    expect(back.room.positions['tank_0'], (4000.0, 1500.0));
    expect(back.room.measures.single.bx, 1200);
  });

  test('xoay tay: đảo 90° so với phương án; lưu JSON', () {
    final c = AirConfigTemplate.workshop.build()
      ..room.turned.add('compressor_0');
    final r = _room(c);
    final comp = r.of(RoomItemKind.compressor).single;
    expect([comp.lengthMm, comp.depthMm], [1220, 1720]);
    expect(comp.rotated, isTrue);
    // Phương án 2 đã xoay máy sấy; xoay tay lần nữa → về dọc tường.
    c.room
      ..style = RoomStyle.option2
      ..turned.add('dryer_0');
    final dryer = _room(c).of(RoomItemKind.dryer).single;
    expect([dryer.lengthMm, dryer.depthMm], [1280, 650]);
    final back = AirConfig.fromJson(c.toJson());
    expect(back.room.turned, {'compressor_0', 'dryer_0'});
  });

  test('di chuyển thiết bị: theo vị trí chỉnh tay, giữ trong phòng, nhánh '
      'ống đi theo; chồng nhau thì cảnh báo', () {
    final c = AirConfigTemplate.workshop.build();
    final auto = _room(c);
    expect(auto.items.map((i) => i.key), [
      'panel_0',
      'compressor_0',
      'tank_0',
      'dryer_0',
    ]);
    // Bình kéo ra giữa phòng.
    c.room.positions['tank_0'] = (3000, 1500);
    final moved = _room(c);
    final tank = moved.of(RoomItemKind.tank).single;
    expect(tank.rect.topLeft, const Offset(3000, 1500));
    expect(tank.moved, isTrue);
    expect(
      moved.branches.any(
        (b) =>
            (b.$1.dx - tank.rect.center.dx).abs() < 1e-6 &&
            (b.$2.dy - tank.rect.top).abs() < 1e-6,
      ),
      isTrue,
    );
    // Kéo quá tường: giữ trong phòng.
    c.room.positions['tank_0'] = (99999, -500);
    final clamped = _room(c).of(RoomItemKind.tank).single;
    expect(clamped.rect.right, closeTo(auto.lengthMm, 1e-6));
    expect(clamped.rect.top, 0);
    // Kéo bình đè lên máy nén → cảnh báo.
    final comp = auto.of(RoomItemKind.compressor).single;
    c.room.positions['tank_0'] = (comp.rect.left, comp.rect.top);
    final clash = _room(c);
    final w = clash.warnings.firstWhere((w) => w.code == RoomWarningCode.clash);
    expect(w.params['items'], containsAll([2, 3]));
  });

  for (final template in AirConfigTemplate.values) {
    for (final style in RoomStyle.values) {
      for (final lang in AirLang.values) {
        test('bản vẽ ${template.title} ${style.name} (${lang.name}): '
            'không chồng chữ, nằm trong khung', () {
          final c = template.build()..room.style = style;
          final d = buildRoomDrawing(c, _room(c), AirStrings(lang));
          expect(_overlaps(d), isEmpty);
          expect(
            d.texts.every(
              (t) =>
                  t.box.left >= 0 &&
                  t.box.right <= d.width &&
                  t.box.top >= 0 &&
                  t.box.bottom <= d.height,
            ),
            isTrue,
          );
        });
      }
    }
  }
}
