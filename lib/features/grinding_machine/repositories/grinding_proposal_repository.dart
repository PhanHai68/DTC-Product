import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/grinding_machine_database.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_technical_snapshot.dart';

/// Repository RIÊNG cho "Technical Proposal / Quotation" (Phase 8) — domain
/// khác catalog máy VÀ khác Engineering Project (Phase 7), dùng chung 1
/// database nhưng chỉ đụng 2 bảng `grinding_proposals`/
/// `grinding_proposal_line_items`.
class GrindingProposalRepository {
  GrindingProposalRepository({GrindingMachineDatabase? database})
    : _db = database ?? GrindingMachineDatabase.instance;

  final GrindingMachineDatabase _db;

  Map<String, dynamic> _map(Map<String, Object?> row) =>
      Map<String, dynamic>.from(row);

  /// Lưu [proposal] mới + [lineItems] trong CÙNG 1 transaction. `proposalNumber`
  /// KHÔNG được sinh trước (tránh cần bảng đếm riêng có nguy cơ race) — thay
  /// vào đó derive TỪ id AUTOINCREMENT vừa insert (`GM-<năm>-<id 4 số>`),
  /// ghi UPDATE ngay trong transaction, không ai đọc được dòng thiếu số.
  Future<int> createProposal(
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
  ) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final id = await txn.insert('grinding_proposals', proposal.toRow());
      final proposalNumber =
          'GM-${proposal.createdAt.year}-${id.toString().padLeft(4, '0')}';
      // R0 luôn là gốc chain của chính nó — set rootProposalId = id ngay
      // trong transaction, cùng lúc với proposalNumber (mục 2-3, Phase 9).
      await txn.update(
        'grinding_proposals',
        {
          'proposalNumber': proposalNumber,
          'rootProposalId': proposal.rootProposalId ?? id,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _insertLineItems(txn, id, lineItems);
      return id;
    });
  }

  /// Tạo revision mới TỪ [sourceProposalId] (thường là revision mới nhất
  /// của chain) — copy dữ liệu thương mại + line items + snapshot kỹ thuật
  /// làm điểm khởi đầu, KHÔNG copy id/status/sentAt/acceptedAt/rejectedAt
  /// (mục 16). Revision mới luôn Draft. `revision` mới derive bằng
  /// `MAX(revision)+1` NGAY TRONG transaction (mục 32) — không tính ở
  /// caller — và insert proposal + line items atomically: lỗi giữa chừng
  /// (vd line item insert fail) rollback toàn bộ, R1 không tồn tại, R0
  /// không đổi (mục 28).
  Future<int> createRevision(int sourceProposalId) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'grinding_proposals',
        where: 'id = ?',
        whereArgs: [sourceProposalId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Proposal $sourceProposalId không tồn tại.');
      }
      final source = GrindingProposal.fromRow(_map(rows.first));
      final rootId = source.rootProposalId ?? source.id!;

      final maxRevRows = await txn.rawQuery(
        'SELECT MAX(revision) AS maxRev FROM grinding_proposals WHERE rootProposalId = ?',
        [rootId],
      );
      final maxRev =
          (maxRevRows.first['maxRev'] as int?) ?? source.revision;
      final nextRevision = maxRev + 1;

      final now = DateTime.now();
      final newProposal = GrindingProposal(
        projectId: source.projectId,
        proposalNumber: source.proposalNumber,
        status: GrindingProposalStatus.draft,
        currency: source.currency,
        machineId: source.machineId,
        machineUnitPrice: source.machineUnitPrice,
        machineQuantity: source.machineQuantity,
        discount: source.discount,
        vatPercent: source.vatPercent,
        notes: source.notes,
        technicalSnapshot: source.technicalSnapshot,
        rootProposalId: rootId,
        revision: nextRevision,
        validityDays: source.validityDays,
        deliveryTime: source.deliveryTime,
        warranty: source.warranty,
        paymentTerms: source.paymentTerms,
        createdAt: now,
        updatedAt: now,
      );
      final newId = await txn.insert(
        'grinding_proposals',
        newProposal.toRow(),
      );

      final lineItemRows = await txn.query(
        'grinding_proposal_line_items',
        where: 'proposalId = ?',
        whereArgs: [sourceProposalId],
        orderBy: 'sortOrder ASC, id ASC',
      );
      final items = lineItemRows
          .map((r) => GrindingProposalLineItem.fromRow(_map(r)))
          .toList();
      await _insertLineItems(txn, newId, items);
      return newId;
    });
  }

  Future<void> _insertLineItems(
    Transaction txn,
    int proposalId,
    List<GrindingProposalLineItem> lineItems,
  ) async {
    final batch = txn.batch();
    for (final item in lineItems) {
      batch.insert(
        'grinding_proposal_line_items',
        item.copyWith(proposalId: proposalId).toRow()..remove('id'),
      );
    }
    await batch.commit(noResult: true);
  }

  /// Cập nhật [proposal] (Draft) + thay TOÀN BỘ line items — chỉ dùng cho
  /// Proposal còn Draft; gọi trên Proposal `final` sẽ vẫn ghi được ở tầng
  /// Repository (không tự chặn ở đây) nhưng UI (mục 8) khóa field khi Final
  /// nên trong luồng bình thường không xảy ra.
  Future<void> updateProposal(
    GrindingProposal proposal, {
    List<GrindingProposalLineItem>? lineItems,
  }) async {
    final id = proposal.id;
    if (id == null) {
      throw ArgumentError('updateProposal yêu cầu proposal.id đã tồn tại.');
    }
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'grinding_proposals',
        proposal.toRow(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (lineItems != null) {
        await txn.delete(
          'grinding_proposal_line_items',
          where: 'proposalId = ?',
          whereArgs: [id],
        );
        await _insertLineItems(txn, id, lineItems);
      }
    });
  }

  /// Đóng băng [snapshot] + chuyển status sang `final` — TỪ THỜI ĐIỂM NÀY,
  /// PDF/UI của proposal này phải đọc [GrindingProposal.technicalSnapshot],
  /// KHÔNG đọc lại catalog máy nữa (mục "Technical Snapshot" Phase 8).
  Future<void> finalizeProposal(
    int id, {
    required GrindingTechnicalSnapshot snapshot,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update(
      'grinding_proposals',
      {
        'status': GrindingProposalStatus.final_.value,
        'technicalSnapshotJson': jsonEncode(snapshot.toJson()),
        'finalizedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<GrindingProposal?> getProposal(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_proposals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingProposal.fromRow(_map(rows.first));
  }

  Future<List<GrindingProposalLineItem>> getLineItems(int proposalId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_proposal_line_items',
      where: 'proposalId = ?',
      whereArgs: [proposalId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map((r) => GrindingProposalLineItem.fromRow(_map(r))).toList();
  }

  /// TOÀN BỘ line items (mọi proposal) — dùng cho Backup (Phase 11).
  Future<List<GrindingProposalLineItem>> getAllLineItems() async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_proposal_line_items',
      orderBy: 'proposalId ASC, sortOrder ASC, id ASC',
    );
    return rows.map((r) => GrindingProposalLineItem.fromRow(_map(r))).toList();
  }

  Future<List<GrindingProposal>> getProposalsForProject(int projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_proposals',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => GrindingProposal.fromRow(_map(r))).toList();
  }

  /// TOÀN BỘ proposal (mọi project, mọi chain, mọi revision) trong 1 lần
  /// query — dùng cho Dashboard (Phase 10) tổng hợp KPI, tránh N+1 khi phải
  /// duyệt qua từng project riêng lẻ.
  Future<List<GrindingProposal>> getAllProposals() async {
    final db = await _db.database;
    final rows = await db.query('grinding_proposals', orderBy: 'updatedAt DESC');
    return rows.map((r) => GrindingProposal.fromRow(_map(r))).toList();
  }

  /// Batch-load line items cho nhiều [proposalIds] trong 1 query `IN (...)`
  /// — Dashboard (Phase 10) chỉ cần line items của latest revision mỗi
  /// chain, KHÔNG cần duyệt `getLineItems` cho từng proposal (N+1).
  Future<Map<int, List<GrindingProposalLineItem>>> getLineItemsForProposals(
    List<int> proposalIds,
  ) async {
    if (proposalIds.isEmpty) return {};
    final db = await _db.database;
    final placeholders = List.filled(proposalIds.length, '?').join(',');
    final rows = await db.query(
      'grinding_proposal_line_items',
      where: 'proposalId IN ($placeholders)',
      whereArgs: proposalIds,
      orderBy: 'proposalId ASC, sortOrder ASC, id ASC',
    );
    final map = <int, List<GrindingProposalLineItem>>{};
    for (final row in rows) {
      final item = GrindingProposalLineItem.fromRow(_map(row));
      map.putIfAbsent(item.proposalId!, () => []).add(item);
    }
    return map;
  }

  /// Toàn bộ revision của 1 chain, sắp theo revision TĂNG DẦN (R0, R1, R2...).
  Future<List<GrindingProposal>> getRevisions(int rootProposalId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_proposals',
      where: 'rootProposalId = ?',
      whereArgs: [rootProposalId],
      orderBy: 'revision ASC',
    );
    return rows.map((r) => GrindingProposal.fromRow(_map(r))).toList();
  }

  Future<GrindingProposal?> getLatestRevision(int rootProposalId) async {
    final revisions = await getRevisions(rootProposalId);
    return revisions.isEmpty ? null : revisions.last;
  }

  /// Nhóm toàn bộ proposal của [projectId] theo chain (rootProposalId) —
  /// mỗi phần tử trả về là 1 chain (list revision sắp ASC theo revision);
  /// các chain sắp theo hoạt động gần nhất (revision mới nhất của chain đó)
  /// trước, phục vụ Project Detail hiển thị gộp (mục 14-15).
  Future<List<List<GrindingProposal>>> getProposalChainsByProject(
    int projectId,
  ) async {
    final all = await getProposalsForProject(projectId);
    final byRoot = <int, List<GrindingProposal>>{};
    for (final p in all) {
      final rootId = p.rootProposalId ?? p.id!;
      byRoot.putIfAbsent(rootId, () => []).add(p);
    }
    final chains = byRoot.values.toList();
    for (final chain in chains) {
      chain.sort((a, b) => a.revision.compareTo(b.revision));
    }
    chains.sort((a, b) => b.last.updatedAt.compareTo(a.last.updatedAt));
    return chains;
  }

  /// Chuyển [id] sang Sent — lưu [sentAt] (mục 10; `sentBy` bỏ qua vì app
  /// chưa có user context; không có `sentNote` field theo schema đã chốt).
  Future<void> markSent(int id) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update(
      'grinding_proposals',
      {
        'status': GrindingProposalStatus.sent.value,
        'sentAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Chuyển [id] sang Accepted — CHẶN (trả `false`, không ghi gì) nếu đã có
  /// revision KHÁC cùng chain đang Accepted, giữ logic đơn giản theo đúng
  /// lựa chọn của người dùng (mục 20). `true` nếu ghi thành công.
  Future<bool> markAccepted(int id, {String? responseNote}) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'grinding_proposals',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Proposal $id không tồn tại.');
      }
      final proposal = GrindingProposal.fromRow(_map(rows.first));
      final rootId = proposal.rootProposalId ?? proposal.id!;
      final alreadyAccepted = await txn.query(
        'grinding_proposals',
        where: 'rootProposalId = ? AND status = ? AND id != ?',
        whereArgs: [rootId, GrindingProposalStatus.accepted.value, id],
      );
      if (alreadyAccepted.isNotEmpty) {
        return false;
      }
      final now = DateTime.now();
      await txn.update(
        'grinding_proposals',
        {
          'status': GrindingProposalStatus.accepted.value,
          'acceptedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'responseNote': ?responseNote,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    });
  }

  Future<void> markRejected(int id, {String? responseNote}) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update(
      'grinding_proposals',
      {
        'status': GrindingProposalStatus.rejected.value,
        'rejectedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'responseNote': ?responseNote,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProposal(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'grinding_proposal_line_items',
        where: 'proposalId = ?',
        whereArgs: [id],
      );
      await txn.delete('grinding_proposals', where: 'id = ?', whereArgs: [id]);
    });
  }
}
