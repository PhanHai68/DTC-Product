import 'package:dtc_product/features/grinding_machine/models/grinding_dashboard_summary.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_commercial_dashboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingSelectionProject _project({
  int? id,
  String name = 'P',
  String? customerName,
  GrindingProjectStatus status = GrindingProjectStatus.draft,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? nextFollowUpAt,
  String? followUpNote,
}) {
  final now = DateTime(2026, 9, 24);
  return GrindingSelectionProject(
    id: id,
    projectName: name,
    customerName: customerName,
    status: status,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    nextFollowUpAt: nextFollowUpAt,
    followUpNote: followUpNote,
  );
}

GrindingProposal _proposal({
  required int id,
  int projectId = 1,
  String? proposalNumber = 'GM-2026-0001',
  GrindingProposalStatus status = GrindingProposalStatus.draft,
  String currency = 'VND',
  double? machineUnitPrice,
  double? machineQuantity,
  double? vatPercent,
  int? rootProposalId,
  int revision = 0,
  int? validityDays,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? finalizedAt,
  DateTime? sentAt,
  DateTime? acceptedAt,
  DateTime? rejectedAt,
}) {
  final now = DateTime(2026, 9, 24);
  return GrindingProposal(
    id: id,
    projectId: projectId,
    proposalNumber: proposalNumber,
    status: status,
    currency: currency,
    machineId: machineUnitPrice == null ? null : 'M1',
    machineUnitPrice: machineUnitPrice,
    machineQuantity: machineQuantity,
    vatPercent: vatPercent,
    rootProposalId: rootProposalId ?? id,
    revision: revision,
    validityDays: validityDays,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    finalizedAt: finalizedAt,
    sentAt: sentAt,
    acceptedAt: acceptedAt,
    rejectedAt: rejectedAt,
  );
}

