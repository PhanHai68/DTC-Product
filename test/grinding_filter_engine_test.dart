import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/utils/grinding_filter.dart';
import 'package:dtc_product/features/grinding_machine/utils/grinding_fineness_converter.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingMachine _machine({
  required String id,
  String seriesCode = 'S1',
  double? capacityMinKgH,
  double? capacityMaxKgH,
  double? finenessMin,
  double? finenessMax,
  String? finenessUnit,
}) => GrindingMachine(
  machineId: id,
  seriesCode: seriesCode,
  model: id,
  capacityMinKgH: capacityMinKgH,
  capacityMaxKgH: capacityMaxKgH,
  finenessMin: finenessMin,
  finenessMax: finenessMax,
  finenessUnit: finenessUnit,
);

void main() {
  group('GrindingFilterEngine — Capacity', () {
    test('khớp bucket khi khoảng công suất giao nhau', () {
      final machine = _machine(
        id: 'M1',
        capacityMinKgH: 80,
        capacityMaxKgH: 300,
      );
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(
          capacityBucket: GrindingCapacityBucket.r100to300,
        ),
      );
      expect(result, [machine]);
    });

    test('không khớp bucket khi khoảng công suất không giao nhau', () {
      final machine = _machine(
        id: 'M1',
        capacityMinKgH: 1500,
        capacityMaxKgH: 2500,
      );
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(
          capacityBucket: GrindingCapacityBucket.under100,
        ),
      );
      expect(result, isEmpty);
    });

    test('không khớp model thiếu dữ liệu công suất (không suy đoán)', () {
      final machine = _machine(id: 'M1');
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(
          capacityBucket: GrindingCapacityBucket.over1000,
        ),
      );
      expect(result, isEmpty);
    });
  });

  group('GrindingFilterEngine — Fineness', () {
    test('khớp cùng đơn vị trong khoảng min-max', () {
      final machine = _machine(
        id: 'M1',
        finenessMin: 10,
        finenessMax: 120,
        finenessUnit: 'mesh',
      );
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(finenessUnit: 'mesh', finenessValue: 50),
      );
      expect(result, [machine]);
    });

    test('KHÔNG quy đổi chéo với đơn vị mm (nghiền thô)', () {
      final machine = _machine(
        id: 'M1',
        finenessMin: 0.5,
        finenessMax: 20,
        finenessUnit: 'mm',
      );
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(finenessUnit: 'mesh', finenessValue: 50),
      );
      expect(result, isEmpty);
    });

    test('quy đổi chéo mesh <-> µm khi khớp lọc', () {
      // 325 mesh ~ 44 micron theo bảng chuẩn ASTM đã dùng trong app.
      final machine = _machine(
        id: 'M1',
        finenessMin: 10,
        finenessMax: 400,
        finenessUnit: 'mesh',
      );
      final result = GrindingFilterEngine.apply(
        [machine],
        const GrindingFilterCriteria(finenessUnit: 'µm', finenessValue: 44),
      );
      expect(result, [machine]);
    });
  });

  group('GrindingFilterEngine — Material (compatibleSeriesCodes)', () {
    test('chỉ giữ model thuộc series đã xác minh tương thích nguyên liệu', () {
      final machineA = _machine(id: 'A', seriesCode: 'BS_ROLLER');
      final machineB = _machine(id: 'B', seriesCode: 'BSK_JET');
      final result = GrindingFilterEngine.apply(
        [machineA, machineB],
        const GrindingFilterCriteria(materialId: 'SESAME'),
        compatibleSeriesCodes: {'BS_ROLLER'},
      );
      expect(result, [machineA]);
    });

    test('trả rỗng khi nguyên liệu chưa có series nào được xác minh', () {
      final machineA = _machine(id: 'A', seriesCode: 'BS_ROLLER');
      final result = GrindingFilterEngine.apply(
        [machineA],
        const GrindingFilterCriteria(materialId: 'PEPPER'),
        compatibleSeriesCodes: {},
      );
      expect(result, isEmpty);
    });
  });

  group('GrindingFinenessConverter', () {
    test('quy đổi mesh sang micron khớp bảng chuẩn tại các mốc có sẵn', () {
      expect(GrindingFinenessConverter.meshToMicron(325), closeTo(44, 0.01));
      expect(GrindingFinenessConverter.meshToMicron(100), closeTo(149, 0.01));
    });

    test('quy đổi micron sang mesh khớp bảng chuẩn tại các mốc có sẵn', () {
      expect(GrindingFinenessConverter.micronToMesh(44), closeTo(325, 0.01));
      expect(GrindingFinenessConverter.micronToMesh(149), closeTo(100, 0.01));
    });
  });
}
