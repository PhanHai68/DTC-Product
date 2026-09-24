import 'package:flutter/foundation.dart';

import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_change.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_technical_snapshot.dart';
import '../repositories/grinding_proposal_repository.dart';
import '../services/grinding_proposal_diff_service.dart';
import '../services/grinding_proposal_workflow_service.dart';

/// Quản lý Proposal (Phase 8) cho 1 Project — domain RIÊNG với
/// [GrindingSelectionProjectProvider] (Phase 7) và [GrindingMachineProvider]
/// (catalog). Giữ tối giản: chỉ CRUD + Finalize qua Repository, không tự
/// đọc catalog máy (màn hình tự lấy dữ liệu máy hiện tại qua
/// GrindingMachineProvider rồi truyền vào [finalizeProposal]).
///
/// Phase 9: thêm revision chain + status workflow thương mại — logic quyền
/// hành động/transition hợp lệ nằm ở [GrindingProposalWorkflowService]
/// (KHÔNG viết lại ở đây/Widget), Provider chỉ gọi Repository/Service rồi
/// notify.
class GrindingProposalProvider extends ChangeNotifier {
  GrindingProposalProvider({
    GrindingProposalRepository? repository,
    GrindingProposalWorkflowService? workflowService,
    GrindingProposalDiffService? diffService,
  }) : _repository = repository ?? GrindingProposalRepository(),
       _workflow = workflowService ?? const GrindingProposalWorkflowService(),
       _diff = diffService ?? const GrindingProposalDiffService();

  final GrindingProposalRepository _repository;
  final GrindingProposalWorkflowService _workflow;
  final GrindingProposalDiffService _diff;

  GrindingProposalWorkflowService get workflow => _workflow;

  List<GrindingProposal> _proposals = const [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<GrindingProposal> get proposals => _proposals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadForProject(int projectId) async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _proposals = await _repository.getProposalsForProject(projectId);
    } catch (error) {
      _error = 'Không thể tải danh sách proposal: $error';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<int> createProposal(
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
  ) async {
    final id = await _repository.createProposal(proposal, lineItems);
    await loadForProject(proposal.projectId);
    return id;
  }

  Future<void> updateProposal(
    GrindingProposal proposal, {
    List<GrindingProposalLineItem>? lineItems,
  }) async {
    await _repository.updateProposal(proposal, lineItems: lineItems);
    await loadForProject(proposal.projectId);
  }

  Future<void> finalizeProposal(
    int id, {
    required int projectId,
    required GrindingTechnicalSnapshot snapshot,
  }) async {
    await _repository.finalizeProposal(id, snapshot: snapshot);
    await loadForProject(projectId);
  }

  /// Chỉ xoá được Draft (mục 22) — kiểm tra qua [GrindingProposalWorkflowService]
  /// TRƯỚC khi gọi Repository, không đặt rule này ở Repository (Repository
  /// giữ vai trò pure data access). Ném [StateError] nếu bị chặn — UI bình
  /// thường không hiện nút Delete cho proposal không phải Draft nên trường
  /// hợp này chỉ xảy ra khi có lỗi lập trình.
  Future<void> deleteProposal(int id, {required int projectId}) async {
    final proposal = await _repository.getProposal(id);
    if (proposal == null) return;
    if (!_workflow.canDelete(proposal)) {
      throw StateError('Chỉ Proposal Draft mới xoá trực tiếp được.');
    }
    await _repository.deleteProposal(id);
    await loadForProject(projectId);
  }

  Future<GrindingProposal?> getProposal(int id) => _repository.getProposal(id);

  Future<List<GrindingProposalLineItem>> getLineItems(int proposalId) =>
      _repository.getLineItems(proposalId);

  /// Tạo revision mới từ [sourceProposalId] (thường là revision mới nhất
  /// của chain) — kiểm tra [GrindingProposalWorkflowService.canCreateRevision]
  /// trước (mục 23: Accepted KHÔNG cho Create Revision).
  Future<int> createRevision(int sourceProposalId, {required int projectId}) async {
    final source = await _repository.getProposal(sourceProposalId);
    if (source == null) {
      throw StateError('Proposal $sourceProposalId không tồn tại.');
    }
    if (!_workflow.canCreateRevision(source)) {
      throw StateError('Trạng thái hiện tại không cho phép Create Revision.');
    }
    final newId = await _repository.createRevision(sourceProposalId);
    await loadForProject(projectId);
    return newId;
  }

  Future<void> markSent(int id, {required int projectId}) async {
    final proposal = await _repository.getProposal(id);
    if (proposal == null) return;
    if (!_workflow.canMarkSent(proposal)) {
      throw StateError('Chỉ Proposal Final mới chuyển Sent được.');
    }
    await _repository.markSent(id);
    await loadForProject(projectId);
  }

  /// Trả `false` nếu bị chặn do đã có revision khác cùng chain Accepted
  /// (mục 20) — UI hiện thông báo tương ứng, KHÔNG throw vì đây là 1 nhánh
  /// nghiệp vụ bình thường chứ không phải lỗi lập trình.
  Future<bool> markAccepted(
    int id, {
    required int projectId,
    String? responseNote,
  }) async {
    final proposal = await _repository.getProposal(id);
    if (proposal == null) return false;
    if (!_workflow.canAccept(proposal)) {
      throw StateError('Chỉ Proposal Sent mới Accept được.');
    }
    final result = await _repository.markAccepted(id, responseNote: responseNote);
    await loadForProject(projectId);
    return result;
  }

  Future<void> markRejected(
    int id, {
    required int projectId,
    String? responseNote,
  }) async {
    final proposal = await _repository.getProposal(id);
    if (proposal == null) return;
    if (!_workflow.canReject(proposal)) {
      throw StateError('Chỉ Proposal Sent mới Reject được.');
    }
    await _repository.markRejected(id, responseNote: responseNote);
    await loadForProject(projectId);
  }

  Future<List<GrindingProposal>> getRevisions(int rootProposalId) =>
      _repository.getRevisions(rootProposalId);

  Future<GrindingProposal?> getLatestRevision(int rootProposalId) =>
      _repository.getLatestRevision(rootProposalId);

  Future<List<List<GrindingProposal>>> getProposalChainsByProject(
    int projectId,
  ) => _repository.getProposalChainsByProject(projectId);

  /// So sánh field-level [oldProposalId] vs [newProposalId] (vd R0 vs R1) —
  /// derive lúc gọi, không lưu DB (mục 18-19).
  Future<List<GrindingProposalChange>> diffProposals({
    required int oldProposalId,
    required int newProposalId,
  }) async {
    final oldProposal = await _repository.getProposal(oldProposalId);
    final newProposal = await _repository.getProposal(newProposalId);
    if (oldProposal == null || newProposal == null) return const [];
    final oldItems = await _repository.getLineItems(oldProposalId);
    final newItems = await _repository.getLineItems(newProposalId);
    return _diff.diff(
      oldProposal: oldProposal,
      oldLineItems: oldItems,
      newProposal: newProposal,
      newLineItems: newItems,
    );
  }
}
