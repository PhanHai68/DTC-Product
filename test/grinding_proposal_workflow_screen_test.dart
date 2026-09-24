import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_proposal_provider.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_selection_project_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_proposal_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Full flow: R0 Final -> Create Revision -> R1 Draft prefill -> đổi giá -> Finalize -> Mark Sent -> Mark Accepted, đúng nút theo từng status',
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
            projectName: 'Dự án Workflow',
            createdAt: now,
            updatedAt: now,
          ),
          primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
          ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
        ],
        child: MaterialApp(home: child),
      );

      Future<void> waitFor(WidgetTester tester, Key key) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 50 && find.byKey(key).evaluate().isEmpty; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
        });
        await tester.pump();
      }

      Future<void> waitForText(WidgetTester tester, String text) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 50 && find.text(text).evaluate().isEmpty; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
        });
        await tester.pump();
      }

      // --- Tạo R0, nhập giá, Finalize ---
      await tester.pumpWidget(wrap(GrindingProposalEditorScreen(projectId: projectId)));
      await tester.pump();
      await waitFor(tester, const Key('grinding_proposal_save_draft_button'));

      expect(find.text('DRAFT'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
        '400000000',
      );
      await tester.enterText(
        find.byKey(const Key('grinding_proposal_machine_quantity_field')),
        '1',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('grinding_proposal_finalize_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalize').last);
      await waitForText(tester, 'FINAL');

      // Final: có Mark as Sent + Create Revision, KHÔNG có Save Draft/Finalize/Delete.
      expect(find.byKey(const Key('grinding_proposal_mark_sent_button')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_create_revision_button')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_save_draft_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_finalize_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_delete_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_mark_accepted_button')), findsNothing);

      // --- Create Revision -> mở R1 (push route mới) ---
      await tester.tap(find.byKey(const Key('grinding_proposal_create_revision_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận').last);
      await waitForText(tester, 'DRAFT');

      // R1 Draft: prefill đúng giá của R0, badge DRAFT, title có "R1".
      expect(find.textContaining(' R1'), findsWidgets);
      final priceField = tester.widget<TextFormField>(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
      );
      expect(priceField.controller!.text, '400000000');

      // Đổi giá trên R1.
      await tester.enterText(
        find.byKey(const Key('grinding_proposal_machine_price_field')),
        '450000000',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('grinding_proposal_finalize_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalize').last);
      await waitForText(tester, 'FINAL');

      // --- Mark as Sent trên R1 ---
      await tester.tap(find.byKey(const Key('grinding_proposal_mark_sent_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận').last);
      await waitForText(tester, 'SENT');

      expect(find.byKey(const Key('grinding_proposal_mark_accepted_button')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_mark_rejected_button')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_create_revision_button')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_mark_sent_button')), findsNothing);

      // --- Mark Accepted trên R1 ---
      await tester.tap(find.byKey(const Key('grinding_proposal_mark_accepted_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận').last);
      await waitForText(tester, 'ACCEPTED');

      // Accepted: KHÔNG còn Create Revision/Mark Sent/Mark Accepted/Mark Rejected/Delete.
      expect(find.byKey(const Key('grinding_proposal_create_revision_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_mark_accepted_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_mark_rejected_button')), findsNothing);
      expect(find.byKey(const Key('grinding_proposal_delete_button')), findsNothing);

      // Revision History hiện đủ R0 (Final) + R1 (Accepted).
      expect(find.byKey(const Key('grinding_proposal_revision_history')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_revision_tile_0')), findsOneWidget);
      expect(find.byKey(const Key('grinding_proposal_revision_tile_1')), findsOneWidget);

      // Xác nhận Repository: đúng trạng thái cuối cùng, R0 không đổi.
      final chains = await proposalProvider.getProposalChainsByProject(projectId);
      expect(chains, hasLength(1));
      final chain = chains.single;
      expect(chain.map((p) => p.revision).toList(), [0, 1]);
      final r0 = chain[0];
      final r1 = chain[1];
      expect(r0.machineUnitPrice, 400000000);
      expect(r1.machineUnitPrice, 450000000);
      expect(r1.status.value, 'accepted');
    },
  );
}
