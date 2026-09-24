import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_dashboard_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_backup_restore_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_home_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_selector_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_proposal_editor_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_project_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Widget test màn hình nhỏ (Phase 11, mục 24/62) — 320px/360px width,
/// expect KHÔNG có RenderFlex overflow exception. Không cần pixel test,
/// chỉ cần không throw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingMachineProvider machineProvider;
  late GrindingSelectionProjectProvider projectProvider;
  late GrindingProposalProvider proposalProvider;
  late GrindingDashboardProvider dashboardProvider;

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
      ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
      ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
      ChangeNotifierProvider<GrindingDashboardProvider>.value(value: dashboardProvider),
    ],
    child: MaterialApp(home: child),
  );

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    machineProvider = GrindingMachineProvider(
      repository: GrindingMachineRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
    );
    projectProvider = GrindingSelectionProjectProvider(
      repository: GrindingSelectionProjectRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
    );
    proposalProvider = GrindingProposalProvider(
      repository: GrindingProposalRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
    );
    dashboardProvider = GrindingDashboardProvider(
      projectRepository: GrindingSelectionProjectRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
      proposalRepository: GrindingProposalRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
    );
  });

  tearDown(() async {
    machineProvider.dispose();
    projectProvider.dispose();
    proposalProvider.dispose();
    dashboardProvider.dispose();
    await database.close();
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('Home không overflow ở width ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await machineProvider.loadHome();
      });
      await tester.pumpWidget(wrap(const GrindingMachineHomeScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Dashboard (empty state) không overflow ở width ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const GrindingProjectDashboardScreen()));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 30 && find.byKey(const Key('grinding_dashboard_empty_text')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Backup & Restore screen không overflow ở width ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const GrindingBackupRestoreScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Machine Selector không overflow ở width ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await machineProvider.loadHome();
      });
      await tester.pumpWidget(wrap(const GrindingMachineSelectorScreen()));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 30 &&
              find.byKey(const Key('grinding_selector_submit_button')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Proposal Editor (Draft mới) không overflow ở width ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late int projectId;
      await tester.runAsync(() async {
        await machineProvider.loadHome();
        final projectRepository = GrindingSelectionProjectRepository(
          database: GrindingMachineDatabase.forTesting(database),
        );
        final now = DateTime(2026, 9, 24);
        projectId = await projectRepository.createProject(
          GrindingSelectionProject(
            projectName: 'Dự án nhỏ nhưng tên rất rất rất dài để test overflow trên màn hình nhỏ',
            createdAt: now,
            updatedAt: now,
          ),
          primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
        );
      });

      await tester.pumpWidget(wrap(GrindingProposalEditorScreen(projectId: projectId)));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 30 &&
              find.byKey(const Key('grinding_proposal_save_draft_button')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
