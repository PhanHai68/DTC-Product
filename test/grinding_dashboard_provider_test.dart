import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_dashboard_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ThrowingProjectRepository extends GrindingSelectionProjectRepository {
  @override
  Future<List<GrindingSelectionProject>> getAllProjects() async {
    throw StateError('DB lỗi giả lập');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingSelectionProjectRepository projectRepository;
  late GrindingProposalRepository proposalRepository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    projectRepository = GrindingSelectionProjectRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    proposalRepository = GrindingProposalRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Empty: chưa có project nào -> summary rỗng, không lỗi', () async {
    final provider = GrindingDashboardProvider(
      projectRepository: projectRepository,
      proposalRepository: proposalRepository,
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.error, isNull);
    expect(provider.summary, isNotNull);
    expect(provider.summary!.isEmpty, isTrue);
    expect(provider.summary!.totalProjects, 0);
    expect(provider.summary!.proposalChainCount, 0);
  });

  test('Load: có project + proposal -> summary phản ánh đúng dữ liệu', () async {
    final now = DateTime(2026, 9, 24);
    final projectId = await projectRepository.createProject(
      GrindingSelectionProject(
        projectName: 'Dự án Dashboard',
        status: GrindingProjectStatus.evaluating,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await proposalRepository.createProposal(
      GrindingProposal(
        projectId: projectId,
        createdAt: now,
        updatedAt: now,
      ),
      const [],
    );

    final provider = GrindingDashboardProvider(
      projectRepository: projectRepository,
      proposalRepository: proposalRepository,
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.summary!.totalProjects, 1);
    expect(provider.summary!.proposalChainCount, 1);
    expect(provider.summary!.proposalChainStatusCounts[GrindingProposalStatus.draft], 1);
  });

  test('Refresh: gọi lại sau khi có thêm project mới -> summary cập nhật', () async {
    final provider = GrindingDashboardProvider(
      projectRepository: projectRepository,
      proposalRepository: proposalRepository,
    );
    addTearDown(provider.dispose);

    await provider.load();
    expect(provider.summary!.totalProjects, 0);

    final now = DateTime(2026, 9, 24);
    await projectRepository.createProject(
      GrindingSelectionProject(
        projectName: 'Dự án mới',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await provider.refresh();

    expect(provider.summary!.totalProjects, 1);
  });

  test('Error: repository throw -> provider.error có giá trị, không crash', () async {
    final provider = GrindingDashboardProvider(
      projectRepository: _ThrowingProjectRepository(),
      proposalRepository: proposalRepository,
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.error, isNotNull);
    expect(provider.summary, isNull);
    expect(provider.isLoading, isFalse);
  });
}
