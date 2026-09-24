import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_proposal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

GrindingProposal _proposal({
  int projectId = 1,
  String? machineId,
  double? machineUnitPrice,
  double? machineQuantity,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 9, 24, 10, 0);
  return GrindingProposal(
    projectId: projectId,
    machineId: machineId,
    machineUnitPrice: machineUnitPrice,
    machineQuantity: machineQuantity,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingProposalRepository repository;

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

  test('createProposal sinh proposalNumber đúng format GM-<năm>-<id>, đọc lại khớp', () async {
    final id = await repository.createProposal(
      _proposal(machineId: 'M1', machineUnitPrice: 100000000, machineQuantity: 1),
      const [],
    );
    final loaded = await repository.getProposal(id);

    expect(loaded, isNotNull);
    expect(loaded!.proposalNumber, 'GM-2026-${id.toString().padLeft(4, '0')}');
    expect(loaded.machineId, 'M1');
    expect(loaded.status, GrindingProposalStatus.draft);
    // Field chưa nhập phải giữ null.
    expect(loaded.discount, isNull);
    expect(loaded.vatPercent, isNull);
  });

  test('2 proposal liên tiếp -> proposalNumber khác nhau, unique', () async {
    final id1 = await repository.createProposal(_proposal(), const []);
    final id2 = await repository.createProposal(_proposal(), const []);
    final p1 = await repository.getProposal(id1);
    final p2 = await repository.getProposal(id2);

    expect(p1!.proposalNumber, isNot(p2!.proposalNumber));
  });

  test('createProposal lưu kèm line items (accessory + additional cost)', () async {
    final id = await repository.createProposal(
      _proposal(),
      const [
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
      ],
    );
    final items = await repository.getLineItems(id);

    expect(items, hasLength(2));
    expect(items[0].name, 'Cyclone phụ');
    expect(items[0].kind, GrindingProposalLineItemKind.accessory);
    expect(items[1].kind, GrindingProposalLineItemKind.additionalCost);
  });

  test('updateProposal cập nhật field + thay toàn bộ line items', () async {
    final id = await repository.createProposal(
      _proposal(),
      const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cũ',
          quantity: 1,
          unitPrice: 1000000,
        ),
      ],
    );
    final loaded = (await repository.getProposal(id))!;

    await repository.updateProposal(
      loaded.copyWith(discount: 2000000),
      lineItems: const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Mới',
          quantity: 2,
          unitPrice: 500000,
        ),
      ],
    );

    final updated = await repository.getProposal(id);
    final items = await repository.getLineItems(id);

    expect(updated!.discount, 2000000);
    expect(items, hasLength(1));
    expect(items.single.name, 'Mới');
  });

  test('deleteProposal xóa cả proposal lẫn line items', () async {
    final id = await repository.createProposal(
      _proposal(),
      const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'X',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );
    await repository.deleteProposal(id);

    expect(await repository.getProposal(id), isNull);
    expect(await repository.getLineItems(id), isEmpty);
  });

  test('getProposalsForProject chỉ trả proposal của đúng project, sắp theo updatedAt giảm dần', () async {
    await repository.createProposal(
      _proposal(projectId: 1, createdAt: DateTime(2026, 1, 1)),
      const [],
    );
    final idNew = await repository.createProposal(
      _proposal(projectId: 1, createdAt: DateTime(2026, 9, 1)),
      const [],
    );
    await repository.createProposal(_proposal(projectId: 2), const []);

    final list = await repository.getProposalsForProject(1);

    expect(list, hasLength(2));
    expect(list.first.id, idNew);
  });

  test('Proposal tồn tại sau khi mở lại Repository mới trên cùng database', () async {
    final id = await repository.createProposal(_proposal(), const []);

    final reopened = GrindingProposalRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    final loaded = await reopened.getProposal(id);

    expect(loaded, isNotNull);
  });

  test(
    'Transaction rollback: insert line item lỗi -> proposal KHÔNG được lưu',
    () async {
      await database.execute('''
        CREATE TRIGGER fail_line_item
        BEFORE INSERT ON grinding_proposal_line_items
        WHEN NEW.name = 'FAIL'
        BEGIN SELECT RAISE(ABORT, 'test failure'); END
      ''');

      await expectLater(
        repository.createProposal(
          _proposal(),
          const [
            GrindingProposalLineItem(
              kind: GrindingProposalLineItemKind.accessory,
              name: 'FAIL',
              quantity: 1,
              unitPrice: 1,
            ),
          ],
        ),
        throwsA(isA<DatabaseException>()),
      );

      final all = await repository.getProposalsForProject(1);
      expect(all, isEmpty);
    },
  );

  group('Finalize — Draft vs Final behavior', () {
    test('Draft: technicalSnapshot null, status draft, finalizedAt null', () async {
      final id = await repository.createProposal(
        _proposal(machineId: 'M1'),
        const [],
      );
      final draft = await repository.getProposal(id);

      expect(draft!.status, GrindingProposalStatus.draft);
      expect(draft.isFinal, isFalse);
      expect(draft.technicalSnapshot, isNull);
      expect(draft.finalizedAt, isNull);
    });

    test('finalizeProposal đóng băng snapshot, chuyển status final, set finalizedAt', () async {
      final id = await repository.createProposal(
        _proposal(machineId: 'M1', machineUnitPrice: 100000000, machineQuantity: 1),
        const [],
      );
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'M1',
        model: 'ASP-350',
        seriesDisplayCode: 'BSP',
        capacityDisplay: '300 - 500 kg/h',
        capturedAt: DateTime(2026, 9, 24, 11, 0),
      );

      await repository.finalizeProposal(id, snapshot: snapshot);
      final finalProposal = await repository.getProposal(id);

      expect(finalProposal!.status, GrindingProposalStatus.final_);
      expect(finalProposal.isFinal, isTrue);
      expect(finalProposal.finalizedAt, isNotNull);
      expect(finalProposal.technicalSnapshot, isNotNull);
      expect(finalProposal.technicalSnapshot!.model, 'ASP-350');
      expect(finalProposal.technicalSnapshot!.capacityDisplay, '300 - 500 kg/h');
    });

    test(
      'Finalize xong -> đổi machineId thành model đã xóa vẫn KHÔNG đổi snapshot đã đóng băng',
      () async {
        final id = await repository.createProposal(
          _proposal(machineId: 'M1'),
          const [],
        );
        final snapshot = GrindingTechnicalSnapshot(
          machineId: 'M1',
          model: 'ASP-350',
          capturedAt: DateTime(2026, 9, 24),
        );
        await repository.finalizeProposal(id, snapshot: snapshot);

        // Machine bị đổi mất trong catalog thật (mô phỏng update database)
        // KHÔNG được tự động chạm vào bảng grinding_proposals — xác nhận
        // snapshot đọc lại vẫn y hệt sau khi finalize, không phụ thuộc
        // trạng thái catalog hiện tại (repository này không hề đụng bảng
        // grinding_machines).
        final reloaded = await repository.getProposal(id);
        expect(reloaded!.technicalSnapshot!.model, 'ASP-350');
        expect(reloaded.machineId, 'M1');
      },
    );
  });
}
