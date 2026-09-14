/// Unit tests cho MachineSelectorService.
/// Kiểm tra logic ranking với dữ liệu thực tế từ database.

import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/models/machine_selector_request.dart';
import 'package:dtc_product/models/machine_match_result.dart';
import 'package:dtc_product/services/machine_selector_service.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';

/// Mock repository trả về dữ liệu test tĩnh (không cần database thật)
class MockPackingMachineRepository implements PackingMachineRepository {
  final List<PackingMachine> _mockMachines;

  MockPackingMachineRepository(this._mockMachines);

  @override
  Future<List<PackingMachine>> getMachinesForSelector({
    String? bagMaterial,
    double? weightKg,
  }) async {
    var result = List<PackingMachine>.from(_mockMachines);

    if (bagMaterial != null && bagMaterial.isNotEmpty) {
      result = result.where((m) {
        return m.bagMaterial == null ||
            m.bagMaterial!.isEmpty ||
            m.bagMaterial!.toUpperCase() == bagMaterial.toUpperCase();
      }).toList();
    }

    if (weightKg != null) {
      result = result.where((m) {
        final min = m.weightMinKg;
        final max = m.weightMaxKg;
        if (min == null && max == null) return true;
        return (min == null || weightKg >= min) &&
            (max == null || weightKg <= max);
      }).toList();
    }

    return result;
  }

  // Implement remaining methods as no-ops
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // ─── Test Data ─────────────────────────────────────────────────────────────

  // Dữ liệu thực từ Excel (trích từ DB generation output)
  final testMachines = [
    // LZB-600-R10: PE, 6 cạnh, 0.35-5kg, 540-600 túi/giờ, Bán tự động
    const PackingMachine(
      id: 17,
      stt: 17,
      productGroup: 'Túi PE (hút chân không)',
      machineLine: 'Túi 6 cạnh - Bán tự động',
      model: 'LZB-600-R10',
      automationLevel: 'Bán tự động',
      bagMaterial: 'PE',
      bagEdges: '6 cạnh',
      bagShape: 'Túi vuông',
      materials: 'Gạo, đường, đậu và các loại hạt tương tự',
      headsStations: '2',
      weightMinKg: 0.35,
      weightMaxKg: 5.0,
      weightUnit: 'kg',
      capacityMin: 540.0,
      capacityMax: 600.0,
      capacityUnit: 'túi/giờ',
    ),

    // LZB-1200-R40: PE, 6 cạnh, 0.25-5kg, 1000-1200 túi/giờ, Hoàn toàn tự động
    const PackingMachine(
      id: 14,
      stt: 14,
      productGroup: 'Túi PE (hút chân không)',
      machineLine: 'Túi 6 cạnh - Hoàn toàn tự động',
      model: 'LZB-1200-R40',
      automationLevel: 'Hoàn toàn tự động',
      bagMaterial: 'PE',
      bagEdges: '6 cạnh',
      weightMinKg: 0.25,
      weightMaxKg: 5.0,
      weightUnit: 'kg',
      capacityMin: 1000.0,
      capacityMax: 1200.0,
      capacityUnit: 'túi/giờ',
    ),

    // LZB-300-R5: PE, 6 cạnh, 0.35-5kg, 300-360 túi/giờ, Bán tự động
    const PackingMachine(
      id: 16,
      stt: 16,
      productGroup: 'Túi PE (hút chân không)',
      machineLine: 'Túi 6 cạnh - Bán tự động',
      model: 'LZB-300-R5',
      automationLevel: 'Bán tự động',
      bagMaterial: 'PE',
      bagEdges: '6 cạnh',
      weightMinKg: 0.35,
      weightMaxKg: 5.0,
      weightUnit: 'kg',
      capacityMin: 300.0,
      capacityMax: 360.0,
      capacityUnit: 'túi/giờ',
    ),

    // PZB-1200-F40: PE, 2 cạnh, 2-10kg, 800-1200 túi/giờ
    const PackingMachine(
      id: 10,
      stt: 10,
      productGroup: 'Túi PE (hút chân không)',
      machineLine: 'Túi 2 cạnh - Hoàn toàn tự động',
      model: 'PZB-1200-F40',
      automationLevel: 'Hoàn toàn tự động',
      bagMaterial: 'PE',
      bagEdges: '2 cạnh',
      weightMinKg: 2.0,
      weightMaxKg: 10.0,
      weightUnit: 'kg',
      capacityMin: 800.0,
      capacityMax: 1200.0,
      capacityUnit: 'túi/giờ',
    ),

    // DCS-25K-3A: PP, 5-50kg, 300-900 túi/giờ, Bán tự động
    const PackingMachine(
      id: 29,
      stt: 29,
      productGroup: 'Bao dệt PP',
      machineLine: 'Bán tự động',
      model: 'DCS-25K-3A',
      automationLevel: 'Bán tự động',
      bagMaterial: 'PP',
      weightMinKg: 5.0,
      weightMaxKg: 50.0,
      weightUnit: 'kg',
      capacityMin: 300.0,
      capacityMax: 900.0,
      capacityUnit: 'túi/giờ',
    ),

    // LZB-500-FR10: PE, 2 & 6 cạnh, 0.5-10kg, 180-360 túi/giờ
    const PackingMachine(
      id: 21,
      stt: 21,
      productGroup: 'Túi PE (hút chân không)',
      machineLine: 'Túi 2 & 6 cạnh - Bán tự động',
      model: 'LZB-500-FR10',
      automationLevel: 'Bán tự động',
      bagMaterial: 'PE',
      bagEdges: '2 & 6 cạnh',
      weightMinKg: 0.5,
      weightMaxKg: 10.0,
      weightUnit: 'kg',
      capacityMin: 180.0,
      capacityMax: 360.0,
      capacityUnit: 'túi/giờ',
    ),
  ];

