import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_dashboard_summary.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_selection_project.dart';
import '../providers/grinding_dashboard_provider.dart';

/// Dashboard tổng quan Project → Machine Selection → Proposal → Revision →
/// Commercial Status (Phase 10). CHỈ đọc dữ liệu qua [GrindingDashboardProvider]
/// (mục 2) — không query SQLite trực tiếp trong widget. Mọi tính toán KPI
/// nằm ở `GrindingCommercialDashboardService`, widget chỉ hiển thị.
class GrindingProjectDashboardScreen extends StatefulWidget {
  const GrindingProjectDashboardScreen({super.key});

  @override
  State<GrindingProjectDashboardScreen> createState() =>
      _GrindingProjectDashboardScreenState();
}

class _GrindingProjectDashboardScreenState
    extends State<GrindingProjectDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GrindingDashboardProvider>().load(),
    );
  }

  void _openProjectsFiltered(GrindingProjectStatus? status) {
    context.push('/grinding_machine/projects', extra: status);
  }

  void _openProposalsFiltered(GrindingProposalStatus status) {
    final provider = context.read<GrindingDashboardProvider>();
    final chains = GrindingProposal.groupByChain(provider.proposals);
    final matches = chains
        .map((c) => c.last)
        .where((p) => p.status == status)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final projectNameById = {
      for (final p in provider.projects)
        if (p.id != null) p.id!: p.projectName,
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ProposalListSheet(
        title: '${_proposalStatusLabel(status)} (${matches.length})',
        proposals: matches,
        projectNameById: projectNameById,
        onTap: (p) {
          Navigator.pop(sheetContext);
          context.push('/grinding_machine/projects/${p.projectId}/proposals/${p.id}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<GrindingDashboardProvider>(
            builder: (context, provider, _) => IconButton(
              key: const Key('grinding_dashboard_refresh_button'),
              tooltip: 'Refresh',
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: provider.isLoading ? null : () => provider.refresh(),
            ),
          ),
        ],
      ),
      body: Consumer<GrindingDashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.summary == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load dashboard',
                      key: const Key('grinding_dashboard_error_text'),
                      style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      key: const Key('grinding_dashboard_retry_button'),
                      onPressed: () => provider.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (provider.projects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No project data yet',
                      key: const Key('grinding_dashboard_empty_text'),
                      style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('grinding_dashboard_empty_create_button'),
                      onPressed: () => context.push('/grinding_machine/selector'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Project'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = provider.summary!;
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView(
              key: const Key('grinding_dashboard_list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _TimeRangeChips(
                  value: provider.timeRange,
                  onChanged: provider.setTimeRange,
                ),
                const SizedBox(height: 16),
                _SectionTitle('Project Pipeline'),
                const SizedBox(height: 8),
                _ProjectPipelineRow(
                  summary: summary,
                  onTapAll: () => _openProjectsFiltered(null),
                  onTapStatus: _openProjectsFiltered,
                ),
                const SizedBox(height: 20),
                _SectionTitle('Proposal Pipeline'),
                const SizedBox(height: 4),
                Text(
                  '${summary.proposalChainCount} proposal chains · ${summary.revisionCount} revisions',
                  key: const Key('grinding_dashboard_chain_revision_count'),
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                _ProposalPipelineRow(
                  summary: summary,
                  onTapStatus: _openProposalsFiltered,
                ),
                const SizedBox(height: 20),
                _SectionTitle('Commercial Summary'),
                const SizedBox(height: 8),
                _CommercialSummarySection(summary: summary),
                const SizedBox(height: 20),
                _SectionTitle('Expiring Soon'),
                const SizedBox(height: 8),
                _ExpiringSection(
                  key: const Key('grinding_dashboard_expiring_section'),
                  items: summary.expiringSoon,
                  emptyText: 'No proposals expiring in the next 7 days.',
                  isExpired: false,
                ),
                const SizedBox(height: 20),
                _SectionTitle('Expired'),
                const SizedBox(height: 8),
                _ExpiringSection(
                  key: const Key('grinding_dashboard_expired_section'),
                  items: summary.expired,
                  emptyText: 'No expired proposals.',
                  isExpired: true,
                ),
                const SizedBox(height: 20),
                _SectionTitle('Follow Up'),
                const SizedBox(height: 8),
                _FollowUpSection(summary: summary),
                const SizedBox(height: 20),
                _SectionTitle('Recent Activity'),
                const SizedBox(height: 8),
                _RecentActivitySection(items: summary.recentActivity),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _proposalStatusLabel(GrindingProposalStatus status) => switch (status) {
  GrindingProposalStatus.draft => 'Draft',
  GrindingProposalStatus.final_ => 'Final',
  GrindingProposalStatus.sent => 'Sent',
  GrindingProposalStatus.accepted => 'Accepted',
  GrindingProposalStatus.rejected => 'Rejected',
};

String _projectStatusLabel(GrindingProjectStatus status) => switch (status) {
  GrindingProjectStatus.draft => 'Draft',
  GrindingProjectStatus.evaluating => 'Evaluating',
  GrindingProjectStatus.selected => 'Selected',
  GrindingProjectStatus.completed => 'Completed',
};

String _money(double v) => NumberFormat.decimalPattern('vi_VN').format(v);

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: palette.cyan, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: palette.ink, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _TimeRangeChips extends StatelessWidget {
  const _TimeRangeChips({required this.value, required this.onChanged});
  final GrindingDashboardTimeRange value;
  final ValueChanged<GrindingDashboardTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('grinding_dashboard_time_range_chips'),
      spacing: 8,
      children: [
        for (final range in GrindingDashboardTimeRange.values)
          ChoiceChip(
            key: Key('grinding_dashboard_time_range_${range.name}'),
            label: Text(range.label),
            selected: value == range,
            onSelected: (_) => onChanged(range),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final c = color ?? palette.navy;
    return Material(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: palette.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPipelineRow extends StatelessWidget {
  const _ProjectPipelineRow({
    required this.summary,
    required this.onTapAll,
    required this.onTapStatus,
  });

  final GrindingDashboardSummary summary;
  final VoidCallback onTapAll;
  final ValueChanged<GrindingProjectStatus> onTapStatus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('grinding_dashboard_project_pipeline'),
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(label: 'Total', count: summary.totalProjects, onTap: onTapAll),
        for (final status in GrindingProjectStatus.values)
          _StatChip(
            label: _projectStatusLabel(status),
            count: summary.projectStatusCounts[status] ?? 0,
            onTap: () => onTapStatus(status),
          ),
      ],
    );
  }
}

class _ProposalPipelineRow extends StatelessWidget {
  const _ProposalPipelineRow({required this.summary, required this.onTapStatus});

  final GrindingDashboardSummary summary;
  final ValueChanged<GrindingProposalStatus> onTapStatus;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Wrap(
      key: const Key('grinding_dashboard_proposal_pipeline'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in GrindingProposalStatus.values)
          _StatChip(
            label: _proposalStatusLabel(status),
            count: summary.proposalChainStatusCounts[status] ?? 0,
            color: status == GrindingProposalStatus.accepted
                ? Colors.green.shade700
                : status == GrindingProposalStatus.rejected
                ? palette.muted
                : null,
            onTap: () => onTapStatus(status),
          ),
      ],
    );
  }
}

class _CommercialSummarySection extends StatelessWidget {
  const _CommercialSummarySection({required this.summary});
  final GrindingDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      key: const Key('grinding_dashboard_commercial_summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currencyGroup(context, 'Accepted', summary.acceptedTotalsByCurrency, Colors.green.shade700),
          const SizedBox(height: 10),
          _currencyGroup(context, 'Sent', summary.sentTotalsByCurrency, palette.navy),
          const SizedBox(height: 10),
          _currencyGroup(context, 'Open Pipeline (Draft+Final+Sent)', summary.openPipelineTotalsByCurrency, palette.cyan),
          if (summary.incompleteCommercialChainCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${summary.incompleteCommercialChainCount} proposals without complete commercial value',
              key: const Key('grinding_dashboard_incomplete_commercial_text'),
              style: TextStyle(color: palette.muted, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _currencyGroup(BuildContext context, String label, Map<String, double> totals, Color color) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 4),
        if (totals.isEmpty)
          Text('—', style: TextStyle(color: palette.muted, fontSize: 13))
        else
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final entry in totals.entries)
                Text(
                  '${_money(entry.value)} ${entry.key}',
                  style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 13),
                ),
            ],
          ),
      ],
    );
  }
}

