import 'package:dtc_product/core/database/local_database.dart';
import 'package:dtc_product/models/maintenance_record.dart';
import 'package:dtc_product/models/sample_record.dart';
import 'package:dtc_product/repositories/sample_record_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web giữ và đọc lại được byte ảnh lưu mẫu', () async {
    if (!kIsWeb) return;
    final repository = LocalSampleRecordRepository();
    final original = List<int>.generate(32, (index) => index);

    final path = await repository.persistPhoto(
      'camera-photo.jpg',
      SampleStreamType.rawMaterial,
      bytes: original,
    );
    final restored = await repository.readPhoto(path);

    expect(path, startsWith('data:image/jpeg;base64,'));
    expect(restored, orderedEquals(original));
  });

  test('Web tạo, đọc và xóa được bản ghi bảo trì', () async {
    if (!kIsWeb) return;
    final database = LocalDatabase.instance;
    final id = await database.insertMaintenanceRecord(
      MaintenanceRecord(
        customerName: 'DTC Web Storage Test',
        machineModel: 'TEST-ONLY',
        installDate: DateTime(2026, 1, 31),
        maintenanceCycleMonths: 1,
        nextMaintenanceDate: DateTime(2026, 2, 28),
      ),
    );

    try {
      final records = await database.getAllMaintenanceRecords();
      expect(records.any((record) => record.id == id), isTrue);
    } finally {
      await database.deleteMaintenanceRecord(id);
      await database.close();
    }
  });
}
