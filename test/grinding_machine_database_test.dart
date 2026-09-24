import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createSchemaForTesting tạo đủ 7 bảng của module Máy nghiền', () async {
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'grinding_%'",
    );
    final names = tables.map((row) => row['name'] as String).toSet();

    expect(
      names,
      containsAll(const [
        'grinding_series',
        'grinding_machines',
        'grinding_extra_specs',
        'grinding_selection_tags',
        'grinding_materials',
        'grinding_material_series_map',
        'grinding_ai_config',
        'grinding_db_meta',
      ]),
    );
  });
}
