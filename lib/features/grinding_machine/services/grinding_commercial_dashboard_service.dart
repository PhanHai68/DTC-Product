import '../models/grinding_dashboard_summary.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_selection_project.dart';
import 'grinding_proposal_calculator.dart';

/// Tổng hợp toàn bộ KPI cho Dashboard (Phase 10) — THUẦN DART, không đụng
/// database/widget. Input là dữ liệu ĐÃ LOAD sẵn (project/proposal/line
/// items của latest revision mỗi chain) để tránh N+1 (mục 38) — caller
/// ([GrindingDashboardProvider]) chịu trách nhiệm batch-load.
///
/// Rule cốt lõi (đã chốt, xem mục 58 phân tích trước khi code):
/// - Mọi KPI theo proposal đều tính trên LATEST REVISION của từng chain
///   (`GrindingProposal.groupByChain(...).last`), KHÔNG cộng lặp revision cũ.
/// - `GrindingProposalCalculator.grandTotal` không bao giờ `null` (thiết kế
///   Phase 8) — proposal "thiếu dữ liệu thương mại" nhận biết qua
///   `totals.hasIncompleteData == true`; những chain này bị LOẠI khỏi mọi
///   tổng tiền, chỉ đếm vào [GrindingDashboardSummary.incompleteCommercialChainCount].
/// - Currency KHÔNG bao giờ cộng gộp — mọi tổng tiền là `Map<String, double>`.
/// - [timeRange] áp dụng cho Project KPI (theo `createdAt`) và Proposal/
///   Commercial KPI (theo field ngày ứng với status latest revision — mục
///   24): Accepted->`acceptedAt`, Sent->`sentAt`, Draft/Final->`updatedAt`.
///   Rejected dùng `rejectedAt` (ngoài scope các tổng tiền vì Rejected
///   không cộng vào Accepted/Sent/Open Pipeline).
/// - Expiring Soon / Expired / Follow-up KHÔNG áp dụng [timeRange] — luôn
///   phản ánh trạng thái THỰC TẾ tại [now], độc lập bộ lọc KPI phía trên.
abstract final class GrindingCommercialDashboardService {
  static const expiringSoonWindow = Duration(days: 7);
  static const recentActivityLimit = 20;

  static GrindingDashboardSummary build({
    required List<GrindingSelectionProject> projects,
    required List<GrindingProposal> proposals,
    required Map<int, List<GrindingProposalLineItem>> lineItemsByProposalId,
    required DateTime now,
    GrindingDashboardTimeRange timeRange = GrindingDashboardTimeRange.all,
  }) {
    final projectById = <int, GrindingSelectionProject>{
      for (final p in projects)
        if (p.id != null) p.id!: p,
    };

    final projectStatusCounts = <GrindingProjectStatus, int>{
      for (final s in GrindingProjectStatus.values) s: 0,
    };
    var totalProjectsInRange = 0;
    for (final project in projects) {
      if (!_inRange(project.createdAt, timeRange, now)) continue;
      totalProjectsInRange++;
      projectStatusCounts[project.status] = (projectStatusCounts[project.status] ?? 0) + 1;
    }

    final chains = GrindingProposal.groupByChain(proposals);
    final proposalChainStatusCounts = <GrindingProposalStatus, int>{
      for (final s in GrindingProposalStatus.values) s: 0,
    };
    final acceptedTotals = <String, double>{};
    final sentTotals = <String, double>{};
    final openPipelineTotals = <String, double>{};
    var incompleteCount = 0;
    var chainCountInRange = 0;
    var revisionCountInRange = 0;
    final expiringSoon = <GrindingExpiringProposalItem>[];
    final expired = <GrindingExpiringProposalItem>[];

    for (final chain in chains) {
      final latest = chain.last;
      if (latest.id == null) continue;

      if (_inRange(_representativeDate(latest), timeRange, now)) {
        chainCountInRange++;
        revisionCountInRange += chain.length;
        proposalChainStatusCounts[latest.status] =
            (proposalChainStatusCounts[latest.status] ?? 0) + 1;
        _accumulateCommercial(
          latest: latest,
          lineItems: lineItemsByProposalId[latest.id] ?? const [],
          acceptedTotals: acceptedTotals,
          sentTotals: sentTotals,
          openPipelineTotals: openPipelineTotals,
          onIncomplete: () => incompleteCount++,
        );
      }

      final expiryItem = _expiryItemFor(latest, projectById[latest.projectId], now);
      if (expiryItem != null) {
        if (expiryItem.expired) {
          expired.add(expiryItem);
        } else if (_isExpiringSoon(expiryItem.expiresAt, now)) {
          expiringSoon.add(expiryItem);
        }
      }
    }
    expiringSoon.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    expired.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    final followUps = _buildFollowUps(projects, now);
    final recentActivity = _buildRecentActivity(projects, proposals, projectById);

    return GrindingDashboardSummary(
      timeRange: timeRange,
      projectStatusCounts: projectStatusCounts,
      totalProjects: totalProjectsInRange,
      proposalChainStatusCounts: proposalChainStatusCounts,
      proposalChainCount: chainCountInRange,
      revisionCount: revisionCountInRange,
      acceptedTotalsByCurrency: acceptedTotals,
      sentTotalsByCurrency: sentTotals,
      openPipelineTotalsByCurrency: openPipelineTotals,
      incompleteCommercialChainCount: incompleteCount,
      expiringSoon: expiringSoon,
      expired: expired,
      overdueFollowUps: followUps.$1,
      dueTodayFollowUps: followUps.$2,
      upcomingFollowUps: followUps.$3,
      recentActivity: recentActivity,
    );
  }