void main() {
  final now = DateTime(2026, 9, 24);

  test('Project count: 2 Draft, 1 Evaluating, 1 Completed -> đúng count', () {
    final projects = [
      _project(id: 1, status: GrindingProjectStatus.draft),
      _project(id: 2, status: GrindingProjectStatus.draft),
      _project(id: 3, status: GrindingProjectStatus.evaluating),
      _project(id: 4, status: GrindingProjectStatus.completed),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: projects,
      proposals: const [],
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.totalProjects, 4);
    expect(summary.projectStatusCounts[GrindingProjectStatus.draft], 2);
    expect(summary.projectStatusCounts[GrindingProjectStatus.evaluating], 1);
    expect(summary.projectStatusCounts[GrindingProjectStatus.selected], 0);
    expect(summary.projectStatusCounts[GrindingProjectStatus.completed], 1);
  });

  test('Latest Revision: chain R0 Final, R1 Sent, R2 Accepted -> chỉ đếm Accepted=1', () {
    final proposals = [
      _proposal(id: 10, rootProposalId: 10, revision: 0, status: GrindingProposalStatus.final_),
      _proposal(id: 11, rootProposalId: 10, revision: 1, status: GrindingProposalStatus.sent),
      _proposal(
        id: 12,
        rootProposalId: 10,
        revision: 2,
        status: GrindingProposalStatus.accepted,
        acceptedAt: now,
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.proposalChainCount, 1);
    expect(summary.revisionCount, 3);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.accepted], 1);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.final_], 0);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.sent], 0);
  });

  test('Commercial Duplicate: R0=100, R1=150, R2=200 Accepted -> total = 200, KHÔNG phải 450', () {
    final proposals = [
      _proposal(
        id: 10,
        rootProposalId: 10,
        revision: 0,
        status: GrindingProposalStatus.final_,
        machineUnitPrice: 100,
        machineQuantity: 1,
        vatPercent: 0,
      ),
      _proposal(
        id: 11,
        rootProposalId: 10,
        revision: 1,
        status: GrindingProposalStatus.sent,
        machineUnitPrice: 150,
        machineQuantity: 1,
        vatPercent: 0,
        sentAt: now,
      ),
      _proposal(
        id: 12,
        rootProposalId: 10,
        revision: 2,
        status: GrindingProposalStatus.accepted,
        machineUnitPrice: 200,
        machineQuantity: 1,
        vatPercent: 0,
        acceptedAt: now,
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.acceptedTotalsByCurrency['VND'], 200);
  });

  test('Currency Separation: Accepted gồm 1000+2000 USD và 500,000,000 VND -> tách riêng, không cộng gộp', () {
    final proposals = [
      _proposal(
        id: 1,
        rootProposalId: 1,
        currency: 'USD',
        status: GrindingProposalStatus.accepted,
        machineUnitPrice: 1000,
        machineQuantity: 1,
        vatPercent: 0,
        acceptedAt: now,
      ),
      _proposal(
        id: 2,
        rootProposalId: 2,
        currency: 'USD',
        status: GrindingProposalStatus.accepted,
        machineUnitPrice: 2000,
        machineQuantity: 1,
        vatPercent: 0,
        acceptedAt: now,
      ),
      _proposal(
        id: 3,
        rootProposalId: 3,
        currency: 'VND',
        status: GrindingProposalStatus.accepted,
        machineUnitPrice: 500000000,
        machineQuantity: 1,
        vatPercent: 0,
        acceptedAt: now,
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.acceptedTotalsByCurrency['USD'], 3000);
    expect(summary.acceptedTotalsByCurrency['VND'], 500000000);
    expect(summary.acceptedTotalsByCurrency.length, 2);
  });

  test('Null Commercial: Accepted nhưng thiếu machineUnitPrice/VAT -> KHÔNG cộng thành 0, đếm incomplete', () {
    final proposals = [
      _proposal(
        id: 1,
        rootProposalId: 1,
        status: GrindingProposalStatus.accepted,
        acceptedAt: now,
        // machineUnitPrice/vatPercent để trống có chủ đích.
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.acceptedTotalsByCurrency.containsKey('VND'), isFalse);
    expect(summary.incompleteCommercialChainCount, 1);
  });

  test('Expiring Soon: now=2026-09-24, kiểm tra đủ 4 mốc theo đề bài', () {
    GrindingProposal proposalWithValidity(int id, DateTime finalizedAt, int validityDays) =>
        _proposal(
          id: id,
          rootProposalId: id,
          status: GrindingProposalStatus.final_,
          finalizedAt: finalizedAt,
          validityDays: validityDays,
        );

    // expiresAt = finalizedAt + validityDays. Dùng finalizedAt=now để
    // validityDays chính là số ngày còn lại tính từ now.
    final proposals = [
      proposalWithValidity(1, now, 1), // 2026-09-25 -> expiring
      proposalWithValidity(2, now, 6), // 2026-09-30 -> expiring
      proposalWithValidity(3, now, 16), // 2026-10-10 -> không expiring
      proposalWithValidity(4, now.subtract(const Duration(days: 24)), 4), // 2026-09-20 -> expired
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    final expiringIds = summary.expiringSoon.map((e) => e.proposalId).toSet();
    final expiredIds = summary.expired.map((e) => e.proposalId).toSet();
    expect(expiringIds, {1, 2});
    expect(expiredIds, {4});
    expect(expiringIds.contains(3), isFalse);
  });

  test('Follow-Up: yesterday->overdue, today->dueToday, tomorrow->upcoming, null->none', () {
    final projects = [
      _project(
        id: 1,
        name: 'ABC Tea Factory',
        nextFollowUpAt: now.subtract(const Duration(days: 1)),
      ),
      _project(id: 2, name: 'Today Co', nextFollowUpAt: now),
      _project(id: 3, name: 'Tomorrow Co', nextFollowUpAt: now.add(const Duration(days: 1))),
      _project(id: 4, name: 'No followup Co'),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: projects,
      proposals: const [],
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.overdueFollowUps.map((e) => e.projectId), [1]);
    expect(summary.dueTodayFollowUps.map((e) => e.projectId), [2]);
    expect(summary.upcomingFollowUps.map((e) => e.projectId), [3]);
    final allIds = {
      ...summary.overdueFollowUps.map((e) => e.projectId),
      ...summary.dueTodayFollowUps.map((e) => e.projectId),
      ...summary.upcomingFollowUps.map((e) => e.projectId),
    };
    expect(allIds.contains(4), isFalse);
  });

  test('Time Filter: All/This Month/Last 30 Days/This Year deterministic theo now', () {
    final projects = [
      _project(id: 1, createdAt: DateTime(2026, 9, 24)), // hôm nay
      _project(id: 2, createdAt: DateTime(2026, 9, 1)), // trong tháng, >30 ngày trước now? (23 ngày) trong 30 ngày
      _project(id: 3, createdAt: DateTime(2026, 1, 10)), // trong năm, ngoài tháng/30 ngày
      _project(id: 4, createdAt: DateTime(2025, 12, 31)), // năm ngoái
    ];

    GrindingDashboardSummary summaryFor(GrindingDashboardTimeRange range) =>
        GrindingCommercialDashboardService.build(
          projects: projects,
          proposals: const [],
          lineItemsByProposalId: const {},
          now: now,
          timeRange: range,
        );

    expect(summaryFor(GrindingDashboardTimeRange.all).totalProjects, 4);
    expect(summaryFor(GrindingDashboardTimeRange.thisMonth).totalProjects, 2); // id 1,2
    expect(summaryFor(GrindingDashboardTimeRange.last30Days).totalProjects, 2); // id 1,2
    expect(summaryFor(GrindingDashboardTimeRange.thisYear).totalProjects, 3); // id 1,2,3
  });

  test('Open Pipeline: Draft + Final + Sent cộng vào, Accepted/Rejected không', () {
    final proposals = [
      _proposal(
        id: 1,
        rootProposalId: 1,
        status: GrindingProposalStatus.draft,
        machineUnitPrice: 100,
        machineQuantity: 1,
        vatPercent: 0,
      ),
      _proposal(
        id: 2,
        rootProposalId: 2,
        status: GrindingProposalStatus.final_,
        machineUnitPrice: 200,
        machineQuantity: 1,
        vatPercent: 0,
      ),
      _proposal(
        id: 3,
        rootProposalId: 3,
        status: GrindingProposalStatus.sent,
        machineUnitPrice: 300,
        machineQuantity: 1,
        vatPercent: 0,
        sentAt: now,
      ),
      _proposal(
        id: 4,
        rootProposalId: 4,
        status: GrindingProposalStatus.accepted,
        machineUnitPrice: 400,
        machineQuantity: 1,
        vatPercent: 0,
        acceptedAt: now,
      ),
      _proposal(
        id: 5,
        rootProposalId: 5,
        status: GrindingProposalStatus.rejected,
        machineUnitPrice: 500,
        machineQuantity: 1,
        vatPercent: 0,
        rejectedAt: now,
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: proposals,
      lineItemsByProposalId: const {},
      now: now,
    );

    expect(summary.openPipelineTotalsByCurrency['VND'], 600); // 100+200+300
    expect(summary.sentTotalsByCurrency['VND'], 300);
    expect(summary.acceptedTotalsByCurrency['VND'], 400);
  });

  test('Line items được cộng đúng vào grandTotal qua lineItemsByProposalId', () {
    final proposal = _proposal(
      id: 1,
      rootProposalId: 1,
      status: GrindingProposalStatus.accepted,
      machineUnitPrice: 100,
      machineQuantity: 1,
      vatPercent: 0,
      acceptedAt: now,
    );
    const lineItems = [
      GrindingProposalLineItem(
        proposalId: 1,
        kind: GrindingProposalLineItemKind.accessory,
        name: 'Cyclone phụ',
        quantity: 1,
        unitPrice: 50,
      ),
    ];

    final summary = GrindingCommercialDashboardService.build(
      projects: [_project(id: 1)],
      proposals: [proposal],
      lineItemsByProposalId: {1: lineItems},
      now: now,
    );

    expect(summary.acceptedTotalsByCurrency['VND'], 150);
  });
}
