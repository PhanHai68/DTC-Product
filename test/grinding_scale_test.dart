import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_commercial_dashboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scale test (Phase 12, mục 44) — 500 project, nhiều proposal/revision,
/// line items — xác nhận Dashboard Service không có hành vi bất thường
/// (crash, kết quả sai, chậm bất thường kiểu O(n²) rõ ràng). KHÔNG
/// benchmark micro-giây, chỉ đặt ngưỡng thời gian rộng rãi để bắt regression
/// hiệu năng thô (VD ai đó vô tình thêm N+1/loop lồng nhau).
void main() {
  test('500 projects + 1500 proposal revisions + line items -> aggregate đúng, không quá chậm', () {
    final now = DateTime(2026, 9, 25);
    final projects = <GrindingSelectionProject>[];
    final proposals = <GrindingProposal>[];
    final lineItemsByProposalId = <int, List<GrindingProposalLineItem>>{};

    var proposalId = 1;
    for (var i = 1; i <= 500; i++) {
      projects.add(
        GrindingSelectionProject(
          id: i,
          projectName: 'Project $i',
          customerName: 'Customer $i',
          status: GrindingProjectStatus.values[i % GrindingProjectStatus.values.length],
          nextFollowUpAt: i % 5 == 0 ? now.add(Duration(days: i % 10 - 5)) : null,
          createdAt: now.subtract(Duration(days: i % 400)),
          updatedAt: now.subtract(Duration(days: i % 30)),
        ),
      );

      // Mỗi project có 1 chain 3 revision (R0 Final, R1 Sent, R2 Accepted)
      // để test "latest revision only" ở quy mô lớn.
      final rootId = proposalId;
      final r0 = proposalId++;
      proposals.add(
        GrindingProposal(
          id: r0,
          projectId: i,
          proposalNumber: 'GM-2026-${i.toString().padLeft(4, '0')}',
          status: GrindingProposalStatus.final_,
          currency: i.isEven ? 'VND' : 'USD',
          machineId: 'M${i % 10}',
          machineUnitPrice: 100000000,
          machineQuantity: 1,
          vatPercent: 10,
          rootProposalId: rootId,
          revision: 0,
          createdAt: now.subtract(Duration(days: i % 400)),
          updatedAt: now.subtract(Duration(days: i % 30)),
          finalizedAt: now.subtract(Duration(days: i % 30)),
        ),
      );
      final r1 = proposalId++;
      proposals.add(
        GrindingProposal(
          id: r1,
          projectId: i,
          proposalNumber: 'GM-2026-${i.toString().padLeft(4, '0')}',
          status: GrindingProposalStatus.sent,
          currency: i.isEven ? 'VND' : 'USD',
          machineId: 'M${i % 10}',
          machineUnitPrice: 110000000,
          machineQuantity: 1,
          vatPercent: 10,
          rootProposalId: rootId,
          revision: 1,
          sentAt: now.subtract(Duration(days: i % 20)),
          createdAt: now.subtract(Duration(days: i % 20)),
          updatedAt: now.subtract(Duration(days: i % 20)),
        ),
      );
      final r2 = proposalId++;
      proposals.add(
        GrindingProposal(
          id: r2,
          projectId: i,
          proposalNumber: 'GM-2026-${i.toString().padLeft(4, '0')}',
          status: GrindingProposalStatus.accepted,
          currency: i.isEven ? 'VND' : 'USD',
          machineId: 'M${i % 10}',
          machineUnitPrice: 120000000,
          machineQuantity: 1,
          vatPercent: 10,
          rootProposalId: rootId,
          revision: 2,
          acceptedAt: now.subtract(Duration(days: i % 10)),
          createdAt: now.subtract(Duration(days: i % 10)),
          updatedAt: now.subtract(Duration(days: i % 10)),
        ),
      );
      lineItemsByProposalId[r2] = [
        GrindingProposalLineItem(
          proposalId: r2,
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ $i',
          quantity: 1,
          unitPrice: 5000000,
        ),
      ];
    }

    expect(proposals, hasLength(1500));

    final stopwatch = Stopwatch()..start();
    final summary = GrindingCommercialDashboardService.build(
      projects: projects,
      proposals: proposals,
      lineItemsByProposalId: lineItemsByProposalId,
      now: now,
    );
    stopwatch.stop();

    // Ngưỡng RỘNG (không phải benchmark chính xác) — chỉ để bắt regression
    // hiệu năng thô (VD N+1/nested loop vô tình thêm vào). Máy CI/dev bình
    // thường xử lý 500 project + 1500 revision trong Dart thuần chỉ vài
    // chục ms; 5 giây là ngưỡng an toàn rất rộng.
    expect(stopwatch.elapsedMilliseconds, lessThan(5000));

    // Latest revision only -> mỗi chain chỉ tính 1 lần (Accepted), không
    // đếm luôn Final/Sent của cùng chain.
    expect(summary.proposalChainCount, 500);
    expect(summary.revisionCount, 1500);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.accepted], 500);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.final_], 0);
    expect(summary.proposalChainStatusCounts[GrindingProposalStatus.sent], 0);

    // Currency tách riêng, không cộng gộp.
    expect(summary.acceptedTotalsByCurrency.containsKey('VND'), isTrue);
    expect(summary.acceptedTotalsByCurrency.containsKey('USD'), isTrue);

    // Follow-up/Expiring vẫn hoạt động ở quy mô lớn, không crash.
    expect(
      summary.overdueFollowUps.length +
          summary.dueTodayFollowUps.length +
          summary.upcomingFollowUps.length,
      greaterThan(0),
    );
  });

  test('groupByChain với 1500 proposal (500 chain x 3 revision) không quá chậm', () {
    final now = DateTime(2026, 9, 25);
    final proposals = <GrindingProposal>[];
    var id = 1;
    for (var chain = 1; chain <= 500; chain++) {
      final rootId = id;
      for (var revision = 0; revision < 3; revision++) {
        proposals.add(
          GrindingProposal(
            id: id++,
            projectId: chain,
            rootProposalId: rootId,
            revision: revision,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    final chains = GrindingProposal.groupByChain(proposals);
    stopwatch.stop();

    expect(chains, hasLength(500));
    expect(chains.every((c) => c.length == 3), isTrue);
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
