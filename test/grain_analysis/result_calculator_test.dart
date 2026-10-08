import 'package:dtc_product/features/grain_analysis/engine/result_calculator.dart';
import 'package:dtc_product/features/grain_analysis/models/grain.dart';
import 'package:flutter_test/flutter_test.dart';

Grain _grain(int i, {double area = 100, bool removed = false, int count = 1}) =>
    Grain(
      id: 'g$i',
      contour: const [],
      centroidX: 0,
      centroidY: 0,
      areaPx: area,
      removed: removed,
      estimatedCount: count,
    );

List<Grain> _grains(int n, {double area = 100}) => [
  for (var i = 0; i < n; i++) _grain(i, area: area),
];

void main() {
  group('Tỉ lệ theo số hạt và diện tích (mục 8)', () {
    test('300 hạt trên 1.000 hạt là 30,0%', () {
      final result = GrainResultCalculator.quickCount(
        wholeGrains: _grains(1000),
        wholePixelsPerMm: 10,
        groupGrains: _grains(300),
        groupPixelsPerMm: 10,
      );
      expect(result.wholeCount, 1000);
      expect(result.groupCount, 300);
      expect(result.countPercent, 30.0);
      expect(result.areaPercent, closeTo(30.0, 1e-9));
      expect(result.areaInMm, isTrue);
      final rows = result.toClassResults();
      expect(rows.map((r) => r.grainCount), [300, 700]);
      expect(
        GrainResultCalculator.roundForDisplay(
          rows.map((r) => r.countPercent).toList(),
        ),
        [30.0, 70.0],
      );
    });

    test('% diện tích dùng mm² khi hai ảnh khác tỉ lệ pixel/mm', () {
      // Ảnh nhóm chụp gần hơn (20 px/mm): 100 px² = 0,25 mm²/hạt.
      // Ảnh cả mẫu 10 px/mm: 100 px² = 1 mm²/hạt.
      final result = GrainResultCalculator.quickCount(
        wholeGrains: _grains(100),
        wholePixelsPerMm: 10,
        groupGrains: _grains(40, area: 400),
        groupPixelsPerMm: 20,
      );
      // Nhóm: 40 × 1 mm² = 40 mm² trên 100 mm².
      expect(result.areaPercent, closeTo(40.0, 1e-9));
    });

    test('thiếu pixelsPerMm ở một ảnh thì so diện tích theo pixel', () {
      final result = GrainResultCalculator.quickCount(
        wholeGrains: _grains(100),
        wholePixelsPerMm: null,
        groupGrains: _grains(25),
        groupPixelsPerMm: 10,
      );
      expect(result.areaInMm, isFalse);
      expect(result.areaPercent, closeTo(25.0, 1e-9));
    });

    test('tổng 0 hạt không chia cho 0', () {
      expect(GrainResultCalculator.percent(0, 0), 0);
      final result = GrainResultCalculator.quickCount(
        wholeGrains: const [],
        wholePixelsPerMm: null,
        groupGrains: const [],
        groupPixelsPerMm: null,
      );
      expect(result.countPercent, 0);
      expect(result.areaPercent, 0);
    });
  });

  group('Đếm hạt', () {
    test('bỏ vật thể đã xóa, cụm tính theo số hạt ước tính', () {
      final grains = [
        ..._grains(10),
        _grain(98, removed: true),
        _grain(99, area: 300, count: 3),
      ];
      expect(GrainResultCalculator.countOf(grains), 13);
      expect(GrainResultCalculator.areaOf(grains, null), 1300);
      expect(GrainResultCalculator.areaOf(grains, 10), closeTo(13, 1e-9));
      final rows = GrainResultCalculator.countResults(grains);
      expect(rows.single.classId, ClassResult.allId);
      expect(rows.single.grainCount, 13);
    });
  });

  group('Làm tròn khi hiển thị', () {
    test('tổng các nhóm luôn bằng 100,0; chênh lệch dồn vào nhóm lớn nhất', () {
      final rounded = GrainResultCalculator.roundForDisplay([
        100 / 3,
        100 / 3,
        100 / 3,
      ]);
      expect(rounded.fold(0.0, (a, b) => a + b), closeTo(100.0, 1e-9));
      expect(rounded, [33.4, 33.3, 33.3]);
    });

    test('dồn vào nhóm lớn nhất, không phải nhóm đầu tiên', () {
      // 12,25 + 12,25 + 75,5: làm tròn từng số được 12,3 + 12,3 + 75,5 =
      // 100,1 → bớt 0,1 ở nhóm lớn nhất.
      final rounded = GrainResultCalculator.roundForDisplay([
        12.25,
        12.25,
        75.5,
      ]);
      expect(rounded, [12.3, 12.3, 75.4]);
      expect(rounded.fold(0.0, (a, b) => a + b), closeTo(100.0, 1e-9));
    });

    test('đã tròn sẵn thì giữ nguyên', () {
      expect(GrainResultCalculator.roundForDisplay([30, 70]), [30.0, 70.0]);
    });
  });
}
