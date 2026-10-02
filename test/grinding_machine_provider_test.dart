import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late GrindingMachineRepository repository;
  late GrindingMachineProvider provider;
  Map<String, dynamic> updated() {
    final root = jsonDecode(File('assets/database/grinding_machine_seed.json').readAsStringSync()) as Map<String, dynamic>;
    root['databaseVersion'] = '2.3';
    root['models'][0]['capacityMaxKgH'] = 350;
    return root;
  }
  Uint8List bytes(Map<String, dynamic> root) => Uint8List.fromList(utf8.encode(jsonEncode(root)));

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await GrindingMachineDatabase.instance.createSchemaForTesting(db);
    repository = GrindingMachineRepository(database: GrindingMachineDatabase.forTesting(db));
    provider = GrindingMachineProvider(repository: repository);
    await provider.loadHome();
  });
  tearDown(() async { provider.dispose(); await db.close(); });

  test('Preview không ghi DB; apply làm mới cache và không bị seed ghi đè sau mở lại', () async {
    final preview = await provider.previewImport('new.json', bytes(updated()));
    expect(preview.report.canImport, isTrue);
    expect(preview.updated, contains('ASC_COARSE__ASC-200'));
    expect((await repository.getMachineByModel('ASC-200'))!.capacityMaxKgH, 300);
    await Future.wait([provider.applyImport(preview), provider.loadHome()]);
    expect(provider.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH, 350);
    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();
    expect(reopened.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH, 350);
    expect(await repository.getImportedDatabaseVersion(), '2.3');
  });

  test('Preview thống kê thêm/xóa/inactive và cập nhật đủ dữ liệu con', () async {
    final root = updated();
    final removed = (root['models'] as List).removeAt(0) as Map<String, dynamic>;
    (root['models'] as List).add({...removed, 'machineId': 'ASC_COARSE__ASC-NEW', 'model': 'ASC-NEW'});
    root['models'][0]['active'] = false;
    root['selectionTags'][0]['tag'] = 'updated_tag';
    root['extraSpecs'][0]['specValueNumber'] = 222;
    root['series'][0]['nameVi'] = 'Tên cập nhật';
    root['materials'][0]['nameVi'] = 'Vừng cập nhật';
    root['materialSeriesMap'][0]['scoreAdjustment'] = 10;
    root['aiConfig'][0]['value'] = 35;
    final preview = await provider.previewImport('catalog.json', bytes(root));
    expect(preview.added, ['ASC_COARSE__ASC-NEW']);
    expect(preview.removed, ['ASC_COARSE__ASC-200']);
    await provider.applyImport(preview);
    expect(await repository.getMachineById('ASC_COARSE__ASC-200'), isNull);
    expect(await repository.getMachineById('ASC_COARSE__ASC-NEW'), isNotNull);
    expect(provider.machines.any((m) => m.model == 'ASC-300'), isFalse);
    expect(provider.series.firstWhere((s) => s.seriesCode == 'ASC_COARSE').nameVi, 'Tên cập nhật');
    expect((await repository.getSelectionTags('ASC_COARSE')).any((t) => t.tag == 'updated_tag'), isTrue);
    expect((await repository.getExtraSpecs(root['extraSpecs'][0]['machineId'])).first.specValueNumber, 222);
    expect((await repository.getMaterialById('SESAME'))!.nameVi, 'Vừng cập nhật');
    expect((await repository.getMaterialSeriesMapFor('SESAME')).first.scoreAdjustment, 10);
    expect((await repository.getAiConfigByKey('capacity_weight'))!.asNum, 35);
  });

  test('Cùng version cần lưu ý; version thấp hơn và file lỗi không được apply', () async {
    final root = updated()..['databaseVersion'] = '2.2.3';
    final same = await provider.previewImport('same.json', bytes(root));
    expect(same.report.canImport, isTrue);
    expect(same.report.issues.any((v) => v.message.contains('cùng phiên bản')), isTrue);
    root['databaseVersion'] = '2.0';
    final old = await provider.previewImport('old.json', bytes(root));
    expect(old.report.canImport, isFalse);
    await expectLater(provider.applyImport(old), throwsStateError);
    final bad = await provider.previewImport('empty.json', bytes({}));
    await expectLater(provider.applyImport(bad), throwsStateError);
    expect(await repository.getImportedDatabaseVersion(), '2.2.3');
    expect(provider.machines, hasLength(57));
  });

  test(
    'Thiết bị có importOrigin cũ khác "seed" (từ lần import file thủ công '
    'trước khi màn Database Update bị gỡ) vẫn phải tự nhận seed mới khi '
    'version tăng — không được kẹt vĩnh viễn ở dữ liệu cũ',
    () async {
      // Mô phỏng 1 thiết bị đã cài app trước đây: catalog hiện có origin
      // 'file' (từ lần dùng màn Database Update cũ) và version THẤP HƠN
      // seed đóng gói hiện tại. Ghi thẳng vào bảng meta (không qua
      // `importSnapshot`) vì đây là trạng thái đĩa CÓ SẴN từ 1 bản app cũ,
      // không phải 1 thao tác nghiệp vụ đang diễn ra — `importSnapshot` sẽ
      // (đúng) chặn hạ version nếu gọi qua nó ở đây.
      await db.update('grinding_db_meta', {'value': '1.0'}, where: 'key = ?', whereArgs: ['databaseVersion']);
      await db.update('grinding_db_meta', {'value': 'file'}, where: 'key = ?', whereArgs: ['importOrigin']);
      expect((await repository.getImportMetadata())['importOrigin'], 'file');
      expect(await repository.getImportedDatabaseVersion(), '1.0');

      // Mở lại Home (như user mở app sau khi cài bản mới) -> PHẢI tự nâng
      // lên seed đóng gói mới nhất, bất kể importOrigin cũ là gì.
      final reopened = GrindingMachineProvider(repository: repository);
      addTearDown(reopened.dispose);
      await reopened.loadHome();

      expect(await repository.getImportedDatabaseVersion(), isNot('1.0'));
      expect(reopened.machines, hasLength(57));
      expect(reopened.series.every((s) => !s.seriesCode.startsWith('B')), isTrue);
    },
  );

  test('Thiết bị đang ở catalog 2.2.2 tự nhận tên tiếng Việt mới từ seed 2.2.3', () async {
    await db.update(
      'grinding_series',
      {'nameVi': 'Máy nghiền búa tốc độ cao dạng nhỏ'},
      where: 'seriesCode = ?',
      whereArgs: ['AS_SMALL_HAMMER'],
    );
    await db.update(
      'grinding_db_meta',
      {'value': '2.2.2'},
      where: 'key = ?',
      whereArgs: ['databaseVersion'],
    );

    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();

    expect(await repository.getImportedDatabaseVersion(), '2.2.3');
    final names = {
      for (final series in reopened.series) series.seriesCode: series.nameVi,
    };
    expect(names['ASZ_PIN'], 'Máy nghiền chốt');
    expect(names['ASDF_MULTISTAGE'], 'Máy nghiền búa tiên tiến');
    expect(names['AS_SMALL_HAMMER'], 'Máy nghiền búa cỡ nhỏ');
    expect(names['ASF_AS_HAMMER'], 'Máy nghiền hiệu suất cao');
    expect(names['ASU_UNIVERSAL'], 'Máy nghiền đa năng');
    expect(names['ASG_UNIVERSAL_SYSTEM'], 'Máy nghiền tự hút dạng rời');
    expect(names['AS_ROLLER'], 'Máy nghiền gia vị');
    expect(names['ASP_ULTRAFINE'], 'Máy nghiền siêu mịn');
    expect(names['AS_CRYOGENIC'], 'Máy nghiền lạnh sâu');
    expect(names['ASC_COARSE'], 'Máy nghiền thô');
  });

  test('Lỗi import không chặn thao tác tiếp theo trong hàng đợi', () async {
    final stale = await provider.previewImport('first.json', bytes(updated()));
    final fresh = await provider.previewImport('second.json', bytes(updated()));
    await provider.applyImport(fresh);
    await expectLater(provider.applyImport(stale), throwsStateError);
    await provider.loadHome();
    expect(provider.error, isNull);
    expect(provider.machines, hasLength(57));
  });
}
