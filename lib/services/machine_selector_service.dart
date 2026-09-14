/// Service xử lý logic chọn máy phù hợp (rule-based filtering + ranking).
/// Không dùng AI, chỉ dùng rules từ thông số kỹ thuật.
///
/// Logic ranking:
/// - BEST MATCH: Tất cả điều kiện thỏa mãn, capacity gần nhất với yêu cầu
/// - SUITABLE:   Tất cả điều kiện thỏa mãn, dư capacity < 50%
/// - OVERSIZED:  Tất cả điều kiện thỏa mãn, dư capacity ≥ 50%
/// - NOT SUITABLE: Không thỏa mãn ít nhất một điều kiện bắt buộc

import '../models/packing_machine.dart';
import '../models/machine_selector_request.dart';
import '../models/machine_match_result.dart';
import '../repositories/packing_machine_repository.dart';

class MachineSelectorService {
  final PackingMachineRepository _repository;

  MachineSelectorService({PackingMachineRepository? repository})
    : _repository = repository ?? PackingMachineRepository();

  /// Tìm và rank tất cả máy phù hợp với yêu cầu.
  /// Trả về list đã được sắp xếp theo mức phù hợp.
  Future<List<MachineMatchResult>> findSuitableMachines(
    MachineSelectorRequest request,
  ) async {
    // Lấy ứng viên ban đầu (pre-filter nhẹ bằng DB query)
    final candidates = await _repository.getMachinesForSelector(
      bagMaterial: request.bagMaterial,
      weightKg: request.requestedWeightKg,
    );

    // Rank từng máy
    final results = candidates.map((machine) {
      return _evaluateMachine(machine, request);
    }).toList();

    // Sắp xếp: theo matchLevel priority → score giảm dần (cao = tốt hơn)
    results.sort((a, b) {
      final levelCmp = a.matchLevel.sortPriority.compareTo(
        b.matchLevel.sortPriority,
      );
      if (levelCmp != 0) return levelCmp;
      return b.score.compareTo(a.score); // score cao hơn = tốt hơn
    });

    return results;
  }

  // ─── Core Evaluation Logic ─────────────────────────────────────────────────

