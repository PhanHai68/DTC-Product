import 'dart:io';

import 'package:dtc_product/features/grinding_machine/services/grinding_machine_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse đọc đúng số dòng từ grinding_machine_seed.json', () {
    final jsonSource = File(
      'assets/database/grinding_machine_seed.json',
    ).readAsStringSync();

    final snapshot = GrindingMachineImporter.parse(jsonSource);

    // Số dòng phải khớp CHÍNH XÁC với số dòng trong Excel gốc (57 model,
    // 11 dòng máy...) — không được rơi rớt hay bịa thêm dòng nào khi parse.
    expect(snapshot.databaseVersion, '1.1');
    expect(snapshot.sourceDocument, 'DTC-C-MayNghien-250426-demo4.pdf');
    expect(snapshot.series, hasLength(11));
    expect(snapshot.machines, hasLength(57));
    expect(snapshot.extraSpecs, hasLength(172));
    expect(snapshot.selectionTags, hasLength(88));
    expect(snapshot.materials, hasLength(14));
    expect(snapshot.materialSeriesMap, hasLength(11));
    expect(snapshot.aiConfig, hasLength(11));
  });

  test('parse giữ đúng giá trị null cho thông số Excel bỏ trống', () {
    final jsonSource = File(
      'assets/database/grinding_machine_seed.json',
    ).readAsStringSync();
    final snapshot = GrindingMachineImporter.parse(jsonSource);

    final asc200 = snapshot.machines.firstWhere(
      (m) => m.machineId == 'BSC_COARSE__ASC-200',
    );
    expect(asc200.capacityMinKgH, 80);
    expect(asc200.capacityMaxKgH, 300);
    expect(asc200.finenessUnit, 'mm');

    // Vật liệu "Tiêu" (PEPPER) chưa xác minh -> các cờ thuộc tính phải là
    // null (chưa biết), KHÔNG được suy diễn thành false.
    final pepper = snapshot.materials.firstWhere(
      (m) => m.materialId == 'PEPPER',
    );
    expect(pepper.isVerified, isFalse);
    expect(pepper.fibrous, isNull);
    expect(pepper.oily, isNull);
  });
}
