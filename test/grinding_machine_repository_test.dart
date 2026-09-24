import 'dart:convert';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_importer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingMachineRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    repository = GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );

    final jsonSource = await rootBundle.loadString(
      'assets/database/grinding_machine_seed.json',
    );
    final snapshot = GrindingMachineImporter.parse(jsonSource);
    await repository.importSnapshot(snapshot);
  });

  tearDown(() async {
    await database.close();
  });

  test('importSnapshot nạp đúng số dòng series/machines vào SQLite', () async {
    final series = await repository.getAllSeries();
    final machines = await repository.getAllMachines();

    expect(series, hasLength(11));
    expect(machines, hasLength(57));
    expect(
      await repository.getImportedDatabaseVersion(),
      '1.1',
    );
  });

  test('getMachineByModel trả đúng thông số từ database, không bịa thêm', () async {
    final machine = await repository.getMachineByModel('ASP-350');

    expect(machine, isNotNull);
    expect(machine!.seriesCode, 'BSP_ULTRAFINE');
    // Không assert cứng số liệu cụ thể ở đây để tránh trùng lặp giả định với
    // Excel — chỉ xác nhận các trường bắt buộc có giá trị hợp lệ.
    expect(machine.capacityMinKgH, isNotNull);
    expect(machine.finenessUnit, isNotNull);
  });

  test('getMachineById/getMachineByModel trả về null khi không có trong database', () async {
    expect(await repository.getMachineById('NOT_EXIST'), isNull);
    expect(await repository.getMachineByModel('NOT_EXIST'), isNull);
  });

  test('searchMachines tìm theo model và theo tên dòng máy', () async {
    final byModel = await repository.searchMachines('ASP-350');
    expect(byModel, isNotEmpty);
    expect(byModel.every((m) => m.model.toUpperCase().contains('ASP-350')), isTrue);

    final byBrandName = await repository.searchMachines('siêu mịn');
    expect(byBrandName, isNotEmpty);
    expect(
      byBrandName.every((m) => m.seriesCode == 'BSP_ULTRAFINE'),
      isTrue,
    );
  });

  test('getExtraSpecs/getSelectionTags đọc đúng dữ liệu con theo machine/series', () async {
    final asg300 = await repository.getMachineByModel('ASG-300');
    expect(asg300, isNotNull);
    final specs = await repository.getExtraSpecs(asg300!.machineId);
    expect(specs, isNotEmpty);
    expect(specs.every((s) => s.machineId == asg300.machineId), isTrue);

    final tags = await repository.getSelectionTags('BSC_COARSE');
    expect(tags, isNotEmpty);
    expect(tags.map((t) => t.tag), contains('coarse'));
  });

  test('getAllMaterials/getMaterialSeriesMapFor chỉ trả dữ liệu có trong database', () async {
    final materials = await repository.getAllMaterials();
    expect(materials, hasLength(14));

    final sesameMap = await repository.getMaterialSeriesMapFor('SESAME');
    expect(sesameMap, hasLength(1));
    expect(sesameMap.first.seriesCode, 'BS_ROLLER');
    expect(sesameMap.first.isVerified, isTrue);

    // PEPPER không có trong Material_Series_Map -> phải trả về rỗng, KHÔNG
    // được tự suy đoán 1 dòng tương thích nào.
    final pepperMap = await repository.getMaterialSeriesMapFor('PEPPER');
    expect(pepperMap, isEmpty);
  });

  test('getAllAiConfig nạp đúng trọng số chấm điểm dùng cho Selection Engine sau này', () async {
    final capacityWeight = await repository.getAiConfigByKey('capacity_weight');
    final finenessWeight = await repository.getAiConfigByKey('fineness_weight');
    final threshold = await repository.getAiConfigByKey('candidate_threshold');

    expect(capacityWeight?.asNum, 40);
    expect(finenessWeight?.asNum, 40);
    expect(threshold?.asNum, 80);
  });

  test('importSnapshot chạy lại (re-import) thay thế sạch dữ liệu cũ, không cộng dồn', () async {
    final jsonSource = await rootBundle.loadString(
      'assets/database/grinding_machine_seed.json',
    );
    final snapshot = GrindingMachineImporter.parse(jsonSource);

    await repository.importSnapshot(snapshot);
    await repository.importSnapshot(snapshot);

    final machines = await repository.getAllMachines();
    expect(machines, hasLength(57));
  });

  Future<GrindingDatabaseSnapshot> changedSnapshot({String version = '1.2', String? model}) async {
    final root = jsonDecode(await rootBundle.loadString('assets/database/grinding_machine_seed.json')) as Map<String, dynamic>;
    root['databaseVersion'] = version;
    root['sourceDocument'] = null;
    if (model != null) root['models'][0]['model'] = model;
    return GrindingMachineImporter.parse(jsonEncode(root));
  }

  test('Rollback toàn bộ catalog và metadata khi SQLite lỗi giữa transaction', () async {
    final before = await repository.getImportMetadata();
    await database.execute("CREATE TRIGGER fail_import BEFORE INSERT ON grinding_machines WHEN NEW.model = 'FAIL' BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    final snapshot = await changedSnapshot(model: 'FAIL');
    await expectLater(repository.importSnapshot(snapshot), throwsA(isA<DatabaseException>()));
    expect(await repository.getImportMetadata(), before);
    expect(await repository.getAllMachines(), hasLength(57));
    expect(await repository.getMachineByModel('ASC-200'), isNotNull);
    expect(await repository.getMachineByModel('FAIL'), isNull);
  });

  test('Không ghi đè khi revision xem trước đã cũ', () async {
    final revision = (await repository.getImportMetadata())['importedAt'];
    final snapshot = await changedSnapshot();
    await repository.importSnapshot(snapshot);
    await expectLater(repository.importSnapshot(snapshot, expectedRevision: revision, checkRevision: true), throwsStateError);
    expect(await repository.getImportedDatabaseVersion(), '1.2');
  });

  test('Chặn hạ version ở repository và xóa metadata nguồn cũ khi nguồn mới null', () async {
    await repository.importSnapshot(await changedSnapshot(), fileName: 'new.json');
    final meta = await repository.getImportMetadata();
    expect(meta['sourceDocument'], isNull);
    expect(meta['fileName'], 'new.json');
    expect(meta['importOrigin'], 'file');
    await expectLater(repository.importSnapshot(await changedSnapshot(version: '1.1')), throwsStateError);
    expect(await repository.getImportedDatabaseVersion(), '1.2');
  });

  test('Snapshot rỗng qua API trực tiếp không xóa dữ liệu', () async {
    const empty = GrindingDatabaseSnapshot(databaseVersion: '1.2', series: [], machines: [], extraSpecs: [], selectionTags: [], materials: [], materialSeriesMap: [], aiConfig: []);
    await expectLater(repository.importSnapshot(empty), throwsFormatException);
    expect(await repository.getAllMachines(), hasLength(57));
    expect(await repository.getImportedDatabaseVersion(), '1.1');
  });
}
