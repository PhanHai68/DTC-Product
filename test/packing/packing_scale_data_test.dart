import 'dart:io';

import 'package:dtc_product/models/packing_feature.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repository = PackingMachineRepository();

  test(
    'tìm được từ khoá tiếng Việt có dấu, không phân biệt hoa thường',
    () async {
      // Bản SQLite cũ không viết hoa được chữ có dấu nên "túi" ra 0 kết quả.
      final lower = await repository.searchMachines('túi');
      final upper = await repository.searchMachines('TÚI');
      expect(lower, isNotEmpty);
      expect(upper.map((m) => m.model), lower.map((m) => m.model));
      expect(await repository.searchMachines('bao dệt pp'), isNotEmpty);
    },
  );

  test('tìm kiếm xếp máy khớp model lên trước', () async {
    final results = await repository.searchMachines('LCS');
    final firstNonModel = results.indexWhere(
      (m) => !m.model.toUpperCase().contains('LCS'),
    );
    if (firstNonModel != -1) {
      expect(
        results
            .skip(firstNonModel)
            .every((m) => !m.model.toUpperCase().contains('LCS')),
        isTrue,
      );
    }
    expect(results.first.model, startsWith('LCS'));
  });

  test('dữ liệu cân đóng gói từ JSON có thể đọc và tra cứu', () async {
    final machines = await repository.getAllMachines();
    final groups = await repository.getDistinctProductGroups();
    final bagMaterials = await repository.getDistinctBagMaterials();

    expect(machines, isNotEmpty);
    expect(groups, isNotEmpty);
    expect(bagMaterials, isNotEmpty);

    final results = await repository.searchMachines('LZB-600');
    expect(results, isNotEmpty);
    expect(results.any((machine) => machine.model.contains('LZB-600')), isTrue);
  });

  test('dữ liệu chỉ có đúng 3 kiểu túi', () async {
    final bagEdges = await repository.getDistinctBagEdges();

    expect(bagEdges, hasLength(3));
    expect(bagEdges.toSet(), equals({'2 cạnh', '6 cạnh', '2 & 6 cạnh'}));
  });

  test('mọi máy có khai báo kiểu túi đều dùng vật liệu PE', () async {
    final machines = await repository.getAllMachines();
    final machinesWithBagEdges = machines.where(
      (machine) => machine.bagEdges?.trim().isNotEmpty ?? false,
    );

    expect(machinesWithBagEdges, isNotEmpty);
    expect(
      machinesWithBagEdges.every(
        (machine) => machine.bagMaterial?.toUpperCase() == 'PE',
      ),
      isTrue,
    );
  });

  test('51 model đều có icon, ảnh nền và catalog tiếng Việt hợp lệ', () async {
    final machines = await repository.getAllMachines();

    // 46 model DTC + 5 model APACK (R-APF-18, R-AP50/60-250, R-AP10-1200,
    // R-AP50-1000).
    expect(machines, hasLength(51));
    for (final machine in machines) {
      expect(
        machine.imageMainPath,
        isNotNull,
        reason: '${machine.model} thiếu icon',
      );
      expect(
        File(machine.imageMainPath!).existsSync(),
        isTrue,
        reason: '${machine.model} trỏ tới icon không tồn tại',
      );
      expect(
        machine.image2Path,
        isNotNull,
        reason: '${machine.model} thiếu ảnh nền',
      );
      expect(
        File(machine.image2Path!).existsSync(),
        isTrue,
        reason: '${machine.model} trỏ tới ảnh nền không tồn tại',
      );
      // Catalog nằm trên Google Drive, app tìm theo tên file (phần cuối
      // đường dẫn) nên chỉ kiểm tra tên file PDF hợp lệ.
      // Model hãng khác (có `brand`) dùng catalog của hãng đó, hoặc chưa có
      // catalog PDF (chỉ có tờ rơi dạng ảnh).
      if (machine.brand == null || machine.catalogAssetPath != null) {
        expect(
          machine.catalogAssetPath!.split('/').last,
          machine.brand == null
              ? matches(RegExp(r'^DTC-Packing-.+\.pdf$'))
              : endsWith('.pdf'),
          reason: '${machine.model} trỏ tới catalog không hợp lệ',
        );
      }
      expect(
        packingFeaturesFor(machine),
        isNotEmpty,
        reason: '${machine.model} chưa có đặc điểm nổi bật',
      );
    }
  });

  test('số đặc điểm của hai dòng định lượng đúng mẫu fix 4', () async {
    final riceMixer = await repository.getMachineByModel('LCJ-10T-8');
    final flowScale = await repository.getMachineByModel('LCS-18T');

    expect(packingFeaturesFor(riceMixer!), hasLength(6));
    expect(packingFeaturesFor(flowScale!), hasLength(4));
    expect(flowScale.detailImagePaths.first, flowScale.image2Path);
  });

  test('4 model APACK nằm trong Bao dệt PP → Bán tự động', () async {
    final expected = {
      // model: (khối lượng hiển thị, năng suất hiển thị, sai số, kích thước)
      'R-AP50-250': (
        '5 - 50 kg (gạo)\n5 - 40 kg (lúa)',
        '220 - 280 túi/h (gạo)\n180 - 220 túi/h (lúa)',
        '≤ ±10 g',
        '1192 × 980 × 2382 mm',
      ),
      'R-AP60-250': (
        '5 - 60 kg (gạo)\n5 - 50 kg (lúa)',
        '220 - 280 túi/h (gạo)\n180 - 220 túi/h (lúa)',
        '≤ ±10 g',
        '1192 × 980 × 2732 mm',
      ),
      'R-AP10-1200': ('1 - 10 kg', '800 - 1200 túi/giờ', '≤ 5 g', '1545 × 628 × 2315 mm'),
      'R-AP50-1000': ('25 - 50 kg', '800 - 1200 túi/giờ', '≤ 10 g', '1995 × 1020 × 3233 mm'),
    };
    for (final MapEntry(key: model, value: v) in expected.entries) {
      final machine = await repository.getMachineByModel(model);
      expect(machine, isNotNull, reason: model);
      expect(machine!.productGroup, 'Bao dệt PP', reason: model);
      expect(machine.machineLine, 'Bán tự động', reason: model);
      expect(machine.brand, 'APACK', reason: model);
      expect(machine.weightRangeText, v.$1, reason: model);
      expect(machine.capacityRangeText, v.$2, reason: model);
      expect(machine.accuracy, v.$3, reason: model);
      expect(machine.dimensionText, v.$4, reason: model);
      expect(machine.components, hasLength(6), reason: model);
      expect(packingFeaturesFor(machine), isNotEmpty, reason: model);
    }
  });

  test('R-APF-18 (APACK) theo catalog hãng, nằm trong Cân lưu lượng', () async {
    final machine = await repository.getMachineByModel('R-APF-18');

    expect(machine, isNotNull);
    expect(machine!.machineLine, 'Cân lưu lượng');
    expect(machine.brand, 'APACK');
    expect(machine.capacityMax, 18);
    expect(machine.capacityRangeText, '18 tấn/h');
    expect(machine.notes, isNull);
    expect(machine.batchWeightMaxKg, 65);
    expect(machine.accuracy, '±50 g/mẻ');
    expect(machine.powerKw, 0.2);
    expect(machine.dimensionText, '1080 × 760 × 1916 mm');
    expect(machine.components, hasLength(6));
    expect(packingFeaturesFor(machine), hasLength(7));
    expect(File(machine.diagramImagePath!).existsSync(), isTrue);
  });
}
