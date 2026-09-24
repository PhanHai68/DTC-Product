import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GrindingMachineProvider> setUpProvider() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(db);
    final repository = GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(db),
    );
    // loadHome() chưa gọi ở đây — phải chạy trong tester.runAsync() ở từng
    // test (sqflite_common_ffi dùng FFI thật, không tương thích FakeAsync
    // zone mặc định của testWidgets()).
    return GrindingMachineProvider(repository: repository);
  }

  Widget wrap(GrindingMachineProvider provider) {
    final router = GoRouter(
      initialLocation: '/grinding_machine/list',
      routes: [
        GoRoute(
          path: '/grinding_machine/list',
          builder: (_, _) => const GrindingMachineListScreen(),
        ),
        GoRoute(
          path: '/grinding_machine/detail/:machineId',
          builder: (_, state) => GrindingMachineDetailScreen(
            machineId: state.pathParameters['machineId']!,
          ),
        ),
      ],
    );
    return ChangeNotifierProvider<GrindingMachineProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Bơm widget, `loadHome()`, rồi CHỜ tới khi index search (mục 3, 16) build
  /// xong (`_isIndexing == false`, nhận biết qua ô search xuất hiện) thay vì
  /// 1 khoảng delay cố định — index build ~80 lượt query FFI tuần tự nên thời
  /// gian thực tế không ổn định giữa các lần chạy.
  Future<void> pumpReady(WidgetTester tester, GrindingMachineProvider provider) async {
    await tester.runAsync(() async {
      await provider.loadHome();
      await tester.pumpWidget(wrap(provider));
      await tester.pump();
      for (
        var i = 0;
        i < 50 &&
            find.byKey(const Key('grinding_list_search_field')).evaluate().isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
  }

  /// Gõ [text] vào ô search rồi chờ debounce (300ms) áp dụng xong. Timer
  /// debounce được tạo trong FakeAsync zone của `testWidgets` (vì
  /// `enterText` chạy ngoài `runAsync`) nên phải đẩy đồng hồ ẢO qua
  /// `tester.pump(duration)`, KHÔNG dùng `Future.delayed` thật trong
  /// `runAsync` (Timer ở 2 zone khác nhau sẽ không bao giờ kích hoạt).
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const Key('grinding_list_search_field')),
      text,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('Search theo model không phân biệt hoa/thường', (tester) async {
    final provider = await setUpProvider();
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpReady(tester, provider);
    await search(tester, 'asp-350');

    expect(find.textContaining('ASP-350'), findsWidgets);
    expect(
      find.byKey(const Key('grinding_list_card_BSP_ULTRAFINE__ASP-350')),
      findsOneWidget,
    );
  });

  testWidgets('Search theo series (BSP) trả nhiều model cùng dòng', (tester) async {
    final provider = await setUpProvider();
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 8000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpReady(tester, provider);
    await search(tester, 'BSP');

    final expected = provider.machines
        .where((m) => m.seriesCode.toUpperCase().contains('BSP'))
        .toList();
    expect(expected.length, greaterThan(1));
    for (final m in expected) {
      expect(
        find.byKey(Key('grinding_list_card_${m.machineId}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Search không có kết quả -> hiện thông báo, không crash', (tester) async {
    final provider = await setUpProvider();
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpReady(tester, provider);
    await search(tester, 'khong-ton-tai-xyz');

    expect(find.textContaining('Không tìm thấy'), findsOneWidget);
    expect(find.byKey(const Key('grinding_list_results')), findsNothing);
  });

  testWidgets(
    'Filter theo Series qua bottom sheet -> Apply lọc đúng, Reset trả lại toàn bộ',
    (tester) async {
      final provider = await setUpProvider();
      addTearDown(provider.dispose);
      // Cần đủ cao để render hết 57 model sau khi Reset (card giờ có tới 5
      // chip, cao hơn list tile thường).
      await tester.binding.setSurfaceSize(const Size(390, 16000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpReady(tester, provider);

      await tester.tap(find.byKey(const Key('grinding_list_filter_button')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('grinding_list_filter_series_BS_ROLLER')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('grinding_list_filter_apply')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Filter (1)'), findsOneWidget);
      for (final m in provider.machinesOf('BS_ROLLER')) {
        expect(
          find.byKey(Key('grinding_list_card_${m.machineId}')),
          findsOneWidget,
        );
      }
      final otherMachine = provider.machines.firstWhere(
        (m) => m.seriesCode != 'BS_ROLLER',
      );
      expect(
        find.byKey(Key('grinding_list_card_${otherMachine.machineId}')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('grinding_list_filter_reset')));
      await tester.pump();
      expect(find.textContaining('Filter ('), findsNothing);
      for (final m in provider.machines) {
        expect(
          find.byKey(Key('grinding_list_card_${m.machineId}')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('Luồng List -> search -> mở Detail đúng model', (tester) async {
    final provider = await setUpProvider();
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpReady(tester, provider);
    await search(tester, 'ASP-350');

    await tester.tap(
      find.byKey(const Key('grinding_list_card_BSP_ULTRAFINE__ASP-350')),
    );
    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    expect(find.text('ASP-350'), findsWidgets);
    expect(find.text('Thông số kỹ thuật'), findsOneWidget);
  });
}
