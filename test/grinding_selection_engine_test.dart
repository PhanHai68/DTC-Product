import 'dart:io';

import 'package:dtc_product/features/grinding_machine/models/grinding_selection_request.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_series.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_importer.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_selection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dựng GrindingSelectionContext trực tiếp từ snapshot đã parse (không cần
/// SQLite) — Engine thuần Dart nên test được với đúng dữ liệu thật trong
/// assets/database/grinding_machine_seed.json.
GrindingSelectionContext _contextFor(
  GrindingDatabaseSnapshot snapshot,
  String materialId,
) {
  final seriesByCode = <String, GrindingSeries>{
    for (final s in snapshot.series) s.seriesCode: s,
  };
  final seriesTags = <String, Set<String>>{};
  for (final t in snapshot.selectionTags) {
    (seriesTags[t.seriesCode] ??= {}).add(t.tag);
  }
  final materialScoreAdjustments = <String, double>{
    for (final m in snapshot.materialSeriesMap.where(
      (m) => m.isVerified && m.materialId == materialId,
    ))
      m.seriesCode: m.scoreAdjustment,
  };
  final weights = <String, num>{
    for (final c in snapshot.aiConfig)
      if (c.asNum != null) c.key: c.asNum!,
  };
  final material = snapshot.materials.firstWhere(
    (m) => m.materialId == materialId,
    orElse: () => throw StateError('materialId không có trong database'),
  );

  return GrindingSelectionContext(
    machines: snapshot.machines,
    seriesByCode: seriesByCode,
    seriesTags: seriesTags,
    materialScoreAdjustments: materialScoreAdjustments,
    materialName: material.nameVi,
    weights: weights,
  );
}

void main() {
  late GrindingDatabaseSnapshot snapshot;

  setUpAll(() {
    final jsonSource = File(
      'assets/database/grinding_machine_seed.json',
    ).readAsStringSync();
    snapshot = GrindingMachineImporter.parse(jsonSource);
  });

  test(
    'Khớp đúng ví dụ tính sẵn trong sheet AI_Selection_Test: '
    'capacity=1000kg/h, input=15mm, fineness=50 mesh, material=PEPPER',
    () {
      final context = _contextFor(snapshot, 'PEPPER');
      final results = GrindingSelectionEngine.recommend(
        context: context,
        request: const GrindingSelectionRequest(
          materialId: 'PEPPER',
          capacityKgH: 1000,
          finenessValue: 50,
          finenessUnit: 'mesh',
          inputSizeMm: 15,
        ),
      );

      // ASC-200/300/400 (BSC_COARSE, đơn vị fineness là "mm") phải bị loại
      // hoàn toàn dù công suất có thể khớp — sai đơn vị độ mịn là hard
      // filter theo đúng sheet Selection_Rules (TECH_FINENESS).
      expect(
        results.any((r) => r.machine.machineId.startsWith('BSC_COARSE__')),
        isFalse,
      );

      expect(results, hasLength(3)); // tối đa 3 đề xuất theo mục 7.
      for (final r in results) {
        expect(r.machine.seriesCode, 'BSG_UNIVERSAL_SYSTEM');
        expect(r.score, 100);
        expect(r.isStrongCandidate, isTrue);
        // PEPPER chưa có dòng Material_Series_Map đã xác minh -> phải có
        // cảnh báo, KHÔNG được tự suy đoán tương thích.
        expect(
          r.warnings.any((w) => w.contains('chưa có dữ liệu đã xác minh')),
          isTrue,
        );
      }
    },
  );

  test(
    'Nguyên liệu có dữ liệu xác minh (SESAME) cộng điểm và có lý do tương ứng',
    () {
      final context = _contextFor(snapshot, 'SESAME');
      // maxResults lớn để lấy hết ứng viên hợp lệ, tránh bị các model điểm
      // trùng (cùng chạm mốc 100 vì technical score đã đạt tối đa) chiếm hết
      // top 3 trước khi tới BS_ROLLER — mục tiêu bài test là xác nhận điểm/
      // lý do đúng, không phải thứ hạng giữa các model điểm bằng nhau.
      final results = GrindingSelectionEngine.recommend(
        context: context,
        request: const GrindingSelectionRequest(
          materialId: 'SESAME',
          capacityKgH: 500,
          finenessValue: 20,
          finenessUnit: 'mesh',
        ),
        maxResults: 100,
      );

      final rollerResult = results
          .where((r) => r.machine.seriesCode == 'BS_ROLLER')
          .toList();
      expect(rollerResult, isNotEmpty);
      expect(rollerResult.first.score, 100); // technical 100 + material +20, giới hạn 100.
      expect(
        rollerResult.first.reasons.any((r) => r.contains('Vừng')),
        isTrue,
      );
    },
  );

  test('Không có model nào đạt yêu cầu -> trả danh sách rỗng, không bịa', () {
    final context = _contextFor(snapshot, 'PEPPER');
    final results = GrindingSelectionEngine.recommend(
      context: context,
      request: const GrindingSelectionRequest(
        materialId: 'PEPPER',
        capacityKgH: 999999,
        finenessValue: 1,
        finenessUnit: 'mesh',
      ),
    );
    expect(results, isEmpty);
  });

  test('Kích thước đầu vào vượt giới hạn CÓ dữ liệu -> loại model đó', () {
    final context = _contextFor(snapshot, 'PEPPER');
    // ASC-200: input_size_max_mm = 100.
    final resultsOk = GrindingSelectionEngine.recommend(
      context: context,
      request: const GrindingSelectionRequest(
        materialId: 'PEPPER',
        capacityKgH: 200,
        finenessValue: 10,
        finenessUnit: 'mm',
        inputSizeMm: 90,
      ),
    );
    expect(
      resultsOk.any((r) => r.machine.machineId == 'BSC_COARSE__ASC-200'),
      isTrue,
    );

    final resultsTooBig = GrindingSelectionEngine.recommend(
      context: context,
      request: const GrindingSelectionRequest(
        materialId: 'PEPPER',
        capacityKgH: 200,
        finenessValue: 10,
        finenessUnit: 'mm',
        inputSizeMm: 500,
      ),
    );
    expect(
      resultsTooBig.any((r) => r.machine.machineId == 'BSC_COARSE__ASC-200'),
      isFalse,
    );
  });
}
