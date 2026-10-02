import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dtc_product/features/site_layout/data/site_layout_database.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/repositories/site_layout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;
  late SiteLayoutRepository repository;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final helper = SiteLayoutDatabase.forTesting(database);
    await helper.createSchemaForTesting(database);
    repository = SiteLayoutRepository(database: helper);
  });

  tearDown(() => database.close());

  test('tạo dự án luôn có phương án A ưu tiên', () async {
    final project = await repository.createProject(
      name: 'Dự án test',
      customer: 'DTC',
      location: 'Cần Thơ',
      surveyor: 'Kỹ sư A',
      surveyDate: DateTime(2026, 9, 25),
      siteWidthMm: 12000,
      siteLengthMm: 18000,
    );
    final layouts = await repository.getLayouts(project.id);
    expect(layouts, hasLength(1));
    expect(layouts.single.name, 'Phương án A');
    expect(layouts.single.isPreferred, isTrue);
  });

  test(
    'lưu và nhân bản phương án sao chép đối tượng, không đổi catalog',
    () async {
      final project = await repository.createProject(
        name: 'Dự án test',
        customer: '',
        location: '',
        surveyor: '',
        surveyDate: DateTime(2026, 9, 25),
        siteWidthMm: 10000,
        siteLengthMm: 10000,
      );
      final layout = (await repository.getLayouts(project.id)).single;
      var bundle = (await repository.getBundle(project.id, layout.id))!;
      bundle = bundle.copyWith(
        machines: [
          MachinePlacement(
            id: 'machine_1',
            layoutId: layout.id,
            sourceType: 'grinding',
            sourceId: 'asp_1',
            category: 'Máy nghiền',
            model: 'ASP-1000',
            displayName: 'ASP-1000',
            xMm: 1000,
            yMm: 1000,
            lengthMm: 2000,
            widthMm: 1000,
            heightMm: 1800,
          ),
        ],
      );
      await repository.saveBundle(bundle);
      final duplicate = await repository.duplicateLayout(layout);
      final copied = await repository.getBundle(project.id, duplicate.id);
      expect(copied!.machines, hasLength(1));
      expect(copied.machines.single.sourceId, 'asp_1');
      expect(copied.machines.single.id, isNot('machine_1'));
    },
  );

  test('xóa dự án xóa toàn bộ phương án bằng khóa ngoại', () async {
    final project = await repository.createProject(
      name: 'Dự án test',
      customer: '',
      location: '',
      surveyor: '',
      surveyDate: DateTime(2026, 9, 25),
      siteWidthMm: 10000,
      siteLengthMm: 10000,
    );
    await repository.deleteProject(project.id);
    expect(await repository.getProject(project.id), isNull);
    expect(await repository.getLayouts(project.id), isEmpty);
  });

  test('migration v3 thêm đơn vị mét mà không đổi kích thước', () async {
    final migrationDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(migrationDb.close);
    await migrationDb.execute('''
      CREATE TABLE site_layout_projects(
        id TEXT PRIMARY KEY,
        siteWidthMm REAL NOT NULL,
        siteLengthMm REAL NOT NULL
      )
    ''');
    await migrationDb.insert('site_layout_projects', {
      'id': 'legacy',
      'siteWidthMm': 12500,
      'siteLengthMm': 8000,
    });

    final helper = SiteLayoutDatabase.forTesting(migrationDb);
    await helper.upgradeSchemaForTesting(migrationDb, 3, 4);
    final row = (await migrationDb.query('site_layout_projects')).single;

    expect(row['dimensionUnit'], 'meter');
    expect(row['siteWidthMm'], 12500);
    expect(row['siteLengthMm'], 8000);
  });
}