class _ExpiringSection extends StatelessWidget {
  const _ExpiringSection({
    super.key,
    required this.items,
    required this.emptyText,
    required this.isExpired,
  });

  final List<GrindingExpiringProposalItem> items;
  final String emptyText;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    if (items.isEmpty) {
      return Text(emptyText, style: TextStyle(color: palette.muted, fontSize: 12.5));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('grinding_dashboard_expiry_${item.proposalId}'),
                onTap: () => context.push(
                  '/grinding_machine/projects/${item.projectId}/proposals/${item.proposalId}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.proposalNumber ?? '—'} R${item.revision}',
                              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              [item.projectName, item.customerName].whereType<String>().join(' · '),
                              style: TextStyle(color: palette.muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(item.expiresAt),
                        style: TextStyle(
                          color: isExpired ? Theme.of(context).colorScheme.error : palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowUpSection extends StatelessWidget {
  const _FollowUpSection({required this.summary});
  final GrindingDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bucket(context, 'Overdue', summary.overdueFollowUps, Theme.of(context).colorScheme.error),
        const SizedBox(height: 10),
        _bucket(context, 'Due Today', summary.dueTodayFollowUps, palette.navy),
        const SizedBox(height: 10),
        _bucket(context, 'Upcoming', summary.upcomingFollowUps, palette.muted),
      ],
    );
  }

  Widget _bucket(BuildContext context, String title, List<GrindingFollowUpItem> items, Color color) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text('—', style: TextStyle(color: palette.muted, fontSize: 12.5))
        else
          for (final item in items)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('grinding_dashboard_followup_${item.projectId}'),
                onTap: () => context.push('/grinding_machine/projects/${item.projectId}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${item.projectName}${item.customerName == null ? '' : ' — ${item.customerName}'}'
                    ' — ${DateFormat('dd/MM/yyyy').format(item.nextFollowUpAt)}',
                    style: TextStyle(color: palette.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.items});
  final List<GrindingRecentActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    if (items.isEmpty) {
      return Text('No recent activity.', style: TextStyle(color: palette.muted, fontSize: 12.5));
    }
    return Container(
      key: const Key('grinding_dashboard_recent_activity'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(color: palette.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM').format(item.timestamp),
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProposalListSheet extends StatelessWidget {
  const _ProposalListSheet({
    required this.title,
    required this.proposals,
    required this.projectNameById,
    required this.onTap,
  });

  final String title;
  final List<GrindingProposal> proposals;
  final Map<int, String> projectNameById;
  final ValueChanged<GrindingProposal> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            Flexible(
              child: proposals.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Không có proposal nào.', style: TextStyle(color: palette.muted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: proposals.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = proposals[index];
                        return ListTile(
                          key: Key('grinding_dashboard_proposal_sheet_item_${p.id}'),
                          title: Text('${p.proposalNumber ?? '—'} R${p.revision}'),
                          subtitle: Text(projectNameById[p.projectId] ?? 'Project #${p.projectId}'),
                          onTap: () => onTap(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
