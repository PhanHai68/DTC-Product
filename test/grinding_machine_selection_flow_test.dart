import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_request.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_recommendation_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Nhập yêu cầu (Vừng, 300 kg/h, 20 mesh) -> đề xuất đúng model dòng con lăn, có Reason',
    (tester) async {
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
        initialLocation: '/grinding_machine/selection',
        routes: [
          GoRoute(
            path: '/grinding_machine/selection',
            builder: (_, _) => const GrindingMachineSelectionScreen(),
          ),
          GoRoute(
            path: '/grinding_machine/recommendation',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return GrindingMachineRecommendationScreen(
                request: extra['request'] as GrindingSelectionRequest,
                materialName: extra['materialName'] as String,
              );
            },
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

      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // sqflite_common_ffi gọi SQLite thật qua FFI, không tương thích
      // FakeAsync zone mặc định của testWidgets().
      await tester.runAsync(() async {
        await provider.loadHome();
        await tester.pumpWidget(
          ChangeNotifierProvider<GrindingMachineProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      // Mở dropdown Nguyên liệu -> chọn "Vừng".
      await tester.tap(find.byKey(const Key('grinding_selection_material_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vừng').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('grinding_selection_capacity_field')),
        '300',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_selection_fineness_field')),
        '20',
      );
      // Chọn thêm tag "roller" (chỉ riêng BS_ROLLER có) để tránh kết quả bị
      // các dòng máy khác điểm bằng nhau (cùng chạm mốc điểm tối đa) chiếm
      // hết top 3 trước khi tới model cần kiểm tra.
      await tester.tap(find.byKey(const Key('grinding_selection_tag_roller')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('grinding_selection_submit_button')));
      await tester.runAsync(() async {
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.textContaining('model phù hợp nhất'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_recommendation_card_BS_ROLLER__AS500-3')),
        findsOneWidget,
      );
      expect(find.textContaining('Vừng'), findsWidgets);
      expect(find.text('Lưu ý'), findsWidgets);
    },
  );

  testWidgets(
    'Không đủ thông tin bắt buộc -> báo lỗi, KHÔNG chuyển sang trang kết quả',
    (tester) async {
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

      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await provider.loadHome();
        await tester.pumpWidget(
          ChangeNotifierProvider<GrindingMachineProvider>.value(
            value: provider,
            child: const MaterialApp(home: GrindingMachineSelectionScreen()),
          ),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      await tester.tap(find.byKey(const Key('grinding_selection_submit_button')));
      await tester.pump();

      expect(
        find.textContaining('Vui lòng nhập đủ'),
        findsOneWidget,
      );
    },
  );
}
