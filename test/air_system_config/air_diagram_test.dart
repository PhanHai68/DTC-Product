import 'dart:math' as math;

import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram_render.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram_svg.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AirDiagram _diagram(AirConfig config, [AirLang lang = AirLang.vi]) =>
    buildAirDiagram(config, appAirEngine().compute(config), AirStrings(lang));

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

bool _inside(AirDiagram d) => d.texts.every(
  (t) =>
      t.box.left >= 0 &&
      t.box.right <= d.width &&
      t.box.top >= 0 &&
      t.box.bottom <= d.height,
);

void main() {
  for (final template in AirConfigTemplate.values) {
    for (final lang in AirLang.values) {
      test(
        '${template.title} (${lang.name}): không chồng chữ, nằm trong khung',
        () {
          final d = _diagram(template.build(), lang);
          expect(_overlaps(d), isEmpty);
          expect(_inside(d), isTrue);
        },
      );
    }
  }

  test('20 line: không chồng chữ, các ô line không chồng nhau', () {
    final config = AirConfig(
      lines: [
        for (var i = 0; i < 20; i++)
          AirLine(name: 'Line ${i + 1} xưởng số ${i + 1}'),
      ],
    )..compressor.demand = 30;
    final d = _diagram(config);
    expect(_overlaps(d), isEmpty);
    expect(_inside(d), isTrue);
    final boxes = d.shapes
        .whereType<DRect>()
        .where(
          (r) =>
              (r.rect.width - 220).abs() < 0.01 &&
              (r.rect.height - 50).abs() < 0.01,
        )
        .map((r) => r.rect)
        .toList();
    expect(boxes, hasLength(20));
    for (var i = 0; i < boxes.length; i++) {
      for (var j = i + 1; j < boxes.length; j++) {
        expect(boxes[i].overlaps(boxes[j]), isFalse);
      }
    }
  });

  test('tắt bình, after cooler, lọc: không vẽ, các thiết bị sau dồn lại', () {
    final full = _diagram(AirConfigTemplate.food.build());
    final config = AirConfigTemplate.food.build()
      ..tank.enabled = false
      ..pretreat.afterCooler = AfterCoolerType.none
      ..pretreat.standard = false
      ..pretreat.waterSeparator = false;
    final d = _diagram(config);
    final texts = d.texts.map((t) => t.text).toSet();
    expect(texts, isNot(contains('V2000')));
    expect(texts, isNot(contains('After cooler')));
    expect(texts, isNot(contains('1. Tách nước 3 micron')));
    // Không còn lọc tuyến chính → lọc sau máy sấy đánh số từ 1.
    expect(texts, contains('1. Tách thô 1 micron'));
    expect(d.width, lessThan(full.width));
  });

  test('tiêu đề có tên dự án và thành phần hệ thống', () {
    final config = AirConfigTemplate.food.build();
    final texts = _diagram(config).texts.map((t) => t.text).join('\n');
    expect(texts, contains('Thực phẩm 3 line'));
    expect(texts, contains('1 máy nén khí không dầu'));
    expect(texts, contains('1 máy sấy hấp thụ'));
    expect(texts, isNot(contains('ISO 8573-1: [')));
  });

  test('bộ lọc đường ống: đánh số liên tục 1 → 3, mỗi lọc có xả tự động; '
      'máy nén và máy sấy có công suất', () {
    final d = _diagram(AirConfigTemplate.workshop.build());
    final texts = d.texts.map((t) => t.text).toList();
    // Tuyến chính: 1 tách nước; sau máy sấy: 2 tách thô, 3 tách tinh.
    // Hai cụm lọc có tiêu đề "Lọc"; chú giải gọi là "Bộ lọc đường ống".
    expect(texts.where((t) => t == 'Lọc'), hasLength(2));
    expect(texts, contains('Bộ lọc đường ống'));
    // Ghi chú dài không bị gãy dòng.
    expect(texts, contains('1. Tách nước 3 micron'));
    expect(texts, contains('Lưu lượng: 12,6 m³/phút'));
    expect(texts, contains('Áp suất làm việc: 7,5 bar'));
    expect(texts, contains('PM VFD – Trục vít biến tần'));
    expect(texts, contains('Lưu lượng: 13,5 m³/phút'));
    // Mọi khối ghi chú bắt đầu cùng một hàng.
    final firstLines = d.texts.where(
      (t) => ['ACP-100PV', 'Bình chứa khí', 'Lọc', 'ACD-13'].contains(t.text),
    );
    expect(firstLines.map((t) => t.baseline.dy).toSet(), hasLength(1));
    final coarse = texts.indexOf('2. Tách thô 1 micron');
    final fine = texts.indexOf('3. Tách tinh 0,01 micron');
    expect(coarse, isNonNegative);
    expect(fine, greaterThan(coarse));
    for (final n in ['1', '2', '3']) {
      expect(texts, contains(n));
    }
    // Ghi chú dưới 2 cụm lọc + chú giải.
    expect(texts.where((t) => t == 'Xả tự động'), hasLength(3));
    // Van xả: bình + máy sấy + 3 lọc (chưa tính mẫu trong chú giải).
    final filters = d.shapes
        .whereType<DImage>()
        .where((i) => i.asset == AirDiagramAssets.filter)
        .length;
    expect(filters, 4); // 3 lọc + 1 mẫu trong chú giải
    expect(texts, contains('Công suất: 75 kW'));
    // ACD-13: máy nén lạnh 3 kW + quạt 420 W.
    expect(texts, contains('Công suất: 3,42 kW'));
    expect(texts, isNot(contains(startsWith('PDP '))));
  });

  test('tiếng Anh: số dùng dấu chấm', () {
    final texts = _diagram(
      AirConfigTemplate.food.build(),
      AirLang.en,
    ).texts.map((t) => t.text).join(' ');
    // Ghi chú dài có thể xuống dòng giữa số và đơn vị.
    expect(texts, contains('22.5 m³/min'));
    expect(texts, contains('Complete Installation Layout'));
  });

  test('màu ống: tuyến chính tới hết lọc cuối, sau đó tới thiết bị sử dụng; '
      'tuyến chính ngắn lại', () {
    final d = _diagram(AirConfigTemplate.workshop.build());
    final pipes = d.shapes.whereType<DPath>().where((p) => p.stroke != null);
    final supply = pipes.where((p) => p.stroke == AirDiagramColors.supply);
    expect(supply, isNotEmpty);
    expect(
      pipes.any((p) => p.stroke == AirDiagramColors.refrigerated),
      isFalse,
    );
    // Đoạn cam bắt đầu ngay sau lọc số 2 (lọc cuối).
    final filters = d.shapes
        .whereType<DImage>()
        .where((i) => i.asset == AirDiagramAssets.filter)
        .map((i) => i.rect.right)
        .reduce(math.max);
    // Bỏ mẫu ống trong phần chú giải (dưới cùng).
    final legendY = d.texts
        .firstWhere((t) => t.text == 'Đường tới thiết bị sử dụng')
        .baseline
        .dy;
    final supplyStart = supply
        .where((p) => p.points.first.dy < legendY - 30)
        .map((p) => p.points.first.dx)
        .reduce(math.min);
    expect(supplyStart, greaterThanOrEqualTo(filters - 0.01));
    final texts = d.texts.map((t) => t.text).toList();
    expect(texts, contains('Đường tới thiết bị sử dụng'));
    expect(texts, isNot(contains('Tới máy sấy lạnh')));
    // Máy nén → bình: 60 px (gấp đôi khe 30 px giữa các thiết bị khác);
    // máy nén → khung máy sấy vẫn ngắn hơn bản đầu (374 px).
    final compressor = d.shapes
        .whereType<DImage>()
        .firstWhere((i) => i.asset == AirDiagramAssets.compressor)
        .rect;
    final tank = d.shapes
        .whereType<DImage>()
        .firstWhere((i) => i.asset == AirDiagramAssets.tank)
        .rect;
    expect(tank.left - compressor.right, closeTo(60, 0.01));
    final frame = d.shapes.whereType<DRect>().firstWhere((r) => r.dashed).rect;
    expect(frame.left - compressor.right, lessThan(374));
  });

  test('SVG hợp lệ, có đủ chữ', () {
    final svg = airDiagramSvg(_diagram(AirConfigTemplate.workshop.build()));
    expect(svg, startsWith('<?xml'));
    expect(svg.trim(), endsWith('</svg>'));
    expect(svg, contains('Sơn tĩnh điện'));
    expect(svg, contains('stroke-dasharray'));
  });

  testWidgets('PNG xuất được ở tỉ lệ 2x', (tester) async {
    final d = _diagram(AirConfigTemplate.pharma.build());
    final bytes = await tester.runAsync(() => airDiagramPng(d));
    expect(bytes, isNotNull);
    expect(bytes!.sublist(1, 4), 'PNG'.codeUnits);
    final image = await tester.runAsync(() => decodeImageFromList(bytes));
    expect(image!.width, (d.width * 2).ceil());
  });

  testWidgets('sơ đồ dùng ảnh thiết bị thật; SVG nhúng ảnh PNG', (
    tester,
  ) async {
    final config = AirConfigTemplate.food.build();
    final d = _diagram(config);
    // Mẫu thực phẩm (sấy hấp thụ) + xưởng cơ khí (sấy lạnh) đủ 5 loại ảnh.
    final assets = {
      for (final c in [config, AirConfigTemplate.workshop.build()])
        ..._diagram(c).shapes.whereType<DImage>().map((i) => i.asset),
    };
    expect(assets, AirDiagramAssets.all.toSet());
    final images = await tester.runAsync(AirDiagramImages.bytes);
    expect(images!.keys.toSet(), AirDiagramAssets.all.toSet());
    final svg = airDiagramSvg(d, images: images);
    expect(
      '<image '.allMatches(svg).length,
      d.shapes.whereType<DImage>().length,
    );
  });
}
