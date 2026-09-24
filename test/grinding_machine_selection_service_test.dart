import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine_match.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_material_series_map.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_criteria.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_selection_service.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingMachine _machine({
  String machineId = 'M1',
  String seriesCode = 'S1',
  String model = 'M1',
  double? capacityMinKgH,
  double? capacityMaxKgH,
  double? finenessMin,
  double? finenessMax,
  String? finenessUnit,
  double? mainMotorKwMin,
  double? mainMotorKwMax,
  double? inputSizeMaxMm,
}) => GrindingMachine(
  machineId: machineId,
  seriesCode: seriesCode,
  model: model,
  capacityMinKgH: capacityMinKgH,
  capacityMaxKgH: capacityMaxKgH,
  finenessMin: finenessMin,
  finenessMax: finenessMax,
  finenessUnit: finenessUnit,
  mainMotorKwMin: mainMotorKwMin,
  mainMotorKwMax: mainMotorKwMax,
  inputSizeMaxMm: inputSizeMaxMm,
);

void main() {
  group('Capacity: MATCH / NOT_MATCH / UNKNOWN', () {
    test('capacity=800, yêu cầu >=500 -> MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(capacityKgH: 500),
        machines: [_machine(capacityMaxKgH: 800)],
      );
      expect(results.single.criteria.single.status, GrindingCriterionStatus.match);
    });

    test('capacity=300, yêu cầu >=500 -> NOT_MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(capacityKgH: 500),
        machines: [_machine(capacityMaxKgH: 300)],
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.notMatch,
      );
    });

    test('capacity=null -> UNKNOWN, KHÔNG được coi là match hay not_match', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(capacityKgH: 500),
        machines: [_machine()],
      );
      final status = results.single.criteria.single.status;
      expect(status, GrindingCriterionStatus.unknown);
      expect(status, isNot(GrindingCriterionStatus.match));
      expect(status, isNot(GrindingCriterionStatus.notMatch));
    });
  });

  test(
    'null specification must remain UNKNOWN cho MỌI tiêu chí, không tự đổi thành 0/false/match/not_match',
    () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(
          capacityKgH: 500,
          finenessValue: 20,
          finenessUnit: 'µm',
          maxMotorKw: 75,
          feedSizeMm: 10,
          materialId: 'SESAME',
          materialName: 'Vừng',
          application: 'tea',
        ),
        machines: [_machine()], // mọi field thông số đều null
        materialSeriesMap: const [],
        seriesTags: const {},
      );
      final match = results.single;
      expect(match.criteria, hasLength(6));
      expect(
        match.criteria.every((c) => c.status == GrindingCriterionStatus.unknown),
        isTrue,
        reason: 'Model không có dữ liệu nào phải toàn bộ UNKNOWN.',
      );
      expect(match.matchScore, 0);
      expect(match.label, GrindingMatchLabel.possible);
    },
  );

  test(
    'Giữ nguyên cả 3 trạng thái cùng lúc: capacity MATCH, fineness UNKNOWN, motor NOT_MATCH',
    () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(
          capacityKgH: 500,
          finenessValue: 20,
          finenessUnit: 'µm',
          maxMotorKw: 75,
        ),
        machines: [
          _machine(capacityMaxKgH: 800, mainMotorKwMax: 90), // fineness null
        ],
      );
      final match = results.single;
      expect(match.criteria, hasLength(3));
      final byLabel = {for (final c in match.criteria) c.label: c.status};
      expect(byLabel['Công suất'], GrindingCriterionStatus.match);
      expect(byLabel['Độ mịn'], GrindingCriterionStatus.unknown);
      expect(byLabel['Công suất động cơ'], GrindingCriterionStatus.notMatch);
      // NOT_MATCH ở 1 tiêu chí không được xóa mất thông tin của 2 tiêu chí kia.
      expect(match.matched, hasLength(1));
      expect(match.unknown, hasLength(1));
      expect(match.notMatched, hasLength(1));
      expect(match.label, GrindingMatchLabel.closest);
    },
  );

  test('Độ mịn quy đổi mesh <-> µm khi khác đơn vị', () {
    final results = GrindingMachineSelectionService.evaluate(
      criteria: const GrindingSelectionCriteria(
        finenessValue: 44, // ~325 mesh
        finenessUnit: 'µm',
      ),
      machines: [
        _machine(finenessMin: 100, finenessMax: 400, finenessUnit: 'mesh'),
      ],
    );
    expect(results.single.criteria.single.status, GrindingCriterionStatus.match);
  });

  test('Đơn vị mm không quy đổi chéo với mesh/µm -> UNKNOWN, không suy đoán', () {
    final results = GrindingMachineSelectionService.evaluate(
      criteria: const GrindingSelectionCriteria(
        finenessValue: 20,
        finenessUnit: 'µm',
      ),
      machines: [_machine(finenessMin: 1, finenessMax: 10, finenessUnit: 'mm')],
    );
    expect(results.single.criteria.single.status, GrindingCriterionStatus.unknown);
  });

  group('Nguyên liệu: chỉ dùng dữ liệu Verified', () {
    test('Verified, scoreAdjustment >= 0 -> MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(materialId: 'SESAME'),
        machines: [_machine(seriesCode: 'BS_ROLLER')],
        materialSeriesMap: const [
          GrindingMaterialSeriesMap(
            materialId: 'SESAME',
            seriesCode: 'BS_ROLLER',
            scoreAdjustment: 10,
            status: 'Verified',
          ),
        ],
      );
      expect(results.single.criteria.single.status, GrindingCriterionStatus.match);
    });

    test('Verified, scoreAdjustment âm -> NOT_MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(materialId: 'SESAME'),
        machines: [_machine(seriesCode: 'BS_ROLLER')],
        materialSeriesMap: const [
          GrindingMaterialSeriesMap(
            materialId: 'SESAME',
            seriesCode: 'BS_ROLLER',
            scoreAdjustment: -20,
            status: 'Verified',
          ),
        ],
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.notMatch,
      );
    });

    test('Chưa Verified (Needs validation) -> UNKNOWN, không suy đoán', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(materialId: 'SESAME'),
        machines: [_machine(seriesCode: 'BS_ROLLER')],
        materialSeriesMap: const [
          GrindingMaterialSeriesMap(
            materialId: 'SESAME',
            seriesCode: 'BS_ROLLER',
            scoreAdjustment: 10,
            status: 'Needs validation',
          ),
        ],
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.unknown,
      );
    });

    test('Không có dòng map nào cho series -> UNKNOWN', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(materialId: 'PEPPER'),
        machines: [_machine(seriesCode: 'BS_ROLLER')],
        materialSeriesMap: const [],
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.unknown,
      );
    });
  });

  group('Ứng dụng: đối chiếu Selection Tags', () {
    test('Series có tag khớp -> MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(application: 'tea'),
        machines: [_machine(seriesCode: 'S1')],
        seriesTags: const {
          'S1': {'food', 'tea'},
        },
      );
      expect(results.single.criteria.single.status, GrindingCriterionStatus.match);
    });

    test('Series có tag nhưng không khớp -> NOT_MATCH', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(application: 'tea'),
        machines: [_machine(seriesCode: 'S1')],
        seriesTags: const {
          'S1': {'chemical'},
        },
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.notMatch,
      );
    });

    test('Series chưa có tag nào ghi nhận -> UNKNOWN', () {
      final results = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(application: 'tea'),
        machines: [_machine(seriesCode: 'S1')],
        seriesTags: const {},
      );
      expect(
        results.single.criteria.single.status,
        GrindingCriterionStatus.unknown,
      );
    });
  });

  test('Sắp xếp: Strong Match -> Possible Match (có Unknown) -> Closest Match (có Not_match)', () {
    final results = GrindingMachineSelectionService.evaluate(
      criteria: const GrindingSelectionCriteria(
        capacityKgH: 500,
        maxMotorKw: 75,
      ),
      machines: [
        _machine(machineId: 'CLOSEST', model: 'CLOSEST', capacityMaxKgH: 300, mainMotorKwMax: 50),
        _machine(machineId: 'STRONG', model: 'STRONG', capacityMaxKgH: 800, mainMotorKwMax: 50),
        _machine(machineId: 'POSSIBLE', model: 'POSSIBLE', capacityMaxKgH: 800),
      ],
    );
    expect(results.map((m) => m.machine.machineId).toList(), [
      'STRONG',
      'POSSIBLE',
      'CLOSEST',
    ]);
    expect(results[0].label, GrindingMatchLabel.strong);
    expect(results[1].label, GrindingMatchLabel.possible);
    expect(results[2].label, GrindingMatchLabel.closest);
  });

  test('Không hard-code theo tên model: đổi machineId không đổi kết quả đối chiếu', () {
    final resultsA = GrindingMachineSelectionService.evaluate(
      criteria: const GrindingSelectionCriteria(capacityKgH: 500),
      machines: [_machine(machineId: 'BSP-500', model: 'BSP-500', capacityMaxKgH: 800)],
    );
    final resultsB = GrindingMachineSelectionService.evaluate(
      criteria: const GrindingSelectionCriteria(capacityKgH: 500),
      machines: [_machine(machineId: 'X', model: 'X', capacityMaxKgH: 800)],
    );
    expect(resultsA.single.label, resultsB.single.label);
    expect(resultsA.single.matchScore, resultsB.single.matchScore);
  });
}
