import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_database_update_screen.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_database_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _xlsxFixture = 'test/fixtures/grinding_machine/ai_ready.xlsx';

class _FakeFilePicker extends GrindingDatabaseFilePicker {
  const _FakeFilePicker(this._result);
  final GrindingImportFile? _result;
  @override
  Future<GrindingImportFile?> pick() async => _result;
}

Future<GrindingMachineRepository> _seededRepository(Database db) async {
  await GrindingMachineDatabase.instance.createSchemaForTesting(db);
  final repository = GrindingMachineRepository(
    database: GrindingMachineDatabase.forTesting(db),
  );
  final provider = GrindingMachineProvider(repository: repository);
  await provider.loadHome();
  provider.dispose();
  return repository;
}

Widget _wrap(GrindingMachineProvider provider, GrindingDatabaseFilePicker picker) =>
    ChangeNotifierProvider<GrindingMachineProvider>.value(
      value: provider,
      child: MaterialApp(
        home: GrindingDatabaseUpdateScreen(filePicker: picker),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Chọn file Excel thật (.xlsx) -> preview hiển thị đúng, Cập nhật database thành công',
    (tester) async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      late GrindingMachineRepository repository;
      await tester.runAsync(() async {
        repository = await _seededRepository(db);
      });
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final xlsxBytes = await tester.runAsync(
        () async => Uint8List.fromList(
          await File(_xlsxFixture).readAsBytes(),
        ),
      );

      await tester.runAsync(() async {
        await provider.loadHome();
        await tester.pumpWidget(
          _wrap(
            provider,
            _FakeFilePicker(
              GrindingImportFile('ai_ready.xlsx', xlsxBytes!),
            ),
          ),
        );
        await tester.pump();
      });

      await tester.tap(find.byKey(const Key('grinding_import_pick')));
      await tester.runAsync(() async {
        // GrindingExcelParser.parse chạy qua compute() (isolate riêng) và
        // xử lý cả workbook thật (18 sheet) nên chậm hơn nhánh JSON.
        for (var i = 0; i < 20 && find.byKey(const Key('grinding_import_apply')).evaluate().isEmpty; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          await tester.pump();
        }
      });
      await tester.pump();

      // Workbook thật cùng version/dữ liệu với seed đã nạp sẵn -> preview
      // phải hiển thị đúng số dòng/model và 0 thay đổi (không mất dữ liệu,
      // không lệch giữa Excel thật và JSON seed).
      expect(find.textContaining('11 dòng máy'), findsOneWidget);
      expect(find.textContaining('57 model'), findsOneWidget);
      expect(find.textContaining('Model mới: 0'), findsOneWidget);
      expect(find.textContaining('Model đổi thông số: 0'), findsOneWidget);
      expect(find.textContaining('Model không còn trong file: 0'), findsOneWidget);
      expect(find.byKey(const Key('grinding_import_apply')), findsOneWidget);

      await tester.tap(find.byKey(const Key('grinding_import_acknowledge')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grinding_import_apply')));
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byKey(const Key('grinding_import_success')), findsOneWidget);
      expect(find.byKey(const Key('grinding_import_error')), findsNothing);
      expect(await repository.getImportedDatabaseVersion(), '1.1');
      expect(await repository.getAllMachines(), hasLength(57));
    },
  );

  testWidgets(
    'Chọn file JSON có thay đổi thật -> preview hiển thị đúng, Cập nhật database thành công',
    (tester) async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      late GrindingMachineRepository repository;
      await tester.runAsync(() async {
        repository = await _seededRepository(db);
      });
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final jsonBytes = await tester.runAsync(() async {
        final root =
            jsonDecode(
                  await File(
                    'assets/database/grinding_machine_seed.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        root['databaseVersion'] = '1.2';
        root['models'][0]['capacityMaxKgH'] = 350;
        return Uint8List.fromList(utf8.encode(jsonEncode(root)));
      });

      await tester.runAsync(() async {
        await provider.loadHome();
        await tester.pumpWidget(
          _wrap(
            provider,
            _FakeFilePicker(GrindingImportFile('new.json', jsonBytes!)),
          ),
        );
        await tester.pump();
      });

      await tester.tap(find.byKey(const Key('grinding_import_pick')));
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.textContaining('Model đổi thông số: 1'), findsOneWidget);
      expect(find.textContaining('1.1 → 1.2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('grinding_import_acknowledge')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grinding_import_apply')));
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byKey(const Key('grinding_import_success')), findsOneWidget);
      expect(await repository.getImportedDatabaseVersion(), '1.2');
      expect(
        (await repository.getMachineByModel('ASC-200'))!.capacityMaxKgH,
        350,
      );
    },
  );

  testWidgets(
    'Hủy chọn file -> không có preview, database không đổi',
    (tester) async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      late GrindingMachineRepository repository;
      await tester.runAsync(() async {
        repository = await _seededRepository(db);
      });
      final provider = GrindingMachineProvider(repository: repository);
      addTearDown(provider.dispose);

      await tester.binding.setSurfaceSize(const Size(390, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await provider.loadHome();
        await tester.pumpWidget(_wrap(provider, const _FakeFilePicker(null)));
        await tester.pump();
      });

      final versionBefore = await repository.getImportedDatabaseVersion();
      final machinesBefore = await repository.getAllMachines();

      await tester.tap(find.byKey(const Key('grinding_import_pick')));
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byKey(const Key('grinding_import_apply')), findsNothing);
      expect(find.byKey(const Key('grinding_import_error')), findsNothing);
      expect(await repository.getImportedDatabaseVersion(), versionBefore);
      expect(await repository.getAllMachines(), hasLength(machinesBefore.length));
    },
  );
}
