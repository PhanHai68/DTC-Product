import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _xlsxFixture = 'test/fixtures/grinding_machine/ai_ready.xlsx';

/// "Developer Catalog Update Regression" — thay thế cho
/// `grinding_database_update_screen_test.dart` (đã xóa cùng màn hình Update
/// Database trên UI production, theo yêu cầu điều chỉnh: catalog máy nghiền
/// từ nay CHỈ được cập nhật ở tầng developer, người dùng cuối không còn
/// chức năng tự cập nhật catalog trên điện thoại).
///
/// Test này KHÔNG pump bất kỳ Widget/Screen nào — gọi thẳng
/// `GrindingMachineProvider.previewImport()`/`applyImport()`, đúng API mà
/// developer/AI sẽ dùng khi cập nhật catalog từ file Excel người dùng cung
/// cấp trên PC (đọc file → previewImport → xác nhận diff → applyImport →
/// chạy test → build release). Đây chính là API cốt lõi phục vụ workflow
/// developer-side, vẫn được giữ nguyên vẹn trong provider dù UI đã gỡ.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GrindingMachineRepository> seededRepository(Database db) async {
    await GrindingMachineDatabase.instance.createSchemaForTesting(db);
    final repository = GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(db),
    );
    final seedProvider = GrindingMachineProvider(repository: repository);
    await seedProvider.loadHome();
    seedProvider.dispose();
    return repository;
  }

  test(
    'Excel master thật (.xlsx, 18 sheet) -> previewImport đúng số liệu, applyImport không mất dữ liệu',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      final repository = await seededRepository(db);
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.loadHome();

      final xlsxBytes = Uint8List.fromList(await File(_xlsxFixture).readAsBytes());
      final preview = await provider.previewImport('ai_ready.xlsx', xlsxBytes);

      // File Excel master khớp ĐÚNG với seed đã đóng gói -> preview phải
      // báo 0 thay đổi (không mất/lệch dữ liệu giữa Excel thật và JSON seed
      // trong app), null vẫn giữ null (không có issue "thiếu field" giả).
      expect(preview.report.canImport, isTrue, reason: preview.report.issues.join('\n'));
      expect(preview.report.snapshot!.machines, hasLength(57));
      expect(preview.added, isEmpty);
      expect(preview.updated, isEmpty);
      expect(preview.removed, isEmpty);

      await provider.applyImport(preview);

      expect(await repository.getImportedDatabaseVersion(), '1.1');
      expect(await repository.getAllMachines(), hasLength(57));
    },
  );

  test(
    'JSON có thay đổi thật (1 model đổi thông số + version tăng) -> previewImport phát hiện đúng diff, applyImport ghi đúng',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      final repository = await seededRepository(db);
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.loadHome();

      final root =
          jsonDecode(await File('assets/database/grinding_machine_seed.json').readAsString())
              as Map<String, dynamic>;
      root['databaseVersion'] = '1.2';
      root['models'][0]['capacityMaxKgH'] = 350;
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(root)));

      final preview = await provider.previewImport('new.json', jsonBytes);

      expect(preview.updated, hasLength(1));
      expect(preview.currentVersion, '1.1');
      expect(preview.report.snapshot!.databaseVersion, '1.2');

      await provider.applyImport(preview);

      expect(await repository.getImportedDatabaseVersion(), '1.2');
      expect((await repository.getMachineByModel('ASC-200'))!.capacityMaxKgH, 350);
    },
  );

  test(
    'File cũ hơn database hiện tại -> previewImport báo lỗi, applyImport bị chặn (không cho hạ phiên bản)',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      final repository = await seededRepository(db);
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.loadHome();

      final root =
          jsonDecode(await File('assets/database/grinding_machine_seed.json').readAsString())
              as Map<String, dynamic>;
      root['databaseVersion'] = '1.0';
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(root)));

      final preview = await provider.previewImport('old.json', jsonBytes);

      expect(preview.report.canImport, isFalse);
      await expectLater(provider.applyImport(preview), throwsStateError);
      // Database không đổi sau khi bị chặn.
      expect(await repository.getImportedDatabaseVersion(), '1.1');
    },
  );
}
