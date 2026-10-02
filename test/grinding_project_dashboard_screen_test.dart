import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_home_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_selection_project_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_selection_project_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingMachineProvider machineProvider;
  late GrindingSelectionProjectProvider projectProvider;
  late GrindingProposalProvider proposalProvider;
  late GrindingSelectionProjectRepository projectRepository;
  late GrindingProposalRepository proposalRepository;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/grinding_machine',
      routes: [
        GoRoute(
          path: '/grinding_machine',
          builder: (_, _) => const GrindingMachineHomeScreen(),
        ),
        GoRoute(
          path: '/grinding_machine/projects',
          builder: (_, state) => GrindingSelectionProjectListScreen(
            initialStatusFilter: state.extra is GrindingProjectStatus
                ? state.extra as GrindingProjectStatus
                : null,
          ),
        ),
        GoRoute(
          path: '/grinding_machine/projects/:id',
          builder: (_, state) => GrindingSelectionProjectDetailScreen(
            projectId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
        ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

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
    projectRepository = GrindingSelectionProjectRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    projectProvider = GrindingSelectionProjectProvider(repository: projectRepository);
    proposalRepository = GrindingProposalRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    proposalProvider = GrindingProposalProvider(repository: proposalRepository);
  });

  tearDown(() async {
    machineProvider.dispose();
    projectProvider.dispose();
    proposalProvider.dispose();
    await database.close();
  });

  testWidgets(
    'Trang Máy nghiền không còn Dashboard và vẫn mở được Dự án đã lưu',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late int projectId;
      await tester.runAsync(() async {
        await machineProvider.loadHome();
        final now = DateTime.now();
        projectId = await projectRepository.createProject(
          GrindingSelectionProject(
            projectName: 'ABC Tea Factory',
            customerName: 'ABC Co.',
            status: GrindingProjectStatus.evaluating,
            nextFollowUpAt: now,
            followUpNote: 'Gọi xác nhận báo giá',
            createdAt: now,
            updatedAt: now,
          ),
          primaryMachineId: 'ASP_ULTRAFINE__ASP-350',
        );
        final proposalId = await proposalRepository.createProposal(
          GrindingProposal(
            projectId: projectId,
            machineId: 'ASP_ULTRAFINE__ASP-350',
            machineUnitPrice: 100000000,
            machineQuantity: 1,
            vatPercent: 10,
            createdAt: now,
            updatedAt: now,
          ),
          const [],
        );
        await proposalRepository.finalizeProposal(
          proposalId,
          snapshot: GrindingTechnicalSnapshotStub.fake(),
        );
        await proposalRepository.markSent(proposalId);
      });

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(
        find.byKey(const Key('grinding_machine_dashboard_button')),
        findsNothing,
      );
      expect(find.text('Dashboard'), findsNothing);
      expect(
        find.byKey(const Key('grinding_machine_backup_button')),
        findsNothing,
      );
      expect(find.text('Backup & Restore'), findsNothing);

      await tester.tap(
        find.byKey(const Key('grinding_machine_projects_button')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 50 &&
              find.byKey(Key('grinding_project_card_$projectId')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(find.text('Dự án đã lưu'), findsOneWidget);
      expect(find.byKey(Key('grinding_project_card_$projectId')), findsOneWidget);
    },
  );
}

/// Snapshot kỹ thuật tối giản chỉ để Finalize trong test — không đại diện
/// máy thật.
abstract final class GrindingTechnicalSnapshotStub {
  static GrindingTechnicalSnapshot fake() => GrindingTechnicalSnapshot(
    machineId: 'ASP_ULTRAFINE__ASP-350',
    model: 'ASP-350',
    capturedAt: DateTime(2026, 9, 24),
  );
}
