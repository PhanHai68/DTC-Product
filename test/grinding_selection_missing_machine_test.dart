import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_selection_project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Project tham chiếu machineId không còn trong database -> hiện unavailable, không crash',
    (tester) async {
      sqfliteFfiInit();
      final database = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(database.close);
      await GrindingMachineDatabase.instance.createSchemaForTesting(database);
      final machineProvider = GrindingMachineProvider(
        repository: GrindingMachineRepository(
          database: GrindingMachineDatabase.forTesting(database),
        ),
      );
      addTearDown(machineProvider.dispose);
      final projectRepository = GrindingSelectionProjectRepository(
        database: GrindingMachineDatabase.forTesting(database),
      );
      final projectProvider = GrindingSelectionProjectProvider(
        repository: projectRepository,
      );
      addTearDown(projectProvider.dispose);
      final proposalProvider = GrindingProposalProvider(
        repository: GrindingProposalRepository(
          database: GrindingMachineDatabase.forTesting(database),
        ),
      );
      addTearDown(proposalProvider.dispose);

      late int projectId;
      await tester.runAsync(() async {
        await machineProvider.loadHome();
        final now = DateTime(2026, 9, 24);
        projectId = await projectRepository.createProject(
          GrindingSelectionProject(
            projectName: 'Dự án máy cũ đã ngừng sản xuất',
            createdAt: now,
            updatedAt: now,
          ),
          // Model KHÔNG tồn tại trong database hiện tại (mô phỏng bị xóa
          // sau khi Excel được cập nhật lại).
          primaryMachineId: 'KHONG_TON_TAI__MODEL-X',
        );
      });

      final router = GoRouter(
        initialLocation: '/grinding_machine/projects/$projectId',
        routes: [
          GoRoute(
            path: '/grinding_machine/projects/:id',
            builder: (_, state) => GrindingSelectionProjectDetailScreen(
              projectId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
              ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
              ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        for (
          var i = 0;
          i < 50 &&
              find
                  .byKey(const Key('grinding_project_selected_machine_section'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      // Không crash (widget tree render bình thường tới đây), hiện đúng
      // thông báo, KHÔNG tự chọn máy khác thay thế.
      expect(find.byKey(const Key('grinding_project_machine_unavailable')), findsOneWidget);
      expect(
        find.text('Machine no longer available in current database'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('grinding_project_view_machine_button')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