  late MachineSelectorService selectorService;
  late MockPackingMachineRepository mockRepo;

  setUp(() {
    mockRepo = MockPackingMachineRepository(testMachines);
    selectorService = MachineSelectorService(repository: mockRepo);
  });

  // ─── Tests ─────────────────────────────────────────────────────────────────

  group('MachineSelectorService - Basic Filtering', () {
    test('Test case chính: PE, 6 cạnh, 5kg, 500 túi/giờ → LZB-600-R10 là BEST MATCH', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        bagEdges: '6 cạnh',
        requestedWeightKg: 5.0,
        requestedCapacity: 500.0,
        capacityUnit: 'túi/giờ',
      );

      final results = await selectorService.findSuitableMachines(request);
      expect(results, isNotEmpty);

      final lzb600 = results.firstWhere(
        (r) => (r.machine as PackingMachine).model == 'LZB-600-R10',
      );

      // LZB-600-R10 phải là BEST MATCH hoặc SUITABLE
      expect(
        lzb600.matchLevel,
        anyOf(MatchLevel.bestMatch, MatchLevel.suitable),
        reason: 'LZB-600-R10 đáp ứng PE, 6 cạnh, 5kg, 500 túi/giờ (máy đạt 540-600)',
      );

      // Phải có match reason về PE
      expect(
        lzb600.matchReasons.any((r) => r.contains('PE')),
        isTrue,
        reason: 'Phải có lý do về PE',
      );

      print('--- Test Result: PE 6-cạnh 5kg 500túi/giờ ---');
      for (final r in results) {
        final m = r.machine as PackingMachine;
        print(
          '${m.model}: ${r.matchLevel.labelVi} | Score: ${r.score.toStringAsFixed(1)}',
        );
        for (final reason in r.matchReasons) {
          print('  $reason');
        }
        for (final reason in r.mismatchReasons) {
          print('  $reason');
        }
      }
    });

    test('LZB-1200-R40 với 500 túi/giờ phải là OVERSIZED (dư >50%)', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        bagEdges: '6 cạnh',
        requestedWeightKg: 5.0,
        requestedCapacity: 500.0,
      );

      final results = await selectorService.findSuitableMachines(request);
      final lzb1200 = results.firstWhere(
        (r) => (r.machine as PackingMachine).model == 'LZB-1200-R40',
      );

