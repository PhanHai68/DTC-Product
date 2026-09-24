import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_proposal_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Draft: chỉnh sửa được, Save Draft -> Finalize -> UI chuyển FINAL, khóa field',
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
      final projectProvider = GrindingSelectionProjectProvider(repository: projectRepository);
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
            projectName: 'Dự án Proposal',
            createdAt: now,
            updatedAt: now,
          ),
          primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
              ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
              ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
            ],
            child: MaterialApp(
              home: GrindingProposalEditorScreen(projectId: projectId),
            ),
          ),
        );
        await tester.pump();
        for (
          var i = 0;
          i < 50 &&
              find.byKey(const Key('grinding_proposal_save_draft_button')).evaluate().isEmpty;
          i++
        ) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      // Đang Draft -> badge DRAFT, field giá còn sửa được.
      expect(find.text('DRAFT'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
        '500000000',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_proposal_machine_quantity_field')),
        '1',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_proposal_vat_field')),
        '10',
      );
      await tester.pump();

      // Grand Total tính đúng ngay trên UI (Preview trực tiếp).
      expect(find.textContaining('550000000 VND'), findsOneWidget);

      await tester.tap(find.byKey(const Key('grinding_proposal_finalize_button')));
      await tester.pumpAndSettle();
      // Dialog confirm Finalize.
      await tester.tap(find.text('Finalize').last);
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && find.text('FINAL').evaluate().isEmpty; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await tester.pump();

      // Sau Finalize: badge FINAL, field nhập giá KHÔNG còn hiện (chỉ đọc).
      expect(find.text('FINAL'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('grinding_proposal_finalize_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('grinding_proposal_save_draft_button')),
        findsNothing,
      );

      // Xác nhận Repository: Final đã có snapshot đóng băng, đúng model.
      final proposals = await proposalProvider.loadForProject(projectId).then(
        (_) => proposalProvider.proposals,
      );
      expect(proposals, hasLength(1));
      expect(proposals.first.isFinal, isTrue);
      expect(proposals.first.technicalSnapshot, isNotNull);
      expect(proposals.first.technicalSnapshot!.model, 'ASP-350');
    },
  );
}
