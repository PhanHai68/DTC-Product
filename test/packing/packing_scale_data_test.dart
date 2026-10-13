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

  test('46 model đều có icon, ảnh nền và catalog tiếng Việt hợp lệ', () async {
    final machines = await repository.getAllMachines();

    expect(machines, hasLength(46));
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
      expect(
        machine.catalogAssetPath!.split('/').last,
        matches(RegExp(r'^DTC-Packing-.+\.pdf$')),
        reason: '${machine.model} trỏ tới catalog không hợp lệ',
      );
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
}
