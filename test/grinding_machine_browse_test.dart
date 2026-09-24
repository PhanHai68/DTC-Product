import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_home_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_search_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_series_machines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _pumpApp(WidgetTester tester) async {
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

  final router = GoRouter(
    initialLocation: '/grinding_machine',
    routes: [
      GoRoute(
        path: '/grinding_machine',
        builder: (_, _) => const GrindingMachineHomeScreen(),
      ),
      GoRoute(
        path: '/grinding_machine/search',
        builder: (_, _) => const GrindingMachineSearchScreen(),
      ),
      GoRoute(
        path: '/grinding_machine/series',
        builder: (_, state) =>
            GrindingSeriesMachinesScreen(seriesCode: state.extra as String),
      ),
      GoRoute(
        path: '/grinding_machine/detail/:machineId',
        builder: (_, state) => GrindingMachineDetailScreen(
          machineId: state.pathParameters['machineId']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // `testWidgets` chạy trong FakeAsync zone, nhưng sqflite_common_ffi gọi
  // SQLite thật qua FFI (không tương thích FakeAsync) — phải bọc bằng
  // `runAsync()` để Future thật (đọc asset JSON + import/query SQLite) được
  // xử lý đúng thay vì treo vô thời hạn.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GrindingMachineProvider>.value(
        value: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    while (provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Home tự seed database thật và hiển thị đúng 11 dòng máy',
    (tester) async {
      await _pumpApp(tester);

      expect(find.text('Máy nghiền'), findsOneWidget);
      expect(find.textContaining('11 dòng · 57 model'), findsOneWidget);
      expect(find.byKey(const Key('grinding_series_card_BSC_COARSE')), findsOneWidget);
    },
  );

  testWidgets(
    'Chạm 1 Series mở đúng danh sách model của dòng máy đó',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('grinding_series_card_BSC_COARSE')));
      await tester.pumpAndSettle();

      // BSC_COARSE có 5 model ASC-200/300/400/600/1000 theo database.
      expect(find.textContaining('5 model'), findsOneWidget);
      expect(find.byKey(const Key('grinding_machine_tile_BSC_COARSE__ASC-200')), findsOneWidget);
    },
  );

  testWidgets(
    'Chạm 1 model mở Detail đúng thông số thật từ database, không rỗng',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('grinding_series_card_BSC_COARSE')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('grinding_machine_tile_BSC_COARSE__ASC-200')),
        );
        await tester.pump();
        // Detail screen tự load (getMachine/getSeries/getExtraSpecs) qua
        // postFrameCallback riêng — cũng là I/O thật nên cần chờ thật trước
        // khi rời runAsync (bên trong FakeAsync zone sẽ không tự chạy).
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ASC-200'), findsWidgets);
      expect(find.text('Công suất xử lý'), findsOneWidget);
      expect(find.text('80 - 300 kg/h'), findsOneWidget);
      expect(find.text('Độ mịn đầu ra'), findsOneWidget);
      expect(find.text('0.5 - 20 mm'), findsOneWidget);
    },
  );

  testWidgets('Search tìm đúng model theo tên nhập vào', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('grinding_machine_search_bar')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('grinding_machine_search_field')),
      'ASP-350',
    );
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('grinding_machine_tile_BSP_ULTRAFINE__ASP-350')), findsOneWidget);
  });
}
