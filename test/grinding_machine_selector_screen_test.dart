import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine_match.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_criteria.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_selector_screen.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_selection_service.dart';
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
    return GrindingMachineProvider(repository: repository);
  }

  Widget wrap(GrindingMachineProvider provider) {
    final router = GoRouter(
      initialLocation: '/grinding_machine/selector',
      routes: [
        GoRoute(
          path: '/grinding_machine/selector',
          builder: (_, _) => const GrindingMachineSelectorScreen(),
        ),
        GoRoute(
          path: '/grinding_machine/detail/:machineId',
          builder: (_, state) => GrindingMachineDetailScreen(
            machineId: state.pathParameters['machineId']!,
          ),
        ),
        GoRoute(
          path: '/grinding_machine/compare',
          builder: (_, _) => const Scaffold(body: Text('Compare screen')),
        ),
      ],
    );
    return ChangeNotifierProvider<GrindingMachineProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> pumpReady(WidgetTester tester, GrindingMachineProvider provider) async {
    await tester.runAsync(() async {
      await provider.loadHome();
      await tester.pumpWidget(wrap(provider));
      await tester.pump();
      for (
        var i = 0;
        i < 50 &&
            find
                .byKey(const Key('grinding_selector_submit_button'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      // Chờ dropdown nguyên liệu load xong (isLoadingMaterials).
      for (
        var i = 0;
        i < 50 &&
            find
                .byKey(const Key('grinding_selector_material_field'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
  }

  Future<void> submitAndWait(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('grinding_selector_submit_button')));
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 50 &&
            find
                .byKey(const Key('grinding_selector_results_title'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  testWidgets(
    'Nhập capacity/fineness/motor -> kết quả giữ đủ MATCH/NOT_MATCH/UNKNOWN, mở được Detail',
    (tester) async {
      final provider = await setUpProvider();
      addTearDown(provider.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpReady(tester, provider);

      await tester.enterText(
        find.byKey(const Key('grinding_selector_capacity_field')),
        '10',
      );
      await tester.pump();

      await submitAndWait(tester);

      expect(find.byKey(const Key('grinding_selector_results_title')), findsOneWidget);
      // Với yêu cầu công suất rất thấp (10 kg/h), model nào có dữ liệu
      // capacity đều phải MATCH (max luôn >= 10) -> Strong/Possible Match,
      // không có model nào NOT_MATCH tiêu chí này.
      expect(find.textContaining('✗ Công suất'), findsNothing);

      final firstDetailButton = find
          .byWidgetPredicate(
            (w) => w.key.toString().startsWith(
              "[<'grinding_selector_detail_",
            ),
          )
          .first;
      await tester.tap(firstDetailButton);
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });
      expect(find.text('Thông số kỹ thuật'), findsOneWidget);
    },
  );

  testWidgets(
    'Yêu cầu vượt xa mọi model -> vẫn hiện Closest matches kèm lý do, không ẩn kết quả',
    (tester) async {
      final provider = await setUpProvider();
      addTearDown(provider.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpReady(tester, provider);

      await tester.enterText(
        find.byKey(const Key('grinding_selector_capacity_field')),
        '999999',
      );
      await tester.pump();

      await submitAndWait(tester);

      // Không có model nào đáp ứng công suất phi thực tế này -> phải hiện
      // rõ "Không tìm thấy máy khớp hoàn toàn" (mục 13), KHÔNG được ẩn kết
      // quả hay hiện "No machine available" trống trơn — vẫn phải render
      // card model gần đúng nhất kèm nút xem chi tiết.
      expect(
        find.textContaining('Không tìm thấy máy khớp hoàn toàn'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'grinding_selector_detail_"),
        ),
        findsWidgets,
      );

      // Đối chiếu độc lập bằng chính Selection Service (không qua UI) để xác
      // nhận yêu cầu 999999 kg/h thật sự tạo ra NOT_MATCH ở tiêu chí công
      // suất cho các model có dữ liệu — bảng "Recommended Machines" trên UI
      // chỉ hiển thị top 5 nên không đảm bảo NOT_MATCH luôn lọt vào khung
      // nhìn nếu có model UNKNOWN công suất đứng trước.
      final independent = GrindingMachineSelectionService.evaluate(
        criteria: const GrindingSelectionCriteria(capacityKgH: 999999),
        machines: provider.machines,
      );
      expect(
        independent.any(
          (m) => m.criteria.any(
            (c) => c.status == GrindingCriterionStatus.notMatch,
          ),
        ),
        isTrue,
        reason: 'Phải có ít nhất 1 model NOT_MATCH công suất trong dữ liệu thật.',
      );
    },
  );

  testWidgets('Không nhập tiêu chí nào -> báo lỗi, không gọi Selection Service', (
    tester,
  ) async {
    final provider = await setUpProvider();
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpReady(tester, provider);

    await tester.tap(find.byKey(const Key('grinding_selector_submit_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Nhập ít nhất 1 tiêu chí'), findsOneWidget);
    expect(find.byKey(const Key('grinding_selector_results_title')), findsNothing);
  });
}
