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

/// Double Submit Protection (Phase 11, mục 27/61) — tap "Save Draft" 2 lần
/// liên tiếp (trước khi request đầu hoàn tất) KHÔNG được tạo 2 proposal.
/// `_isSaving` disable nút ngay sau tap đầu tiên (`setState` đồng bộ trước
/// khi `await` bất kỳ I/O nào) nên tap thứ 2 (cùng frame/microtask) phải bị
/// chặn ở tầng UI, không tới được Provider/Repository lần 2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tap Save Draft 2 lần liên tiếp -> chỉ tạo 1 proposal', (tester) async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(database.close);
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);

    final machineProvider = GrindingMachineProvider(
      repository: GrindingMachineRepository(database: GrindingMachineDatabase.forTesting(database)),
    );
    addTearDown(machineProvider.dispose);
    final projectRepository = GrindingSelectionProjectRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    final projectProvider = GrindingSelectionProjectProvider(repository: projectRepository);
    addTearDown(projectProvider.dispose);
    final proposalProvider = GrindingProposalProvider(
      repository: GrindingProposalRepository(database: GrindingMachineDatabase.forTesting(database)),
    );
    addTearDown(proposalProvider.dispose);

    late int projectId;
    await tester.runAsync(() async {
      await machineProvider.loadHome();
      final now = DateTime(2026, 9, 24);
      projectId = await projectRepository.createProject(
        GrindingSelectionProject(projectName: 'Dự án double-submit', createdAt: now, updatedAt: now),
        primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
      );
    });

    await tester.binding.setSurfaceSize(const Size(390, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GrindingMachineProvider>.value(value: machineProvider),
          ChangeNotifierProvider<GrindingSelectionProjectProvider>.value(value: projectProvider),
          ChangeNotifierProvider<GrindingProposalProvider>.value(value: proposalProvider),
        ],
        child: MaterialApp(home: GrindingProposalEditorScreen(projectId: projectId)),
      ),
    );
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 50 && find.byKey(const Key('grinding_proposal_save_draft_button')).evaluate().isEmpty;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('grinding_proposal_machine_price_field')),
      '100000000',
    );
    await tester.pump();

    // Tap 2 lần liên tiếp KHÔNG chờ request đầu hoàn tất giữa 2 lần.
    await tester.tap(find.byKey(const Key('grinding_proposal_save_draft_button')));
    await tester.tap(find.byKey(const Key('grinding_proposal_save_draft_button')));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump();

    await proposalProvider.loadForProject(projectId);
    expect(proposalProvider.proposals, hasLength(1));
  });
}