  static void _accumulateCommercial({
    required GrindingProposal latest,
    required List<GrindingProposalLineItem> lineItems,
    required Map<String, double> acceptedTotals,
    required Map<String, double> sentTotals,
    required Map<String, double> openPipelineTotals,
    required void Function() onIncomplete,
  }) {
    if (latest.status == GrindingProposalStatus.rejected) return;
    final totals = GrindingProposalCalculator.calculate(latest, lineItems);
    if (totals.hasIncompleteData) {
      onIncomplete();
      return;
    }
    final currency = latest.currency;
    switch (latest.status) {
      case GrindingProposalStatus.accepted:
        acceptedTotals[currency] = (acceptedTotals[currency] ?? 0) + totals.grandTotal;
      case GrindingProposalStatus.sent:
        sentTotals[currency] = (sentTotals[currency] ?? 0) + totals.grandTotal;
        openPipelineTotals[currency] = (openPipelineTotals[currency] ?? 0) + totals.grandTotal;
      case GrindingProposalStatus.draft:
      case GrindingProposalStatus.final_:
        openPipelineTotals[currency] = (openPipelineTotals[currency] ?? 0) + totals.grandTotal;
      case GrindingProposalStatus.rejected:
        break;
    }
  }

  static GrindingExpiringProposalItem? _expiryItemFor(
    GrindingProposal latest,
    GrindingSelectionProject? project,
    DateTime now,
  ) {
    if (latest.status != GrindingProposalStatus.final_ &&
        latest.status != GrindingProposalStatus.sent) {
      return null;
    }
    final expiresAt = latest.expiresAt;
    if (expiresAt == null || latest.id == null) return null;
    return GrindingExpiringProposalItem(
      proposalId: latest.id!,
      projectId: latest.projectId,
      rootProposalId: latest.rootProposalId ?? latest.id!,
      proposalNumber: latest.proposalNumber,
      revision: latest.revision,
      projectName: project?.projectName ?? 'Project #${latest.projectId}',
      customerName: project?.customerName,
      status: latest.status,
      expiresAt: expiresAt,
      expired: latest.isExpired(now: now),
    );
  }

  static bool _isExpiringSoon(DateTime expiresAt, DateTime now) {
    final remaining = expiresAt.difference(now);
    return remaining >= Duration.zero && remaining <= expiringSoonWindow;
  }

  static (List<GrindingFollowUpItem>, List<GrindingFollowUpItem>, List<GrindingFollowUpItem>)
  _buildFollowUps(List<GrindingSelectionProject> projects, DateTime now) {
    final overdue = <GrindingFollowUpItem>[];
    final dueToday = <GrindingFollowUpItem>[];
    final upcoming = <GrindingFollowUpItem>[];
    final today = DateTime(now.year, now.month, now.day);

    for (final project in projects) {
      final followUpAt = project.nextFollowUpAt;
      if (followUpAt == null || project.id == null) continue;
      final followUpDate = DateTime(followUpAt.year, followUpAt.month, followUpAt.day);
      final item = GrindingFollowUpItem(
        projectId: project.id!,
        projectName: project.projectName,
        customerName: project.customerName,
        nextFollowUpAt: followUpAt,
        followUpNote: project.followUpNote,
        bucket: followUpDate.isBefore(today)
            ? GrindingFollowUpBucket.overdue
            : followUpDate.isAtSameMomentAs(today)
            ? GrindingFollowUpBucket.dueToday
            : GrindingFollowUpBucket.upcoming,
      );
      switch (item.bucket) {
        case GrindingFollowUpBucket.overdue:
          overdue.add(item);
        case GrindingFollowUpBucket.dueToday:
          dueToday.add(item);
        case GrindingFollowUpBucket.upcoming:
          upcoming.add(item);
      }
    }
    overdue.sort((a, b) => a.nextFollowUpAt.compareTo(b.nextFollowUpAt));
    dueToday.sort((a, b) => a.nextFollowUpAt.compareTo(b.nextFollowUpAt));
    upcoming.sort((a, b) => a.nextFollowUpAt.compareTo(b.nextFollowUpAt));
    return (overdue, dueToday, upcoming);
  }