  MachineMatchResult _evaluateMachine(
    PackingMachine machine,
    MachineSelectorRequest request,
  ) {
    final matchReasons = <String>[];
    final mismatchReasons = <String>[];
    bool isCompatible = true;

    // ── 1. Kiểm tra vật liệu túi ───────────────────────────────────────────
    if (request.bagMaterial != null && request.bagMaterial!.isNotEmpty) {
      final machineMaterial = machine.bagMaterial;
      if (machineMaterial == null || machineMaterial.isEmpty) {
        // Máy không có thông tin túi → không thể xác nhận
        mismatchReasons.add('✗ Không có thông tin loại bao');
        isCompatible = false;
      } else if (machineMaterial.toUpperCase() ==
          request.bagMaterial!.toUpperCase()) {
        matchReasons.add('✓ Phù hợp bao ${request.bagMaterial}');
      } else {
        mismatchReasons.add(
          '✗ Bao ${machine.bagMaterial} (yêu cầu ${request.bagMaterial})',
        );
        isCompatible = false;
      }
    }

    // ── 2. Kiểm tra kiểu túi (bag_edges) ──────────────────────────────────
    if (request.bagEdges != null && request.bagEdges!.isNotEmpty) {
      final machineEdges = machine.bagEdges;
      if (machineEdges == null || machineEdges.isEmpty) {
        mismatchReasons.add('✗ Không có thông tin kiểu túi');
        isCompatible = false;
      } else if (_isEdgesCompatible(machineEdges, request.bagEdges!)) {
        matchReasons.add('✓ Phù hợp túi ${request.bagEdges}');
      } else {
        mismatchReasons.add(
          '✗ Túi ${machine.bagEdges} (yêu cầu ${request.bagEdges})',
        );
        isCompatible = false;
      }
    }

    // ── 3. Kiểm tra mức độ tự động hóa ────────────────────────────────────
    if (request.automationLevel != null &&
        request.automationLevel!.isNotEmpty) {
      final machineAuto = machine.automationLevel;
      if (machineAuto != null && machineAuto.isNotEmpty) {
        if (machineAuto.toLowerCase() ==
            request.automationLevel!.toLowerCase()) {
          matchReasons.add('✓ ${request.automationLevel}');
        } else {
          mismatchReasons.add(
            '✗ $machineAuto (yêu cầu ${request.automationLevel})',
          );
          isCompatible = false;
        }
      }
    }

    // ── 4. Kiểm tra khối lượng ────────────────────────────────────────────
    double weightScore = 0;
    if (request.requestedWeightKg != null) {
      final w = request.requestedWeightKg!;
      final wMin = machine.weightMinKg;
      final wMax = machine.weightMaxKg;

      if (wMin == null && wMax == null) {
        // Không có thông tin khối lượng → bỏ qua điều kiện này
      } else if ((wMin == null || w >= wMin) && (wMax == null || w <= wMax)) {
        matchReasons.add(
          '✓ Phù hợp ${_formatNum(w)} ${machine.weightUnit ?? 'kg'}',
        );
        // Score: ưu tiên máy có range nhỏ hơn (fit chính xác hơn)
        final range = (wMax ?? w) - (wMin ?? 0);
        weightScore = range > 0 ? 100 / range : 100;
      } else {
        final msg = _formatNum(w);
        final unit = machine.weightUnit ?? 'kg';
        mismatchReasons.add(
          '✗ Khối lượng ${machine.weightMinKg ?? '?'} - '
          '${machine.weightMaxKg ?? '?'} $unit '
          '(yêu cầu $msg $unit)',
        );
        isCompatible = false;
      }
    }

    // ── 5. Kiểm tra năng suất ─────────────────────────────────────────────
    double capacityScore = 0;
    MatchLevel? capacityLevel;

    if (request.requestedCapacity != null) {
      final reqCap = request.requestedCapacity!;
      final capMax = machine.capacityMax;
      final capMin = machine.capacityMin;

      if (capMax == null) {
        // Không có thông tin năng suất → bỏ qua
      } else if (reqCap > capMax) {
        // Yêu cầu vượt quá năng suất tối đa
        mismatchReasons.add(
          '✗ Năng suất yêu cầu ${_formatNum(reqCap)}, '
          'máy đạt tối đa ${_formatNum(capMax)} ${machine.capacityUnit ?? ''}',
        );
        isCompatible = false;
      } else {
        // Máy đáp ứng được năng suất
        final capRange = (capMin != null && capMin > 0)
            ? '${_formatNum(capMin)}-${_formatNum(capMax)}'
            : _formatNum(capMax);
        matchReasons.add(
          '✓ Yêu cầu ${_formatNum(reqCap)} ${machine.capacityUnit ?? ''} '
          '/ Máy đạt $capRange ${machine.capacityUnit ?? ''}',
        );

        // Tính mức dư công suất
        final surplus = (capMax - reqCap) / reqCap;
        capacityScore = 100 - (surplus * 50).clamp(0, 100);

        if (surplus < 0.1) {
          capacityLevel = MatchLevel.bestMatch; // Gần nhất, dưới 10%
        } else if (surplus < 0.5) {
          capacityLevel = MatchLevel.suitable; // Dưới 50%
        } else {
          capacityLevel = MatchLevel.oversized; // Trên 50%
        }
      }
    }

    // ── Xác định Match Level tổng thể ─────────────────────────────────────
    MatchLevel finalLevel;
    if (!isCompatible) {
      finalLevel = MatchLevel.notSuitable;
    } else if (capacityLevel != null) {
      finalLevel = capacityLevel;
    } else {
      // Không có yêu cầu năng suất → dùng SUITABLE nếu compatible
      finalLevel = MatchLevel.suitable;
    }

    // Tổng score
    final totalScore = weightScore + capacityScore;

    return MachineMatchResult(
      machine: machine,
      matchLevel: finalLevel,
      matchReasons: matchReasons,
      mismatchReasons: mismatchReasons,
      score: totalScore,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Kiểm tra bag_edges có compatible với yêu cầu không
  /// Máy "2 & 6 cạnh" tương thích với cả "2 cạnh" và "6 cạnh"
  bool _isEdgesCompatible(String machineEdges, String requestEdges) {
    final m = machineEdges.toLowerCase().trim();
    final r = requestEdges.toLowerCase().trim();

    if (m == r) return true;

    // "2 & 6 cạnh" tương thích với cả "2 cạnh" và "6 cạnh"
    if (m.contains('2') && m.contains('6')) {
      return r.contains('2') || r.contains('6');
    }

    return false;
  }

  String _formatNum(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
