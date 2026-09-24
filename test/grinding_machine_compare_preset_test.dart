import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_compare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<GrindingMachineProvider> _seededProvider(WidgetTester tester) async {
  sqfliteFfiInit();
  final database = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  addTearDown(database.close);
  await GrindingMachineDatabase.instance.createSchemaForTesting(database);
  final provider = GrindingMachineProvider(
    repository: GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(database),
    ),
  );
  addTearDown(provider.dispose);
  await tester.runAsync(() async {
    await provider.loadHome();
  });
  return provider;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  GrindingMachineProvider provider,
  Widget screen,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GrindingMachineProvider>.value(
        value: provider,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30 && find.text('Chọn ít nhất 2 model để so sánh.').evaluate().isNotEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await Future.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Truyền 2 machineId -> Compare screen tự preselect đúng 2 slot', (
    tester,
  ) async {
    final provider = await _seededProvider(tester);
    await _pumpScreen(
      tester,
      provider,
      const GrindingMachineCompareScreen(
        initialMachineIds: ['BSC_COARSE__ASC-200', 'BSC_COARSE__ASC-300'],
      ),
    );

    expect(find.text('Chọn ít nhất 2 model để so sánh.'), findsNothing);
    expect(find.text('ASC-200'), findsWidgets);
    expect(find.text('ASC-300'), findsWidgets);
    expect(find.text('Công suất xử lý'), findsOneWidget);
  });

  testWidgets('Truyền 3 machineId -> preselect đủ 3 slot', (tester) async {
    final provider = await _seededProvider(tester);
    await _pumpScreen(
      tester,
      provider,
      const GrindingMachineCompareScreen(
        initialMachineIds: [
          'BSC_COARSE__ASC-200',
          'BSC_COARSE__ASC-300',
          'BSP_ULTRAFINE__ASP-350',
        ],
      ),
    );

    expect(find.text('ASC-200'), findsWidgets);
    expect(find.text('ASC-300'), findsWidgets);
    expect(find.text('ASP-350'), findsWidgets);
  });

  testWidgets(
    'Không truyền initialMachineIds -> hành vi cũ giữ nguyên (chưa chọn model nào)',
    (tester) async {
      final provider = await _seededProvider(tester);
      await _pumpScreen(
        tester,
        provider,
        const GrindingMachineCompareScreen(),
      );

      expect(find.text('Chọn ít nhất 2 model để so sánh.'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_compare_slot_0')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'machineId không còn trong database -> bỏ qua slot đó, không crash',
    (tester) async {
      final provider = await _seededProvider(tester);
      await _pumpScreen(
        tester,
        provider,
        const GrindingMachineCompareScreen(
          initialMachineIds: [
            'BSC_COARSE__ASC-200',
            'KHONG_TON_TAI__X-999',
            'BSC_COARSE__ASC-300',
          ],
        ),
      );

      // 2 model hợp lệ vẫn preselect được dù 1 machineId không tồn tại.
      expect(find.text('ASC-200'), findsWidgets);
      expect(find.text('ASC-300'), findsWidgets);
    },
  );
}
