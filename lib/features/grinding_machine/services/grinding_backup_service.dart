import 'dart:convert';

import '../data/grinding_machine_database.dart';
import '../models/grinding_backup.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_selection_project.dart';
import '../repositories/grinding_proposal_repository.dart';
import '../repositories/grinding_selection_project_repository.dart';

const _knownProjectStatus = {'draft', 'evaluating', 'selected', 'completed'};
const _knownProposalStatus = {'draft', 'final', 'sent', 'accepted', 'rejected'};

/// Backup/Restore "logical" (Option B, Phase 11 mục 2) cho dữ liệu workflow
/// module Máy nghiền — Saved Projects + quan hệ máy + Proposals + revision
/// chain + line items + technical snapshot + commercial fields. KHÔNG backup
/// catalog máy (phục hồi qua Excel/JSON seed sẵn có).
///
/// Chọn Option B thay vì backup nguyên file SQLite vì: (1) dễ validate
/// từng field trước khi ghi — SQLite file không tự mô tả được field nào
/// hợp lệ; (2) dễ version độc lập với `databaseVersion` (mục 4) — schema
/// SQLite đổi không bắt buộc đổi format backup; (3) restore được giữa các
/// bản app khác `databaseVersion` miễn còn field cần thiết; (4) không kéo
/// theo catalog máy (nặng, đã có nguồn phục hồi riêng qua Excel/JSON).
///
/// Toàn bộ logic (export/serialize/validate/import) nằm ở đây — KHÔNG đặt
/// trong Widget (mục 5). Restore là giao dịch (transaction) DUY NHẤT xuyên
/// 2 domain project+proposal — ngoại lệ có chủ đích với quy ước "mỗi
/// Repository chỉ đụng bảng của mình", vì backup/restore vốn là thao tác
/// xuyên domain, cần atomic thật sự (mục 11).
abstract final class GrindingBackupService {
  static const supportedFormatVersion = 1;

  static Future<GrindingBackupPayload> exportPayload({
    required GrindingSelectionProjectRepository projectRepository,
    required GrindingProposalRepository proposalRepository,
    required int appDatabaseVersion,
    DateTime? now,
  }) async {
    final projects = await projectRepository.getAllProjects();
    final projectMachines = await projectRepository.getAllProjectMachineRelations();
    final proposals = await proposalRepository.getAllProposals();
    final lineItems = await proposalRepository.getAllLineItems();
    return GrindingBackupPayload(
      formatVersion: supportedFormatVersion,
      createdAt: now ?? DateTime.now(),
      appDatabaseVersion: appDatabaseVersion,
      projects: projects,
      projectMachines: projectMachines,
      proposals: proposals,
      lineItems: lineItems,
    );
  }

  static String encode(GrindingBackupPayload payload) =>
      const JsonEncoder.withIndent('  ').convert(payload.toJson());

