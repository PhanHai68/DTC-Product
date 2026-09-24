import 'dart:convert';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_backup.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_backup_service.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

GrindingBackupPayload _payload({
  int formatVersion = GrindingBackupService.supportedFormatVersion,
  DateTime? createdAt,
  int appDatabaseVersion = 5,
  List<GrindingSelectionProject> projects = const [],
  List<Map<String, Object?>> projectMachines = const [],
  List<GrindingProposal> proposals = const [],
  List<GrindingProposalLineItem> lineItems = const [],
}) {
  return GrindingBackupPayload(
    formatVersion: formatVersion,
    createdAt: createdAt ?? DateTime(2026, 9, 24, 10, 0),
    appDatabaseVersion: appDatabaseVersion,
    projects: projects,
    projectMachines: projectMachines,
    proposals: proposals,
    lineItems: lineItems,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Serialization round-trip', () {
    test('project + proposal + revision + line item + snapshot + follow-up giữ nguyên qua export->parse', () {
      final now = DateTime(2026, 9, 1);
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'M1',
        model: 'ASP-350',
        seriesDisplayCode: 'BSP',
        capacityDisplay: '300 - 500 kg/h',
        capturedAt: now,
      );
      final payload = _payload(
        projects: [
          GrindingSelectionProject(
            id: 1,
            projectName: 'Trà xanh Bảo Lộc',
            customerName: 'Công ty ABC',
            status: GrindingProjectStatus.evaluating,
            nextFollowUpAt: DateTime(2026, 10, 1),
            followUpNote: 'Gọi xác nhận',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        projectMachines: [
          {'projectId': 1, 'machineId': 'M1', 'role': 'primary', 'addedAt': now.toIso8601String()},
        ],
        proposals: [
          GrindingProposal(
            id: 10,
            projectId: 1,
            proposalNumber: 'GM-2026-0001',
            status: GrindingProposalStatus.final_,
            currency: 'VND',
            machineId: 'M1',
            machineUnitPrice: 100000000,
            machineQuantity: 1,
            discount: 2000000,
            vatPercent: 10,
            technicalSnapshot: snapshot,
            rootProposalId: 10,
            revision: 0,
            createdAt: now,
            updatedAt: now,
            finalizedAt: now,
          ),
        ],
        lineItems: const [
          GrindingProposalLineItem(
            id: 100,
            proposalId: 10,
            kind: GrindingProposalLineItemKind.accessory,
            name: 'Cyclone phụ',
            quantity: 1,
            unitPrice: 5000000,
          ),
        ],
      );

      final encoded = GrindingBackupService.encode(payload);
      final decoded = GrindingBackupService.decode(encoded);

      expect(decoded.projects, hasLength(1));
      final project = decoded.projects.single;
      expect(project.projectName, 'Trà xanh Bảo Lộc');
      expect(project.customerName, 'Công ty ABC');
      expect(project.status, GrindingProjectStatus.evaluating);
      expect(project.nextFollowUpAt, DateTime(2026, 10, 1));
      expect(project.followUpNote, 'Gọi xác nhận');

      expect(decoded.projectMachines, hasLength(1));
      expect(decoded.projectMachines.single['machineId'], 'M1');
      expect(decoded.projectMachines.single['role'], 'primary');

      expect(decoded.proposals, hasLength(1));
      final proposal = decoded.proposals.single;
      expect(proposal.proposalNumber, 'GM-2026-0001');
      expect(proposal.status, GrindingProposalStatus.final_);
      expect(proposal.discount, 2000000);
      expect(proposal.vatPercent, 10);
      expect(proposal.rootProposalId, 10);
      expect(proposal.revision, 0);
      expect(proposal.technicalSnapshot, isNotNull);
      expect(proposal.technicalSnapshot!.model, 'ASP-350');
      expect(proposal.technicalSnapshot!.capacityDisplay, '300 - 500 kg/h');

      expect(decoded.lineItems, hasLength(1));
      expect(decoded.lineItems.single.name, 'Cyclone phụ');
      expect(decoded.lineItems.single.unitPrice, 5000000);
    });
  });

  group('Metadata', () {
    test('type/formatVersion/createdAt/appDatabaseVersion đúng', () {
      final payload = _payload(createdAt: DateTime(2026, 9, 24, 15, 30), appDatabaseVersion: 5);
      final json = jsonDecode(GrindingBackupService.encode(payload)) as Map<String, dynamic>;

      expect(json['type'], 'dtc_grinding_backup');
      expect(json['formatVersion'], 1);
      expect(json['createdAt'], DateTime(2026, 9, 24, 15, 30).toIso8601String());
      expect(json['appDatabaseVersion'], 5);
    });

    test('backupFormatVersion độc lập với databaseVersion (5 vs 1)', () {
      final payload = _payload(appDatabaseVersion: 5);
      expect(payload.formatVersion, 1);
      expect(payload.appDatabaseVersion, 5);
    });
  });

  group('Invalid backup', () {
    test('JSON hỏng -> corrupted, không throw raw exception khác', () {
      expect(
        () => GrindingBackupService.decode('{not valid json'),
        throwsA(
          isA<GrindingBackupException>().having(
            (e) => e.kind,
            'kind',
            GrindingBackupErrorKind.corrupted,
          ),
        ),
      );
    });

    test('Sai type -> corrupted', () {
      final json = jsonEncode({'type': 'something_else', 'formatVersion': 1});
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.corrupted)),
      );
    });

    test('Thiếu section bắt buộc -> corrupted', () {
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': DateTime(2026, 9, 24).toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [],
        // thiếu projectMachines/proposals/proposalLineItems
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.corrupted)),
      );
    });

    test('formatVersion tương lai (chưa hỗ trợ) -> unsupportedVersion, message đúng', () {
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 999,
        'createdAt': DateTime(2026, 9, 24).toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [],
        'projectMachines': [],
        'proposals': [],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(
          isA<GrindingBackupException>()
              .having((e) => e.kind, 'kind', GrindingBackupErrorKind.unsupportedVersion)
              .having((e) => e.message, 'message', 'Backup format is newer than this app version.'),
        ),
      );
    });

    test('Duplicate project id -> integrity', () {
      final now = DateTime(2026, 9, 24);
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': now.toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [
          {'id': 1, 'projectName': 'A', 'status': 'draft', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
          {'id': 1, 'projectName': 'B', 'status': 'draft', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
        ],
        'projectMachines': [],
        'proposals': [],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.integrity)),
      );
    });

    test('Duplicate revision trong cùng chain -> integrity', () {
      final now = DateTime(2026, 9, 24);
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': now.toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [
          {'id': 1, 'projectName': 'A', 'status': 'draft', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
        ],
        'projectMachines': [],
        'proposals': [
          {'id': 10, 'projectId': 1, 'status': 'draft', 'currency': 'VND', 'rootProposalId': 10, 'revision': 0, 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
          {'id': 11, 'projectId': 1, 'status': 'draft', 'currency': 'VND', 'rootProposalId': 10, 'revision': 0, 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
        ],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.integrity)),
      );
    });

    test('Enum status không hợp lệ -> corrupted', () {
      final now = DateTime(2026, 9, 24);
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': now.toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [
          {'id': 1, 'projectName': 'A', 'status': 'not_a_real_status', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
        ],
        'projectMachines': [],
        'proposals': [],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.corrupted)),
      );
    });

    test('Proposal tham chiếu projectId không tồn tại trong backup -> integrity (broken FK)', () {
      final now = DateTime(2026, 9, 24);
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': now.toIso8601String(),
        'appDatabaseVersion': 5,
        'projects': [],
        'projectMachines': [],
        'proposals': [
          {'id': 10, 'projectId': 999, 'status': 'draft', 'currency': 'VND', 'rootProposalId': 10, 'revision': 0, 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String()},
        ],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.integrity)),
      );
    });

    test('Malformed timestamp -> corrupted', () {
      final json = jsonEncode({
        'type': 'dtc_grinding_backup',
        'formatVersion': 1,
        'createdAt': 'not-a-date',
        'appDatabaseVersion': 5,
        'projects': [],
        'projectMachines': [],
        'proposals': [],
        'proposalLineItems': [],
      });
      expect(
        () => GrindingBackupService.decode(json),
        throwsA(isA<GrindingBackupException>().having((e) => e.kind, 'kind', GrindingBackupErrorKind.corrupted)),
      );
    });
  });

  group('Export/Restore với database thật', () {
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

    Future<int> seedProject(String name, {DateTime? followUp}) async {
      final now = DateTime(2026, 9, 24);
      return projectRepository.createProject(
        GrindingSelectionProject(
          projectName: name,
          status: GrindingProjectStatus.evaluating,
          nextFollowUpAt: followUp,
          createdAt: now,
          updatedAt: now,
        ),
        primaryMachineId: 'M1',
      );
    }

    test('Export: dữ liệu thật trong DB -> payload đúng count', () async {
      final projectId = await seedProject('Dự án A', followUp: DateTime(2026, 10, 1));
      final proposalId = await proposalRepository.createProposal(
        GrindingProposal(
          projectId: projectId,
          machineId: 'M1',
          machineUnitPrice: 100000000,
          machineQuantity: 1,
          createdAt: DateTime(2026, 9, 24),
          updatedAt: DateTime(2026, 9, 24),
        ),
        const [
          GrindingProposalLineItem(
            kind: GrindingProposalLineItemKind.accessory,
            name: 'Cyclone phụ',
            quantity: 1,
            unitPrice: 5000000,
          ),
        ],
      );
      await proposalRepository.createRevision(proposalId);

      final payload = await GrindingBackupService.exportPayload(
        projectRepository: projectRepository,
        proposalRepository: proposalRepository,
        appDatabaseVersion: 5,
      );

      expect(payload.projects, hasLength(1));
      expect(payload.projectMachines, hasLength(1));
      expect(payload.proposals, hasLength(2)); // R0 + R1
      // createRevision copy line items của R0 sang R1 -> 1 (R0) + 1 (R1) = 2.
      expect(payload.lineItems, hasLength(2));

      final parsedBack = GrindingBackupService.decode(GrindingBackupService.encode(payload));
      expect(parsedBack.projects.single.projectName, 'Dự án A');
      expect(parsedBack.proposals, hasLength(2));
    });

    test('Restore Replace: local data A bị thay bằng backup B, catalog máy không đổi', () async {
      // Data A (local hiện có).
      await seedProject('Data A - Project cũ');

      // Seed 1 dòng catalog để xác nhận KHÔNG bị đụng bởi restore.
      await database.insert('grinding_series', {
        'seriesCode': 'TEST_SERIES',
        'displayCode': 'TS',
        'nameVi': 'Test',
        'nameEn': 'Test',
      });

      final now = DateTime(2026, 9, 24);
      final payloadB = _payload(
        appDatabaseVersion: 5,
        projects: [
          GrindingSelectionProject(
            id: 500,
            projectName: 'Data B - Project mới',
            status: GrindingProjectStatus.selected,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        projectMachines: [
          {'projectId': 500, 'machineId': 'M9', 'role': 'primary', 'addedAt': now.toIso8601String()},
        ],
        proposals: [
          GrindingProposal(
            id: 900,
            projectId: 500,
            proposalNumber: 'GM-2026-0099',
            status: GrindingProposalStatus.draft,
            currency: 'USD',
            rootProposalId: 900,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await GrindingBackupService.restore(
        payload: payloadB,
        database: GrindingMachineDatabase.forTesting(database),
      );

      final projects = await projectRepository.getAllProjects();
      expect(projects, hasLength(1));
      expect(projects.single.projectName, 'Data B - Project mới');
      expect(projects.single.id, 500);

      final proposals = await proposalRepository.getAllProposals();
      expect(proposals, hasLength(1));
      expect(proposals.single.proposalNumber, 'GM-2026-0099');

      final relations = await projectRepository.getAllProjectMachineRelations();
      expect(relations, hasLength(1));
      expect(relations.single['machineId'], 'M9');

      // Catalog máy (bảng grinding_series) không bị đụng.
      final seriesRows = await database.query('grinding_series', where: 'seriesCode = ?', whereArgs: ['TEST_SERIES']);
      expect(seriesRows, hasLength(1));
    });

    test('Restore Rollback: lỗi giữa chừng -> local data A vẫn nguyên vẹn', () async {
      await seedProject('Data A không đổi');
      final before = await projectRepository.getAllProjects();
      expect(before, hasLength(1));

      // Trigger làm insert proposal có tên 'FAIL' lỗi giữa transaction.
      await database.execute('''
        CREATE TRIGGER fail_restore_proposal
        BEFORE INSERT ON grinding_proposals
        WHEN NEW.proposalNumber = 'FAIL'
        BEGIN SELECT RAISE(ABORT, 'restore failure'); END
      ''');

      final now = DateTime(2026, 9, 24);
      final badPayload = _payload(
        projects: [
          GrindingSelectionProject(id: 1, projectName: 'B', createdAt: now, updatedAt: now),
        ],
        proposals: [
          GrindingProposal(
            id: 1,
            projectId: 1,
            proposalNumber: 'FAIL',
            rootProposalId: 1,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await expectLater(
        GrindingBackupService.restore(
          payload: badPayload,
          database: GrindingMachineDatabase.forTesting(database),
        ),
        throwsA(isA<DatabaseException>()),
      );

      final after = await projectRepository.getAllProjects();
      expect(after, hasLength(1));
      expect(after.single.projectName, 'Data A không đổi');
    });

    test('Missing machine reference: restore vẫn thành công, đếm đúng số reference thiếu', () async {
      final now = DateTime(2026, 9, 24);
      final payload = _payload(
        projects: [
          GrindingSelectionProject(id: 1, projectName: 'P', createdAt: now, updatedAt: now),
        ],
        projectMachines: [
          {'projectId': 1, 'machineId': 'MACHINE_NOT_IN_CATALOG', 'role': 'primary', 'addedAt': now.toIso8601String()},
        ],
        proposals: [
          GrindingProposal(
            id: 1,
            projectId: 1,
            machineId: 'MACHINE_NOT_IN_CATALOG',
            status: GrindingProposalStatus.final_,
            rootProposalId: 1,
            revision: 0,
            technicalSnapshot: GrindingTechnicalSnapshot(
              machineId: 'MACHINE_NOT_IN_CATALOG',
              model: 'ASP-OLD',
              capturedAt: now,
            ),
            createdAt: now,
            updatedAt: now,
            finalizedAt: now,
          ),
        ],
      );

      final result = await GrindingBackupService.restore(
        payload: payload,
        database: GrindingMachineDatabase.forTesting(database),
        knownMachineIds: const {'M1', 'M2'},
      );

      expect(result.projectsRestored, 1);
      expect(result.revisionsRestored, 1);
      expect(result.missingMachineReferenceCount, 1);

      // Project/Proposal vẫn mở được bình thường (không crash), snapshot
      // vẫn còn nguyên để PDF Final vẫn dùng được.
      final restoredProposal = (await proposalRepository.getProposal(1))!;
      expect(restoredProposal.technicalSnapshot!.model, 'ASP-OLD');
    });

    test(
      'PDF Snapshot Consistency: Final Proposal PDF sau restore giống hệt trước backup (mục 40)',
      () async {
        final projectId = await seedProject('Dự án PDF');
        final proposalId = await proposalRepository.createProposal(
          GrindingProposal(
            projectId: projectId,
            machineId: 'M1',
            machineUnitPrice: 100000000,
            machineQuantity: 1,
            vatPercent: 10,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
          const [],
        );
        final snapshot = GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'ASP-350-SNAPSHOT',
          capacityDisplay: '300 - 500 kg/h',
          capturedAt: DateTime(2026, 9, 1),
        );
        await proposalRepository.finalizeProposal(proposalId, snapshot: snapshot);

        final project = (await projectRepository.getProject(projectId))!;
        final beforeProposal = (await proposalRepository.getProposal(proposalId))!;
        final beforeItems = await proposalRepository.getLineItems(proposalId);
        final beforeBytes = await GrindingProposalPdfService.buildPdf(
          project: project,
          proposal: beforeProposal,
          lineItems: beforeItems,
        );
        final beforeText = PdfTextExtractor(PdfDocument(inputBytes: beforeBytes)).extractText();

        final payload = await GrindingBackupService.exportPayload(
          projectRepository: projectRepository,
          proposalRepository: proposalRepository,
          appDatabaseVersion: 5,
        );
        await GrindingBackupService.restore(
          payload: payload,
          database: GrindingMachineDatabase.forTesting(database),
        );

        final afterProject = (await projectRepository.getProject(projectId))!;
        final afterProposal = (await proposalRepository.getProposal(proposalId))!;
        final afterItems = await proposalRepository.getLineItems(proposalId);
        final afterBytes = await GrindingProposalPdfService.buildPdf(
          project: afterProject,
          proposal: afterProposal,
          lineItems: afterItems,
        );
        final afterText = PdfTextExtractor(PdfDocument(inputBytes: afterBytes)).extractText();

        expect(afterProposal.technicalSnapshot!.model, beforeProposal.technicalSnapshot!.model);
        expect(afterText, beforeText);
      },
    );
  });
}