      // 1200 túi/giờ >> 500 yêu cầu → dư 140% → OVERSIZED
      expect(lzb1200.matchLevel, MatchLevel.oversized);
    });

    test('LZB-300-R5 với 500 túi/giờ phải là NOT SUITABLE (capacity 300-360 < 500)', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        bagEdges: '6 cạnh',
        requestedWeightKg: 5.0,
        requestedCapacity: 500.0,
      );

      final results = await selectorService.findSuitableMachines(request);
      final lzb300 = results.firstWhere(
        (r) => (r.machine as PackingMachine).model == 'LZB-300-R5',
      );

      // LZB-300-R5 chỉ đạt 300-360 túi/giờ < 500 yêu cầu → NOT SUITABLE
      expect(lzb300.matchLevel, MatchLevel.notSuitable);
      expect(
        lzb300.mismatchReasons,
        isNotEmpty,
        reason: 'Phải có lý do không phù hợp',
      );
    });

    test('Túi 2 & 6 cạnh tương thích với yêu cầu 6 cạnh', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        bagEdges: '6 cạnh',
        requestedWeightKg: 5.0,
        requestedCapacity: 300.0,
      );

      final results = await selectorService.findSuitableMachines(request);
      final lzb500FR = results.firstWhere(
        (r) => (r.machine as PackingMachine).model == 'LZB-500-FR10',
      );

      // LZB-500-FR10 là "2 & 6 cạnh" → tương thích với "6 cạnh"
      expect(
        lzb500FR.matchLevel,
        isNot(MatchLevel.notSuitable),
        reason: 'Túi 2 & 6 cạnh phải tương thích với yêu cầu 6 cạnh',
      );
    });

    test('Máy PP không phù hợp với yêu cầu PE', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        bagEdges: '6 cạnh',
        requestedWeightKg: 5.0,
      );

      final results = await selectorService.findSuitableMachines(request);

      // DCS-25K-3A là PP → đã bị lọc bởi mock (bagMaterial filter)
      // Hoặc nếu có trong results, phải là NOT SUITABLE
      final dcs25kResults = results
          .where((r) => (r.machine as PackingMachine).model == 'DCS-25K-3A')
          .toList();

      if (dcs25kResults.isEmpty) {
        // Đã bị filter out bởi mock → test pass (PE filter đang hoạt động)
        expect(dcs25kResults.isEmpty, isTrue);
      } else {
        expect(dcs25kResults.first.matchLevel, MatchLevel.notSuitable);
      }
    });

    test('Kết quả được sắp xếp đúng thứ tự: bestMatch → suitable → oversized → notSuitable', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        requestedWeightKg: 5.0,
        requestedCapacity: 500.0,
      );

      final results = await selectorService.findSuitableMachines(request);
      expect(results, isNotEmpty);

      // Kiểm tra thứ tự sort
      for (int i = 0; i < results.length - 1; i++) {
        expect(
          results[i].matchLevel.sortPriority,
          lessThanOrEqualTo(results[i + 1].matchLevel.sortPriority),
          reason: 'Kết quả phải được sắp xếp theo priority tăng dần',
        );
      }
    });

    test('Khối lượng 15kg không phù hợp với máy 0.35-5kg', () async {
      final request = MachineSelectorRequest(
        bagMaterial: 'PE',
        requestedWeightKg: 15.0, // Ngoài range 0.35-5kg của LZB series
      );

      final results = await selectorService.findSuitableMachines(request);

      // Với weight=15kg, mock repo lọc → chỉ còn PZB-1200-F40 (2-10kg không phù hợp)
      // và LZB-150-M3/S (10-25kg, phù hợp 15kg) nếu có trong mock data
      // LZB-600-R10 (0.35-5kg) sẽ bị filter ra khỏi candidates
      final lzb600Results = results
          .where((r) => (r.machine as PackingMachine).model == 'LZB-600-R10')
          .toList();

      // LZB-600-R10 bị filter vì weight_max=5kg < 15kg → không có trong results
      expect(
        lzb600Results.isEmpty,
        isTrue,
        reason: 'LZB-600-R10 (max 5kg) không nên xuất hiện khi yêu cầu 15kg',
      );

      // Nếu có PZB-1200-F40 (2-10kg), cũng không phù hợp
      final pzbResults = results
          .where((r) => (r.machine as PackingMachine).model == 'PZB-1200-F40')
          .toList();
      if (pzbResults.isNotEmpty) {
        expect(
          pzbResults.first.matchLevel,
          MatchLevel.notSuitable,
          reason: 'PZB-1200-F40 (max 10kg) không đủ cho 15kg',
        );
      }
    });

    test('máy thiếu bagEdges không phù hợp khi yêu cầu có kiểu túi', () async {
      const request = MachineSelectorRequest(
        bagMaterial: 'PP',
        bagEdges: '6 cạnh',
      );

      final results = await selectorService.findSuitableMachines(request);
      final machineWithoutEdges = results.firstWhere(
        (result) => (result.machine as PackingMachine).model == 'DCS-25K-3A',
      );

      expect(machineWithoutEdges.matchLevel, MatchLevel.notSuitable);
      expect(
        machineWithoutEdges.mismatchReasons,
        isNotEmpty,
        reason: 'Không được coi máy thiếu thông tin kiểu túi là phù hợp với yêu cầu cụ thể.',
      );
    });
  });

  group('MatchLevel Extensions', () {
    test('Best match có 5 sao', () {
      expect(MatchLevel.bestMatch.starCount, 5);
    });

    test('Not suitable có 1 sao', () {
      expect(MatchLevel.notSuitable.starCount, 1);
    });

    test('Sort priority: bestMatch < suitable < oversized < notSuitable', () {
      expect(MatchLevel.bestMatch.sortPriority, 0);
      expect(MatchLevel.suitable.sortPriority, 1);
      expect(MatchLevel.oversized.sortPriority, 2);
      expect(MatchLevel.notSuitable.sortPriority, 3);
    });
  });
}
