import 'dart:math' as math;

import 'package:dtc_product/features/grain_analysis/engine/grain_analyzer.dart';
import 'package:dtc_product/features/grain_analysis/engine/image_decode.dart';
import 'package:dtc_product/features/grain_analysis/engine/image_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/grain_analysis/synthetic_tray.dart';

const analyzer = GrainAnalyzer(layout: testLayout);

GrainImageAnalysis run(img.Image image) =>
    analyzer.analyze(rasterFromImage(image));

void main() {
  test('đếm đúng các hạt rời, tính được pixelsPerMm, ảnh đạt chất lượng', () {
    final grains = gridGrains(count: 60);
    final result = run(renderTray(grains: grains));

    expect(result.markersFound, isTrue);
    expect(result.totalCount, 60);
    expect(result.pixelsPerMm, closeTo(12, 0.3));
    expect(result.issues, isEmpty, reason: '${result.metrics}');
    expect(result.tiltDegrees, lessThan(3));
    expect(result.grains.every((g) => g.contour.length >= 8), isTrue);
  });

  test('đo chiều dài, chiều rộng hạt theo mm', () {
    final grains = [
      for (var i = 0; i < 12; i++)
        SynthGrain(
          20.0 + (i % 4) * 18,
          35.0 + (i ~/ 4) * 20,
          7.0,
          2.4,
          i * math.pi / 12,
        ),
    ];
    final result = run(renderTray(grains: grains));
    expect(result.totalCount, 12);
    for (final g in result.grains) {
      expect(g.lengthMm, closeTo(7.0, 0.3));
      expect(g.widthMm, closeTo(2.4, 0.3));
    }
  });

  // Mẫu thật: đa số hạt rời, một phần dính đôi. Hai hàng trên cùng dành
  // cho các cặp dính, các hàng dưới là hạt rời.
  final singles = gridGrains(count: 72, seed: 9).skip(16).toList();

  test('tách các cặp hạt chạm nhau kiểu chữ T và nối đầu', () {
    final grains = <SynthGrain>[...singles];
    for (var i = 0; i < 4; i++) {
      final cx = 16.0 + i * 18.0;
      // Chữ T: đầu hạt dọc chạm (lấn 0,25 mm) vào hông hạt ngang.
      grains
        ..add(SynthGrain(cx, 31, 6.5, 2.3, 0))
        ..add(SynthGrain(cx + 1, 35.15, 6.5, 2.3, math.pi / 2));
      // Nối đầu: hai hạt thẳng hàng, đầu chạm đầu.
      grains
        ..add(SynthGrain(cx - 3.1, 40, 6.5, 2.3, 0.1))
        ..add(SynthGrain(cx + 3.1, 40, 6.5, 2.3, -0.1));
    }
    final result = run(renderTray(grains: grains));
    expect(result.totalCount, singles.length + 16);
    expect(result.grains.where((g) => g.isCluster), isEmpty);
  });

  test('cặp hạt dính song song: không tách được nhưng vẫn đếm đúng', () {
    final grains = <SynthGrain>[...singles];
    for (var i = 0; i < 8; i++) {
      final cx = 13.0 + i * 9.0;
      grains
        ..add(SynthGrain(cx - 1.0, 33, 6.5, 2.3, math.pi / 2))
        ..add(SynthGrain(cx + 1.0, 33, 6.5, 2.3, math.pi / 2 + 0.25));
    }
    final result = run(renderTray(grains: grains));
    expect(result.totalCount, singles.length + 16);
  });

  test('không thấy mốc khay: vẫn đếm, không có số đo mm, báo đúng lý do', () {
    final grains = gridGrains(count: 40, seed: 3);
    final result = run(renderTray(grains: grains, drawMarkers: false));

    expect(result.markersFound, isFalse);
    expect(result.pixelsPerMm, isNull);
    expect(result.issues, contains(QualityIssue.markers));
    expect(result.totalCount, 40);
    expect(result.grains.first.lengthMm, isNull);
  });

  test('ảnh mờ bị báo "Ảnh bị mờ"', () {
    final image = img.gaussianBlur(
      renderTray(grains: gridGrains(count: 30)),
      radius: 8,
    );
    final result = run(image);
    expect(
      result.issues,
      contains(QualityIssue.blur),
      reason: '${result.metrics}',
    );
  });

  test('chụp nghiêng bị báo "Máy đang nghiêng", vẫn đếm đúng', () {
    final image = perspective(renderTray(grains: gridGrains(count: 30)), 0.7);
    final result = run(image);
    expect(result.markersFound, isTrue);
    expect(result.issues, contains(QualityIssue.tilt));
    expect(result.totalCount, 30);
  });

  test('ảnh độ phân giải thấp bị báo thiếu chi tiết', () {
    final result = run(renderTray(grains: gridGrains(count: 20), ppm: 7));
    expect(result.issues, contains(QualityIssue.resolution));
  });

  test('bỏ bụi nhỏ và vật thể bị mép vùng phân tích cắt', () {
    final roi = testLayout.roiRect;
    final grains = [
      ...gridGrains(count: 30, seed: 5),
      // Hạt nằm vắt qua mép trái vùng rải mẫu.
      SynthGrain(roi.left, roi.centerY, 6.5, 2.2, 0),
    ];
    final dust = [
      for (var i = 0; i < 8; i++)
        (x: roi.left + 6 + i * 9.0, y: roi.bottom - 3, r: 0.25),
    ];
    final result = run(renderTray(grains: grains, dust: dust));
    expect(result.totalCount, 30);
    expect(result.edgeCutCount, greaterThanOrEqualTo(1));
  });

  test('cụm hạt chồng lên nhau được ước số hạt và báo hạt chồng nhau', () {
    final grains = [
      ...gridGrains(count: 20, seed: 7),
      // 4 hạt chồng thành một đống không tách được.
      for (var k = 0; k < 4; k++)
        SynthGrain(50, 100, 6.5, 2.2, k * math.pi / 4),
    ];
    final result = run(renderTray(grains: grains));
    final clusters = result.grains.where((g) => g.isCluster).toList();
    expect(clusters, isNotEmpty);
    expect(result.issues, contains(QualityIssue.overlap));
    expect(result.totalCount, inInclusiveRange(21, 24));
  });

  test('khay chụp xoay ngang vẫn nắn đúng chiều và đếm đúng', () {
    final image = img.copyRotate(
      renderTray(grains: gridGrains(count: 35, seed: 11)),
      angle: 90,
    );
    final result = run(image);
    expect(result.markersFound, isTrue);
    // Khung đã nắn luôn theo chiều khay (khổ đứng).
    expect(result.frameHeight, greaterThan(result.frameWidth));
    expect(result.totalCount, 35);
  });

  test('ánh sáng lệch một bên bị báo "Ánh sáng không đều"', () {
    final image = renderTray(grains: gridGrains(count: 30, seed: 13));
    for (final p in image) {
      final k = 0.45 + 0.55 * p.x / image.width; // tối dần sang trái
      p
        ..r = p.r * k
        ..g = p.g * k
        ..b = p.b * k;
    }
    final result = run(image);
    expect(
      result.issues,
      contains(QualityIssue.lighting),
      reason: '${result.metrics}',
    );
  });

  // Hồi quy từ ảnh thật đầu tiên (07/10/2026): giấy trắng không có mốc, phần
  // dưới tối dần, ảnh điện thoại độ phân giải cao có nhiễu. Bản 1.0.0 coi cả
  // vùng giấy tối là "hạt" và đếm ra hơn 110.000 hạt.
  test('giấy trắng sáng không đều, ảnh lớn có nhiễu, không mốc: đếm đúng', () {
    final image = renderTray(
      grains: gridGrains(count: 40, seed: 51),
      ppm: 24,
      drawMarkers: false,
      background: (r: 236, g: 238, b: 242),
      grainR: 120,
      grainG: 42,
      grainB: 36,
    );
    final rnd = math.Random(7);
    for (final p in image) {
      final k = 1.0 - 0.30 * p.y / image.height; // tối dần xuống dưới
      final n = (rnd.nextDouble() + rnd.nextDouble() - 1) * 12; // nhiễu
      p
        ..r = (p.r * k + n).clamp(0, 255)
        ..g = (p.g * k + n).clamp(0, 255)
        ..b = (p.b * k + n).clamp(0, 255);
    }
    final result = run(image);
    expect(result.totalCount, 40, reason: '${result.metrics}');
    expect(result.grains.where((g) => g.isCluster), isEmpty);
    expect(result.issues, contains(QualityIssue.lighting));
  });

  test('vùng cháy sáng lớn bị báo "Ánh sáng không đều"', () {
    final image = renderTray(grains: gridGrains(count: 30, seed: 15));
    final roi = testLayout.roiRect;
    img.fillCircle(
      image,
      x: ((roi.centerX) * 12).round() + 40,
      y: ((roi.centerY) * 12).round() + 40,
      radius: 150,
      color: img.ColorRgb8(255, 255, 255),
    );
    final result = run(image);
    expect(result.issues, contains(QualityIssue.lighting));
  });
}
