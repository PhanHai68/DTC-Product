import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_change.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_diff_service.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_workflow_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

GrindingProposal _proposal({
  int projectId = 1,
  String? machineId,
  double? machineUnitPrice,
  double? machineQuantity,
  double? discount,
  double? vatPercent,
  String? deliveryTime,
  String? warranty,
  String? paymentTerms,
  int? validityDays,
  String? notes,
  GrindingTechnicalSnapshot? technicalSnapshot,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 9, 24, 10, 0);
  return GrindingProposal(
    projectId: projectId,
    machineId: machineId,
    machineUnitPrice: machineUnitPrice,
    machineQuantity: machineQuantity,
    discount: discount,
    vatPercent: vatPercent,
    deliveryTime: deliveryTime,
    warranty: warranty,
    paymentTerms: paymentTerms,
    validityDays: validityDays,
    notes: notes,
    technicalSnapshot: technicalSnapshot,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingProposalRepository repository;
  const workflow = GrindingProposalWorkflowService();
  const diffService = GrindingProposalDiffService();

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    repository = GrindingProposalRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createProposal (R0) tự set rootProposalId = id của chính nó', () async {
    final id = await repository.createProposal(_proposal(), const []);
    final loaded = await repository.getProposal(id);

    expect(loaded!.rootProposalId, id);
    expect(loaded.revision, 0);
    expect(loaded.isRoot, isTrue);
  });

  group('Create Revision', () {
    test(
      'R1 tạo từ R0 Final: Draft, cùng proposalNumber/rootProposalId, revision=1, copy commercial+line items, sentAt null',
      () async {
        final r0Id = await repository.createProposal(
          _proposal(
            machineId: 'M1',
            machineUnitPrice: 100000000,
            machineQuantity: 1,
            discount: 2000000,
            vatPercent: 10,
            deliveryTime: '4 tuần',
            warranty: '12 tháng',
            paymentTerms: '50/50',
            validityDays: 30,
            notes: 'Ghi chú R0',
          ),
          const [
            GrindingProposalLineItem(
              kind: GrindingProposalLineItemKind.accessory,
              name: 'Cyclone phụ',
              quantity: 1,
              unitPrice: 10000000,
            ),
          ],
        );
        final snapshot = GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'ASP-350',
          capturedAt: DateTime(2026, 9, 24),
        );
        await repository.finalizeProposal(r0Id, snapshot: snapshot);
        final r0 = (await repository.getProposal(r0Id))!;

        final r1Id = await repository.createRevision(r0Id);
        final r1 = (await repository.getProposal(r1Id))!;
        final r1Items = await repository.getLineItems(r1Id);

        expect(r1.status, GrindingProposalStatus.draft);
        expect(r1.proposalNumber, r0.proposalNumber);
        expect(r1.rootProposalId, r0Id);
        expect(r1.revision, 1);
        expect(r1.sentAt, isNull);
        expect(r1.acceptedAt, isNull);
        expect(r1.rejectedAt, isNull);
        expect(r1.machineUnitPrice, 100000000);
        expect(r1.discount, 2000000);
        expect(r1.vatPercent, 10);
        expect(r1.deliveryTime, '4 tuần');
        expect(r1.warranty, '12 tháng');
        expect(r1.paymentTerms, '50/50');
        expect(r1.validityDays, 30);
        expect(r1.notes, 'Ghi chú R0');
        expect(r1.technicalSnapshot?.model, 'ASP-350');
        expect(r1Items, hasLength(1));
        expect(r1Items.single.name, 'Cyclone phụ');
        expect(r1Items.single.proposalId, r1Id);
      },
    );

    test('R0 -> R1 -> R2: revision 0,1,2 không trùng lặp', () async {
      final r0Id = await repository.createProposal(_proposal(), const []);
      final r1Id = await repository.createRevision(r0Id);
      final r2Id = await repository.createRevision(r1Id);

      final revisions = await repository.getRevisions(r0Id);

      expect(revisions.map((p) => p.revision).toList(), [0, 1, 2]);
      expect(revisions.map((p) => p.id).toSet(), {r0Id, r1Id, r2Id});
      expect(revisions.every((p) => p.rootProposalId == r0Id), isTrue);
    });

    test(
      'Rollback: line item insert lỗi giữa transaction -> R1 KHÔNG tồn tại, R0 không đổi',
      () async {
        final r0Id = await repository.createProposal(
          _proposal(machineId: 'M1'),
          const [
            GrindingProposalLineItem(
              kind: GrindingProposalLineItemKind.accessory,
              name: 'FAIL',
              quantity: 1,
              unitPrice: 1,
            ),
          ],
        );
        await database.execute('''
          CREATE TRIGGER fail_revision_line_item
          BEFORE INSERT ON grinding_proposal_line_items
          WHEN NEW.name = 'FAIL'
          BEGIN SELECT RAISE(ABORT, 'test failure'); END
        ''');

        await expectLater(
          repository.createRevision(r0Id),
          throwsA(isA<DatabaseException>()),
        );

        final revisions = await repository.getRevisions(r0Id);
        expect(revisions, hasLength(1), reason: 'Chỉ còn R0, R1 không được tạo.');
        expect(revisions.single.id, r0Id);
      },
    );

    test(
      'Immutable: R0 Final rồi tạo R1 và sửa R1 -> R0 (commercial + snapshot) không đổi',
      () async {
        final r0Id = await repository.createProposal(
          _proposal(machineId: 'M1', machineUnitPrice: 100000000),
          const [],
        );
        final snapshot = GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'ASP-350',
          capturedAt: DateTime(2026, 9, 24),
        );
        await repository.finalizeProposal(r0Id, snapshot: snapshot);
        final r0Before = (await repository.getProposal(r0Id))!;

        final r1Id = await repository.createRevision(r0Id);
        final r1 = (await repository.getProposal(r1Id))!;
        await repository.updateProposal(
          r1.copyWith(machineUnitPrice: 200000000),
        );

        final r0After = (await repository.getProposal(r0Id))!;
        expect(r0After.machineUnitPrice, r0Before.machineUnitPrice);
        expect(r0After.status, GrindingProposalStatus.final_);
        expect(r0After.technicalSnapshot!.model, 'ASP-350');
      },
    );
  });

  group('Status workflow', () {
    test('Đường hợp lệ: Draft -> Final -> Sent -> Accepted', () async {
      final id = await repository.createProposal(_proposal(machineId: 'M1'), const []);
      var proposal = (await repository.getProposal(id))!;
      expect(workflow.canFinalize(proposal), isTrue);

      await repository.finalizeProposal(
        id,
        snapshot: GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'X',
          capturedAt: DateTime(2026, 9, 24),
        ),
      );
      proposal = (await repository.getProposal(id))!;
      expect(proposal.status, GrindingProposalStatus.final_);
      expect(workflow.canMarkSent(proposal), isTrue);

      await repository.markSent(id);
      proposal = (await repository.getProposal(id))!;
      expect(proposal.status, GrindingProposalStatus.sent);
      expect(proposal.sentAt, isNotNull);
      expect(workflow.canAccept(proposal), isTrue);
      expect(workflow.canReject(proposal), isTrue);

      final accepted = await repository.markAccepted(id, responseNote: 'OK');
      proposal = (await repository.getProposal(id))!;
      expect(accepted, isTrue);
      expect(proposal.status, GrindingProposalStatus.accepted);
      expect(proposal.acceptedAt, isNotNull);
      expect(proposal.responseNote, 'OK');
    });

    test('Đường hợp lệ khác: Sent -> Rejected', () async {
      final id = await repository.createProposal(_proposal(machineId: 'M1'), const []);
      await repository.finalizeProposal(
        id,
        snapshot: GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'X',
          capturedAt: DateTime(2026, 9, 24),
        ),
      );
      await repository.markSent(id);
      await repository.markRejected(id, responseNote: 'Không phù hợp');

      final proposal = (await repository.getProposal(id))!;
      expect(proposal.status, GrindingProposalStatus.rejected);
      expect(proposal.rejectedAt, isNotNull);
      expect(proposal.responseNote, 'Không phù hợp');
      // Rejected vẫn cho Create Revision, không bị chặn.
      expect(workflow.canCreateRevision(proposal), isTrue);
    });

    test('Transition không hợp lệ bị WorkflowService chặn (không ghi DB)', () {
      expect(
        workflow.validateTransition(
          from: GrindingProposalStatus.draft,
          to: GrindingProposalStatus.accepted,
        ),
        isFalse,
      );
      expect(
        workflow.validateTransition(
          from: GrindingProposalStatus.draft,
          to: GrindingProposalStatus.sent,
        ),
        isFalse,
      );
      expect(
        workflow.validateTransition(
          from: GrindingProposalStatus.accepted,
          to: GrindingProposalStatus.draft,
        ),
        isFalse,
      );
      expect(
        workflow.validateTransition(
          from: GrindingProposalStatus.final_,
          to: GrindingProposalStatus.sent,
        ),
        isTrue,
      );
    });

    test('canDelete: chỉ Draft; canCreateRevision: Final/Sent/Rejected, KHÔNG Accepted', () async {
      final draft = _proposal().copyWith(status: GrindingProposalStatus.draft);
      final final_ = _proposal().copyWith(status: GrindingProposalStatus.final_);
      final sent = _proposal().copyWith(status: GrindingProposalStatus.sent);
      final accepted = _proposal().copyWith(status: GrindingProposalStatus.accepted);
      final rejected = _proposal().copyWith(status: GrindingProposalStatus.rejected);

      expect(workflow.canDelete(draft), isTrue);
      expect(workflow.canDelete(final_), isFalse);
      expect(workflow.canDelete(sent), isFalse);
      expect(workflow.canDelete(accepted), isFalse);
      expect(workflow.canDelete(rejected), isFalse);

      expect(workflow.canCreateRevision(final_), isTrue);
      expect(workflow.canCreateRevision(sent), isTrue);
      expect(workflow.canCreateRevision(rejected), isTrue);
      expect(workflow.canCreateRevision(accepted), isFalse);
      expect(workflow.canCreateRevision(draft), isFalse);
    });
  });

  group('Expiry', () {
    test('Chưa hết hạn / đúng ngày hết hạn / đã hết hạn — deterministic qua now', () async {
      final finalizedAt = DateTime(2026, 1, 1);
      final proposal = _proposal(validityDays: 30).copyWith(
        status: GrindingProposalStatus.final_,
        finalizedAt: finalizedAt,
      );
      final expiry = finalizedAt.add(const Duration(days: 30));

      expect(
        workflow.isExpired(proposal, now: expiry.subtract(const Duration(days: 1))),
        isFalse,
      );
      expect(workflow.isExpired(proposal, now: expiry), isFalse);
      expect(
        workflow.isExpired(proposal, now: expiry.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('Thiếu validityDays hoặc finalizedAt/sentAt -> không tự suy đoán, không expired', () {
      final proposal = _proposal();
      expect(proposal.expiresAt, isNull);
      expect(workflow.isExpired(proposal), isFalse);
    });
  });

  group('Accepted conflict', () {
    test(
      'R1 đã Accepted -> mark Accepted R2 (cùng chain) bị chặn, R1 giữ Accepted, R2 giữ Sent',
      () async {
        final r0Id = await repository.createProposal(_proposal(machineId: 'M1'), const []);
        final snapshot = GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'X',
          capturedAt: DateTime(2026, 9, 24),
        );
        await repository.finalizeProposal(r0Id, snapshot: snapshot);
        await repository.markSent(r0Id);
        final acceptedR0 = await repository.markAccepted(r0Id);
        expect(acceptedR0, isTrue);

        final r1Id = await repository.createRevision(r0Id);
        await repository.finalizeProposal(r1Id, snapshot: snapshot);
        await repository.markSent(r1Id);

        final acceptedR1 = await repository.markAccepted(r1Id);
        expect(acceptedR1, isFalse, reason: 'Đã có R0 Accepted trong cùng chain -> phải bị chặn.');

        final r0 = (await repository.getProposal(r0Id))!;
        final r1 = (await repository.getProposal(r1Id))!;
        expect(r0.status, GrindingProposalStatus.accepted);
        expect(r1.status, GrindingProposalStatus.sent);
      },
    );
  });

  group('Revision chain queries', () {
    test('getLatestRevision trả đúng revision cao nhất', () async {
      final r0Id = await repository.createProposal(_proposal(), const []);
      final r1Id = await repository.createRevision(r0Id);

      final latest = await repository.getLatestRevision(r0Id);
      expect(latest!.id, r1Id);
      expect(latest.revision, 1);
    });

    test('getProposalChainsByProject nhóm đúng theo chain, không lẫn giữa 2 chain khác nhau', () async {
      final chainAR0 = await repository.createProposal(
        _proposal(projectId: 5, createdAt: DateTime(2026, 1, 1)),
        const [],
      );
      await repository.createRevision(chainAR0);
      await repository.createProposal(
        _proposal(projectId: 5, createdAt: DateTime(2026, 2, 1)),
        const [],
      );

      final chains = await repository.getProposalChainsByProject(5);

      expect(chains, hasLength(2));
      final chainA = chains.firstWhere((c) => c.first.id == chainAR0);
      expect(chainA.map((p) => p.revision).toList(), [0, 1]);
    });
  });

  group('Diff service', () {
    test('So R0 vs R1: đổi giá, VAT, thêm dòng, đổi thời gian giao hàng', () {
      final r0 = _proposal(
        machineUnitPrice: 100000000,
        vatPercent: 8,
        deliveryTime: '4 tuần',
      );
      final r1 = _proposal(
        machineUnitPrice: 120000000,
        vatPercent: 10,
        deliveryTime: '6 tuần',
      );
      const oldItems = [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: 10000000,
        ),
      ];
      const newItems = [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: 10000000,
        ),
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.additionalCost,
          name: 'Shipping',
          quantity: 1,
          unitPrice: 3000000,
        ),
      ];

      final changes = diffService.diff(
        oldProposal: r0,
        oldLineItems: oldItems,
        newProposal: r1,
        newLineItems: newItems,
      );

      bool hasChange(String field) => changes.any((c) => c.field == field);
      expect(hasChange('Đơn giá máy'), isTrue);
      expect(hasChange('VAT (%)'), isTrue);
      expect(hasChange('Thời gian giao hàng'), isTrue);
      expect(hasChange('Thêm dòng: Shipping'), isTrue);
      expect(
        changes
            .where((c) => c.category == GrindingProposalChangeCategory.commercial)
            .length,
        greaterThanOrEqualTo(2),
      );
    });

    test('Không có thay đổi gì -> danh sách rỗng', () {
      final p = _proposal(machineUnitPrice: 100000000);
      final changes = diffService.diff(
        oldProposal: p,
        oldLineItems: const [],
        newProposal: p,
        newLineItems: const [],
      );
      expect(changes, isEmpty);
    });
  });
}
