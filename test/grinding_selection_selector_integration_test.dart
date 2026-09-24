import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_selector_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_selection_project_detail_screen.dart';
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

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/grinding_machine/selector',
      routes: [
        GoRoute(
          path: '/grinding_machine/selector',
          builder: (_, state) => GrindingMachineSelectorScreen(
            existingProjectId: state.extra is int ? state.extra as int : null,
          ),
        ),
        GoRoute(
          path: '/grinding_machine/projects/:id',
          builder: (_, state) => GrindingSelectionProjectDetailScreen(
            projectId: int.parse(state.pathParameters['id']!),
          ),
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
        ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> pumpReadySelector(WidgetTester tester) async {
    await tester.runAsync(() async {
      await machineProvider.loadHome();
      await tester.pumpWidget(wrap());
      await tester.pump();
      for (
        var i = 0;
        i < 50 &&
            find.byKey(const Key('grinding_selector_submit_button')).evaluate().isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
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
  });

  tearDown(() async {
    machineProvider.dispose();
    projectProvider.dispose();
    proposalProvider.dispose();
    await database.close();
  });

  testWidgets(
    'Nhập yêu cầu -> có recommendation -> chọn máy -> Save Project -> mở lại đúng criteria + đúng máy đã chọn',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 8000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpReadySelector(tester);

      await tester.enterText(
        find.byKey(const Key('grinding_selector_project_name_field')),
        'Dự án tích hợp',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_selector_customer_name_field')),
        'Khách hàng XYZ',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_selector_capacity_field')),
        '10',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('grinding_selector_submit_button')));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 50 &&
              find.byKey(const Key('grinding_selector_results_title')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(find.byKey(const Key('grinding_selector_results_title')), findsOneWidget);

      // Chọn model đầu tiên trong kết quả làm primary.
      final selectButton = find
          .byWidgetPredicate(
            (w) => w.key.toString().startsWith("[<'grinding_selector_select_"),
          )
          .first;
      await tester.tap(selectButton);
      await tester.pump();
      expect(find.byKey(const Key('grinding_selector_primary_banner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('grinding_selector_save_button')));
      await tester.runAsync(() async {
        // Chờ save (SQLite transaction) + điều hướng + Detail screen tự
        // load xong (initState async) — không dùng pumpAndSettle() ở đây vì
        // dữ liệu tải thật (FFI) không tương thích FakeAsync zone.
        for (
          var i = 0;
          i < 80 &&
              find.byKey(const Key('grinding_project_export_button')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      // Đã điều hướng sang Project Detail sau khi lưu.
      expect(find.text('Dự án tích hợp'), findsWidgets);
      expect(find.text('Khách hàng XYZ'), findsOneWidget);
      expect(find.textContaining('10 kg/h'), findsOneWidget);
      expect(find.byKey(const Key('grinding_project_no_machine')), findsNothing);
      expect(find.byKey(const Key('grinding_project_machine_unavailable')), findsNothing);

      // Xác nhận trực tiếp trong Repository: criteria + selected machine
      // lưu đúng, đọc lại đúng.
      await projectProvider.loadAll();
      final projects = projectProvider.projects;
      expect(projects, hasLength(1));
      final saved = projects.first;
      expect(saved.projectName, 'Dự án tích hợp');
      expect(saved.customerName, 'Khách hàng XYZ');
      expect(saved.requiredCapacityKgH, 10);
      final machines = await projectProvider.getProjectMachines(saved.id!);
      expect(machines.primaryMachineId, isNotNull);
    },
  );
}
