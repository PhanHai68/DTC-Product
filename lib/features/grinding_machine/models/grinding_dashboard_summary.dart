import 'grinding_proposal.dart';
import 'grinding_selection_project.dart';

/// Khoảng thời gian lọc Dashboard (Phase 10, mục 23-24) — áp dụng cho
/// Project KPI (theo `createdAt`) và Proposal/Commercial KPI (theo field
/// ngày tương ứng trạng thái latest revision — xem
/// `GrindingCommercialDashboardService`). KHÔNG áp dụng cho Expiring/
/// Expired/Follow-up (luôn tính theo trạng thái HIỆN TẠI, độc lập filter).
enum GrindingDashboardTimeRange {
  all,
  thisMonth,
  last30Days,
  thisYear;

  String get label => switch (this) {
    GrindingDashboardTimeRange.all => 'All',
    GrindingDashboardTimeRange.thisMonth => 'This Month',
    GrindingDashboardTimeRange.last30Days => 'Last 30 Days',
    GrindingDashboardTimeRange.thisYear => 'This Year',
  };
}

enum GrindingFollowUpBucket { overdue, dueToday, upcoming }

/// 1 project cần follow-up — chỉ tạo khi `nextFollowUpAt != null` (mục 15,
/// KHÔNG biến null thành hôm nay).
class GrindingFollowUpItem {
  const GrindingFollowUpItem({
    required this.projectId,
    required this.projectName,
    this.customerName,
    required this.nextFollowUpAt,
    this.followUpNote,
    required this.bucket,
  });

  final int projectId;
  final String projectName;
  final String? customerName;
  final DateTime nextFollowUpAt;
  final String? followUpNote;
  final GrindingFollowUpBucket bucket;
}

/// 1 proposal (latest revision của chain) đang Final/Sent và có ngày hết
/// hạn xác định — dùng cho cả section "Expiring Soon" và "Expired" (mục
/// 12-13), phân biệt bằng [expired].
class GrindingExpiringProposalItem {
  const GrindingExpiringProposalItem({
    required this.proposalId,
    required this.projectId,
    required this.rootProposalId,
    this.proposalNumber,
    required this.revision,
    required this.projectName,
    this.customerName,
    required this.status,
    required this.expiresAt,
    required this.expired,
  });

  final int proposalId;
  final int projectId;
  final int rootProposalId;
  final String? proposalNumber;
  final int revision;
  final String projectName;
  final String? customerName;
  final GrindingProposalStatus status;
  final DateTime expiresAt;
  final bool expired;
}

/// Loại sự kiện cho "Recent Activity" (mục 19) — derive runtime từ
/// timestamp có sẵn (createdAt/updatedAt/sentAt/acceptedAt/rejectedAt),
/// KHÔNG có bảng audit riêng (mục 20).
enum GrindingActivityType {
  projectCreated,
  proposalCreated,
  proposalFinalized,
  proposalSent,
  proposalAccepted,
  proposalRejected,
}

class GrindingRecentActivityItem {
  const GrindingRecentActivityItem({
    required this.type,
    required this.timestamp,
    required this.title,
    this.subtitle,
    this.projectId,
    this.proposalId,
  });

  final GrindingActivityType type;
  final DateTime timestamp;
  final String title;
  final String? subtitle;
  final int? projectId;
  final int? proposalId;
}

/// Kết quả tổng hợp toàn bộ Dashboard (Phase 10) — output DUY NHẤT của
/// [GrindingCommercialDashboardService], derive hoàn toàn từ dữ liệu nguồn
/// (project/proposal/line items), KHÔNG lưu SQLite (mục 37).
class GrindingDashboardSummary {
  const GrindingDashboardSummary({
    required this.timeRange,
    required this.projectStatusCounts,
    required this.totalProjects,
    required this.proposalChainStatusCounts,
    required this.proposalChainCount,
    required this.revisionCount,
    required this.acceptedTotalsByCurrency,
    required this.sentTotalsByCurrency,
    required this.openPipelineTotalsByCurrency,
    required this.incompleteCommercialChainCount,
    required this.expiringSoon,
    required this.expired,
    required this.overdueFollowUps,
    required this.dueTodayFollowUps,
    required this.upcomingFollowUps,
    required this.recentActivity,
  });

  final GrindingDashboardTimeRange timeRange;

  /// Đếm TOÀN BỘ project theo status (mục 3) — theo `createdAt` trong
  /// [timeRange].
  final Map<GrindingProjectStatus, int> projectStatusCounts;
  final int totalProjects;

  /// Đếm proposal CHAIN theo status của LATEST REVISION (mục 4) — 1 chain
  /// chỉ tính 1 lần, KHÔNG cộng luôn revision cũ.
  final Map<GrindingProposalStatus, int> proposalChainStatusCounts;
  final int proposalChainCount;

  /// Tổng số revision (mọi chain, mọi revision) — phân biệt với
  /// [proposalChainCount] (mục 5).
  final int revisionCount;

  /// `grandTotal` của các chain có latest revision = Accepted, tách theo
  /// currency — KHÔNG cộng revision cũ (mục 6-7), KHÔNG cộng 2 currency
  /// (mục 8), loại các chain `hasIncompleteData` (mục 9, xem
  /// [incompleteCommercialChainCount]).
  final Map<String, double> acceptedTotalsByCurrency;

  /// Tương tự, cho latest revision = Sent.
  final Map<String, double> sentTotalsByCurrency;

  /// Tương tự, cho latest revision ∈ {Draft, Final, Sent} (mục 6, "Open
  /// Pipeline" = chưa Accepted/Rejected).
  final Map<String, double> openPipelineTotalsByCurrency;

  /// Số chain (Draft/Final/Sent/Accepted) có `hasIncompleteData == true` ở
  /// latest revision — KHÔNG được cộng vào tổng tiền nào ở trên (mục 9, 47).
  final int incompleteCommercialChainCount;

  final List<GrindingExpiringProposalItem> expiringSoon;
  final List<GrindingExpiringProposalItem> expired;

  final List<GrindingFollowUpItem> overdueFollowUps;
  final List<GrindingFollowUpItem> dueTodayFollowUps;
  final List<GrindingFollowUpItem> upcomingFollowUps;

  final List<GrindingRecentActivityItem> recentActivity;

  bool get isEmpty => totalProjects == 0;
}