  static List<GrindingRecentActivityItem> _buildRecentActivity(
    List<GrindingSelectionProject> projects,
    List<GrindingProposal> proposals,
    Map<int, GrindingSelectionProject> projectById,
  ) {
    final items = <GrindingRecentActivityItem>[];
    for (final project in projects) {
      if (project.id == null) continue;
      items.add(
        GrindingRecentActivityItem(
          type: GrindingActivityType.projectCreated,
          timestamp: project.createdAt,
          title: 'Project created: ${project.projectName}',
          subtitle: project.customerName,
          projectId: project.id,
        ),
      );
    }
    for (final proposal in proposals) {
      if (proposal.id == null) continue;
      final project = projectById[proposal.projectId];
      final label = proposal.proposalNumber == null
          ? 'Proposal'
          : '${proposal.proposalNumber} R${proposal.revision}';
      final subtitle = project?.projectName;
      items.add(
        GrindingRecentActivityItem(
          type: GrindingActivityType.proposalCreated,
          timestamp: proposal.createdAt,
          title: 'Proposal created: $label',
          subtitle: subtitle,
          projectId: proposal.projectId,
          proposalId: proposal.id,
        ),
      );
      if (proposal.finalizedAt != null) {
        items.add(
          GrindingRecentActivityItem(
            type: GrindingActivityType.proposalFinalized,
            timestamp: proposal.finalizedAt!,
            title: 'Proposal finalized: $label',
            subtitle: subtitle,
            projectId: proposal.projectId,
            proposalId: proposal.id,
          ),
        );
      }
      if (proposal.sentAt != null) {
        items.add(
          GrindingRecentActivityItem(
            type: GrindingActivityType.proposalSent,
            timestamp: proposal.sentAt!,
            title: 'Proposal sent: $label',
            subtitle: subtitle,
            projectId: proposal.projectId,
            proposalId: proposal.id,
          ),
        );
      }
      if (proposal.acceptedAt != null) {
        items.add(
          GrindingRecentActivityItem(
            type: GrindingActivityType.proposalAccepted,
            timestamp: proposal.acceptedAt!,
            title: 'Proposal accepted: $label',
            subtitle: subtitle,
            projectId: proposal.projectId,
            proposalId: proposal.id,
          ),
        );
      }
      if (proposal.rejectedAt != null) {
        items.add(
          GrindingRecentActivityItem(
            type: GrindingActivityType.proposalRejected,
            timestamp: proposal.rejectedAt!,
            title: 'Proposal rejected: $label',
            subtitle: subtitle,
            projectId: proposal.projectId,
            proposalId: proposal.id,
          ),
        );
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(recentActivityLimit).toList();
  }

  /// Ngày đại diện cho 1 chain (dùng để lọc [timeRange]) — theo status của
  /// latest revision (mục 24): Accepted->acceptedAt, Sent->sentAt,
  /// Rejected->rejectedAt, Draft/Final->updatedAt. Fallback `updatedAt` nếu
  /// field mốc thời gian tương ứng thiếu (chưa từng xảy ra trong luồng bình
  /// thường vì Repository luôn set field đó khi chuyển status — chỉ là an
  /// toàn phòng dữ liệu cũ/migration).
  static DateTime _representativeDate(GrindingProposal latest) => switch (latest.status) {
    GrindingProposalStatus.accepted => latest.acceptedAt ?? latest.updatedAt,
    GrindingProposalStatus.sent => latest.sentAt ?? latest.updatedAt,
    GrindingProposalStatus.rejected => latest.rejectedAt ?? latest.updatedAt,
    GrindingProposalStatus.draft => latest.updatedAt,
    GrindingProposalStatus.final_ => latest.updatedAt,
  };

  static bool _inRange(DateTime date, GrindingDashboardTimeRange range, DateTime now) {
    switch (range) {
      case GrindingDashboardTimeRange.all:
        return true;
      case GrindingDashboardTimeRange.thisMonth:
        return date.year == now.year && date.month == now.month;
      case GrindingDashboardTimeRange.last30Days:
        final start = now.subtract(const Duration(days: 30));
        return !date.isBefore(start) && !date.isAfter(now);
      case GrindingDashboardTimeRange.thisYear:
        return date.year == now.year;
    }
  }
}