  /// Parse + validate TOÀN BỘ (mục 14) — ném [GrindingBackupException] với
  /// [GrindingBackupErrorKind] rõ ràng nếu có bất kỳ vấn đề gì; KHÔNG bao
  /// giờ trả về payload "một phần hợp lệ".
  static GrindingBackupPayload decode(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
      );
    }
    return _parse(decoded);
  }

  static GrindingBackupPayload _parse(Map<String, dynamic> json) {
    if (json['type'] != GrindingBackupPayload.type) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: ['File không đúng định dạng backup của Máy nghiền.'],
      );
    }

    final formatVersion = json['formatVersion'];
    if (formatVersion is! int) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: ['Thiếu hoặc sai kiểu formatVersion.'],
      );
    }
    if (formatVersion > supportedFormatVersion) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.unsupportedVersion,
        'Backup format is newer than this app version.',
      );
    }

    final createdAtRaw = json['createdAt'];
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtRaw as String);
    } catch (_) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: ['createdAt không hợp lệ.'],
      );
    }

    final appDatabaseVersion = json['appDatabaseVersion'];
    if (appDatabaseVersion is! int) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: ['Thiếu hoặc sai kiểu appDatabaseVersion.'],
      );
    }

    final projectsRaw = json['projects'];
    final projectMachinesRaw = json['projectMachines'];
    final proposalsRaw = json['proposals'];
    final lineItemsRaw = json['proposalLineItems'];
    if (projectsRaw is! List ||
        projectMachinesRaw is! List ||
        proposalsRaw is! List ||
        lineItemsRaw is! List) {
      throw const GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: ['Thiếu section bắt buộc (projects/projectMachines/proposals/proposalLineItems).'],
      );
    }

    final parseErrors = <String>[];
    final projects = <GrindingSelectionProject>[];
    for (var i = 0; i < projectsRaw.length; i++) {
      final row = _asRow(projectsRaw[i]);
      if (row == null) {
        parseErrors.add('projects[$i]: không phải object hợp lệ.');
        continue;
      }
      if (row['status'] != null && !_knownProjectStatus.contains(row['status'])) {
        parseErrors.add('projects[$i]: status không hợp lệ (${row['status']}).');
        continue;
      }
      try {
        projects.add(GrindingSelectionProject.fromRow(row));
      } catch (e) {
        parseErrors.add('projects[$i]: dữ liệu hỏng ($e).');
      }
    }

    final projectMachines = <Map<String, Object?>>[];
    for (var i = 0; i < projectMachinesRaw.length; i++) {
      final row = _asRow(projectMachinesRaw[i]);
      if (row == null || row['projectId'] is! int || row['machineId'] is! String) {
        parseErrors.add('projectMachines[$i]: dữ liệu hỏng.');
        continue;
      }
      projectMachines.add(row);
    }

    final proposals = <GrindingProposal>[];
    for (var i = 0; i < proposalsRaw.length; i++) {
      final row = _asRow(proposalsRaw[i]);
      if (row == null) {
        parseErrors.add('proposals[$i]: không phải object hợp lệ.');
        continue;
      }
      if (row['status'] != null && !_knownProposalStatus.contains(row['status'])) {
        parseErrors.add('proposals[$i]: status không hợp lệ (${row['status']}).');
        continue;
      }
      try {
        proposals.add(GrindingProposal.fromRow(row));
      } catch (e) {
        parseErrors.add('proposals[$i]: dữ liệu hỏng ($e).');
      }
    }

    final lineItems = <GrindingProposalLineItem>[];
    for (var i = 0; i < lineItemsRaw.length; i++) {
      final row = _asRow(lineItemsRaw[i]);
      if (row == null) {
        parseErrors.add('proposalLineItems[$i]: không phải object hợp lệ.');
        continue;
      }
      try {
        lineItems.add(GrindingProposalLineItem.fromRow(row));
      } catch (e) {
        parseErrors.add('proposalLineItems[$i]: dữ liệu hỏng ($e).');
      }
    }

    if (parseErrors.isNotEmpty) {
      throw GrindingBackupException(
        GrindingBackupErrorKind.corrupted,
        'Invalid or corrupted backup file',
        details: parseErrors,
      );
    }

    final integrityErrors = _validateIntegrity(
      projects: projects,
      projectMachines: projectMachines,
      proposals: proposals,
      lineItems: lineItems,
    );
    if (integrityErrors.isNotEmpty) {
      throw GrindingBackupException(
        GrindingBackupErrorKind.integrity,
        'Backup data is inconsistent.',
        details: integrityErrors,
      );
    }

    return GrindingBackupPayload(
      formatVersion: formatVersion,
      createdAt: createdAt,
      appDatabaseVersion: appDatabaseVersion,
      projects: projects,
      projectMachines: projectMachines,
      proposals: proposals,
      lineItems: lineItems,
    );
  }

  static Map<String, Object?>? _asRow(dynamic value) {
    if (value is! Map) return null;
    return Map<String, Object?>.from(value);
  }

  static List<String> _validateIntegrity({
    required List<GrindingSelectionProject> projects,
    required List<Map<String, Object?>> projectMachines,
    required List<GrindingProposal> proposals,
    required List<GrindingProposalLineItem> lineItems,
  }) {
    final errors = <String>[];

    final projectIds = <int>{};
    for (final p in projects) {
      if (p.id == null) {
        errors.add('Project "${p.projectName}" thiếu id.');
        continue;
      }
      if (!projectIds.add(p.id!)) {
        errors.add('Project id trùng lặp: ${p.id}.');
      }
    }

    final proposalIds = <int>{};
    final chainRevisions = <String>{};
    for (final p in proposals) {
      if (p.id == null) {
        errors.add('Proposal ${p.proposalNumber ?? '(chưa có số)'} thiếu id.');
        continue;
      }
      if (!proposalIds.add(p.id!)) {
        errors.add('Proposal id trùng lặp: ${p.id}.');
      }
      final rootId = p.rootProposalId ?? p.id;
      final key = '$rootId#${p.revision}';
      if (!chainRevisions.add(key)) {
        errors.add('Revision trùng trong cùng chain: rootProposalId=$rootId, revision=${p.revision}.');
      }
      if (!projectIds.contains(p.projectId)) {
        errors.add('Proposal ${p.id} tham chiếu projectId ${p.projectId} không tồn tại trong backup.');
      }
    }

    for (final item in lineItems) {
      if (item.proposalId == null || !proposalIds.contains(item.proposalId)) {
        errors.add('Line item "${item.name}" tham chiếu proposalId không tồn tại trong backup.');
      }
    }

    for (final row in projectMachines) {
      final projectId = row['projectId'];
      if (projectId is! int || !projectIds.contains(projectId)) {
        errors.add('Project machine relation tham chiếu projectId không tồn tại trong backup.');
      }
    }

    return errors;
  }

  /// Đếm số project/proposal trong [payload] tham chiếu `machineId` KHÔNG
  /// có trong [knownMachineIds] (catalog hiện tại) — CHỈ cảnh báo, không
  /// chặn (mục 13).
  static int countMissingMachineReferences(
    GrindingBackupPayload payload,
    Set<String> knownMachineIds,
  ) {
    final referenced = <String>{};
    for (final row in payload.projectMachines) {
      final machineId = row['machineId'];
      if (machineId is String) referenced.add(machineId);
    }
    for (final p in payload.proposals) {
      if (p.machineId != null) referenced.add(p.machineId!);
    }
    return referenced.where((id) => !knownMachineIds.contains(id)).length;
  }

  static GrindingRestorePreview buildPreview({
    required GrindingBackupPayload payload,
    required int currentProjectCount,
    required int currentProposalCount,
    required Set<String> knownMachineIds,
  }) {
    final chains = GrindingProposal.groupByChain(payload.proposals);
    return GrindingRestorePreview(
      createdAt: payload.createdAt,
      formatVersion: payload.formatVersion,
      projectCount: payload.projects.length,
      proposalChainCount: chains.length,
      revisionCount: payload.proposals.length,
      lineItemCount: payload.lineItems.length,
      currentProjectCount: currentProjectCount,
      currentProposalCount: currentProposalCount,
      missingMachineReferenceCount: countMissingMachineReferences(payload, knownMachineIds),
    );
  }

  /// Restore mode "Replace workflow data" (mục 10) — XÓA TOÀN BỘ 4 bảng
  /// workflow rồi ghi lại từ [payload], ATOMIC trong 1 transaction (mục
  /// 11): lỗi giữa chừng rollback toàn bộ, không để trạng thái nửa vời.
  /// GIỮ NGUYÊN id gốc trong backup (mục 12) — đơn giản, deterministic,
  /// không cần remap vì bảng đã bị xóa sạch trước khi insert nên không có
  /// collision. KHÔNG đụng catalog máy (mục 10, 45).
  static Future<GrindingRestoreResult> restore({
    required GrindingBackupPayload payload,
    required GrindingMachineDatabase database,
    Set<String> knownMachineIds = const {},
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.delete('grinding_proposal_line_items');
      await txn.delete('grinding_proposals');
      await txn.delete('grinding_selection_project_machines');
      await txn.delete('grinding_selection_projects');

      final projectBatch = txn.batch();
      for (final project in payload.projects) {
        projectBatch.insert('grinding_selection_projects', project.toRow());
      }
      await projectBatch.commit(noResult: true);

      final relationBatch = txn.batch();
      for (final row in payload.projectMachines) {
        relationBatch.insert('grinding_selection_project_machines', row);
      }
      await relationBatch.commit(noResult: true);

      final proposalBatch = txn.batch();
      for (final proposal in payload.proposals) {
        proposalBatch.insert('grinding_proposals', proposal.toRow());
      }
      await proposalBatch.commit(noResult: true);

      final lineItemBatch = txn.batch();
      for (final item in payload.lineItems) {
        lineItemBatch.insert('grinding_proposal_line_items', item.toRow());
      }
      await lineItemBatch.commit(noResult: true);
    });

    final chains = GrindingProposal.groupByChain(payload.proposals);
    return GrindingRestoreResult(
      projectsRestored: payload.projects.length,
      proposalChainsRestored: chains.length,
      revisionsRestored: payload.proposals.length,
      lineItemsRestored: payload.lineItems.length,
      missingMachineReferenceCount: countMissingMachineReferences(payload, knownMachineIds),
    );
  }
}
