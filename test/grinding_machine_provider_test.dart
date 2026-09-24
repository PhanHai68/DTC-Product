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
    root['databaseVersion'] = '1.2';
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
    expect(preview.updated, contains('BSC_COARSE__ASC-200'));
    expect((await repository.getMachineByModel('ASC-200'))!.capacityMaxKgH, 300);
    await Future.wait([provider.applyImport(preview), provider.loadHome()]);
    expect(provider.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH, 350);
    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();
    expect(reopened.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH, 350);
    expect(await repository.getImportedDatabaseVersion(), '1.2');
  });

  test('Preview thống kê thêm/xóa/inactive và cập nhật đủ dữ liệu con', () async {
    final root = updated();
    final removed = (root['models'] as List).removeAt(0) as Map<String, dynamic>;
    (root['models'] as List).add({...removed, 'machineId': 'BSC_COARSE__ASC-NEW', 'model': 'ASC-NEW'});
    root['models'][0]['active'] = false;
    root['selectionTags'][0]['tag'] = 'updated_tag';
    root['extraSpecs'][0]['specValueNumber'] = 222;
    root['series'][0]['nameVi'] = 'Tên cập nhật';
    root['materials'][0]['nameVi'] = 'Vừng cập nhật';
    root['materialSeriesMap'][0]['scoreAdjustment'] = 10;
    root['aiConfig'][0]['value'] = 35;
    final preview = await provider.previewImport('catalog.json', bytes(root));
    expect(preview.added, ['BSC_COARSE__ASC-NEW']);
    expect(preview.removed, ['BSC_COARSE__ASC-200']);
    await provider.applyImport(preview);
    expect(await repository.getMachineById('BSC_COARSE__ASC-200'), isNull);
    expect(await repository.getMachineById('BSC_COARSE__ASC-NEW'), isNotNull);
    expect(provider.machines.any((m) => m.model == 'ASC-300'), isFalse);
    expect(provider.series.firstWhere((s) => s.seriesCode == 'BSC_COARSE').nameVi, 'Tên cập nhật');
    expect((await repository.getSelectionTags('BSC_COARSE')).any((t) => t.tag == 'updated_tag'), isTrue);
    expect((await repository.getExtraSpecs(root['extraSpecs'][0]['machineId'])).first.specValueNumber, 222);
    expect((await repository.getMaterialById('SESAME'))!.nameVi, 'Vừng cập nhật');
    expect((await repository.getMaterialSeriesMapFor('SESAME')).first.scoreAdjustment, 10);
    expect((await repository.getAiConfigByKey('capacity_weight'))!.asNum, 35);
  });

  test('Cùng version cần lưu ý; version thấp hơn và file lỗi không được apply', () async {
    final root = updated()..['databaseVersion'] = '1.1';
    final same = await provider.previewImport('same.json', bytes(root));
    expect(same.report.canImport, isTrue);
    expect(same.report.issues.any((v) => v.message.contains('cùng phiên bản')), isTrue);
    root['databaseVersion'] = '1.0';
    final old = await provider.previewImport('old.json', bytes(root));
    expect(old.report.canImport, isFalse);
    await expectLater(provider.applyImport(old), throwsStateError);
    final bad = await provider.previewImport('empty.json', bytes({}));
    await expectLater(provider.applyImport(bad), throwsStateError);
    expect(await repository.getImportedDatabaseVersion(), '1.1');
    expect(provider.machines, hasLength(57));
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
