import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_compare_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chuẩn bị 1 GrindingMachineProvider đã seed đủ dữ liệu thật (đọc từ asset
/// JSON) trên database SQLite in-memory — dùng chung cho các test bên dưới.
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

  // sqflite_common_ffi gọi SQLite thật qua FFI, không tương thích FakeAsync
  // zone mặc định của testWidgets() -> phải chờ trong runAsync().
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
  // Cao hơn kích thước điện thoại thật để toàn bộ nội dung ListView (nhiều
  // chip nguyên liệu + công suất + độ mịn + kết quả) được build hết trong
  // viewport — ListView ảo hoá nên phần tử ngoài viewport sẽ KHÔNG có trong
  // element tree cho tới khi cuộn tới, không tiện cho việc assert trong test.
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
    await Future.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Filter theo Nguyên liệu (Vừng) chỉ trả model dòng con lăn đã xác minh',
    (tester) async {
      final provider = await _seededProvider(tester);
      await _pumpScreen(tester, provider, const GrindingMachineFilterScreen());

      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('grinding_filter_material_SESAME')),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Material_Series_Map: SESAME chỉ xác minh tương thích BS_ROLLER.
      expect(find.textContaining('model phù hợp'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_machine_tile_BS_ROLLER__AS150-3')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Filter theo Công suất < 100 kg/h không hiện model công suất lớn',
    (tester) async {
      final provider = await _seededProvider(tester);
      await _pumpScreen(tester, provider, const GrindingMachineFilterScreen());

      await tester.tap(
        find.byKey(const Key('grinding_filter_capacity_under100')),
      );
      await tester.pump();

      // ASC-1000 (1000-2500 kg/h) không được nằm trong kết quả "< 100 kg/h".
      expect(
        find.byKey(const Key('grinding_machine_tile_BSC_COARSE__ASC-1000')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Compare 2 model hiển thị đúng bảng thông số thật, ô thiếu hiện —',
    (tester) async {
      final provider = await _seededProvider(tester);
      await _pumpScreen(
        tester,
        provider,
        const GrindingMachineCompareScreen(),
      );

      expect(find.text('Chọn ít nhất 2 model để so sánh.'), findsOneWidget);

      Future<void> pickIntoSlot(int index, String query, String exactTile) async {
        await tester.tap(find.byKey(Key('grinding_compare_slot_$index')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('grinding_picker_search_field')),
          query,
        );
        await tester.runAsync(() async {
          await tester.pump(const Duration(milliseconds: 300));
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        await tester.tap(find.byKey(Key(exactTile)));
        await tester.pumpAndSettle();
      }

      await pickIntoSlot(
        0,
        'ASC-200',
        'grinding_machine_tile_BSC_COARSE__ASC-200',
      );
      await pickIntoSlot(
        1,
        'ASC-300',
        'grinding_machine_tile_BSC_COARSE__ASC-300',
      );

      expect(find.text('Công suất xử lý'), findsOneWidget);
      expect(find.text('80 - 300 kg/h'), findsOneWidget);
      expect(find.text('100 - 800 kg/h'), findsOneWidget);
    },
  );
}
