import 'package:flutter/foundation.dart';

import '../models/grinding_dashboard_summary.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_selection_project.dart';
import '../repositories/grinding_proposal_repository.dart';
import '../repositories/grinding_selection_project_repository.dart';
import '../services/grinding_commercial_dashboard_service.dart';

/// Load/refresh dữ liệu cho Project Dashboard (Phase 10) — CHỈ orchestration
/// (gọi Repository, cache raw data, gọi Service tính KPI), KHÔNG chứa
/// business calculation (nằm ở [GrindingCommercialDashboardService], mục 40).
///
/// Đổi [timeRange] chỉ tính lại từ dữ liệu ĐÃ LOAD (không query DB lại) —
/// chỉ [refresh] mới đọc lại từ Repository, tránh query thừa mỗi lần đổi
/// filter (mục 38-39).
class GrindingDashboardProvider extends ChangeNotifier {
  GrindingDashboardProvider({
    GrindingSelectionProjectRepository? projectRepository,
    GrindingProposalRepository? proposalRepository,
  }) : _projectRepository = projectRepository ?? GrindingSelectionProjectRepository(),
       _proposalRepository = proposalRepository ?? GrindingProposalRepository();

  final GrindingSelectionProjectRepository _projectRepository;
  final GrindingProposalRepository _proposalRepository;

  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<GrindingSelectionProject> _projects = const [];
  List<GrindingProposal> _proposals = const [];
  Map<int, List<GrindingProposalLineItem>> _rawLineItems = const {};

  GrindingDashboardTimeRange _timeRange = GrindingDashboardTimeRange.all;
  GrindingDashboardSummary? _summary;

  bool get isLoading => _isLoading;
  String? get error => _error;
  GrindingDashboardSummary? get summary => _summary;
  GrindingDashboardTimeRange get timeRange => _timeRange;
  List<GrindingSelectionProject> get projects => _projects;

  /// TOÀN BỘ proposal đã load (mọi chain, mọi revision) — dùng ở UI khi cần
  /// lọc/hiển thị danh sách chain theo status cụ thể (VD bottom sheet khi
  /// tap KPI), KHÔNG chứa business calculation (đã tính sẵn ở [summary]).
  List<GrindingProposal> get proposals => _proposals;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() => refresh();

  /// Đọc lại TOÀN BỘ project + proposal (mọi chain, mọi revision) trong 2
  /// query batch, rồi batch-load line items CHỈ của latest revision mỗi
  /// chain (tránh N+1, mục 38), sau đó gọi Service tính KPI theo
  /// [_timeRange] hiện tại.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final projects = await _projectRepository.getAllProjects();
      final proposals = await _proposalRepository.getAllProposals();
      final chains = GrindingProposal.groupByChain(proposals);
      final latestIds = [
        for (final chain in chains)
          if (chain.last.id != null) chain.last.id!,
      ];
      final lineItems = await _proposalRepository.getLineItemsForProposals(latestIds);

      _projects = projects;
      _proposals = proposals;
      _rawLineItems = lineItems;
      _recompute();
    } catch (error) {
      _error = 'Không thể tải dashboard: $error';
      _summary = null;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void setTimeRange(GrindingDashboardTimeRange range) {
    if (_timeRange == range) return;
    _timeRange = range;
    _recompute();
    _notify();
  }

  void _recompute() {
    _summary = GrindingCommercialDashboardService.build(
      projects: _projects,
      proposals: _proposals,
      lineItemsByProposalId: _rawLineItems,
      now: DateTime.now(),
      timeRange: _timeRange,
    );
  }
}
