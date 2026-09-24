import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_machine_match.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_selection_criteria.dart';
import '../models/grinding_selection_project.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../providers/grinding_proposal_provider.dart';
import '../providers/grinding_selection_project_provider.dart';
import '../services/grinding_machine_selection_service.dart';
import '../services/grinding_proposal_calculator.dart';
import '../services/grinding_selection_export_service.dart';

/// Chi tiết 1 hồ sơ đã lưu (Phase 7, mục 7). Nếu [primaryMachineId] không
/// còn trong database hiện tại (Excel đã update) -> hiển thị rõ "Machine no
/// longer available in current database", KHÔNG crash, KHÔNG tự chọn máy
/// khác (mục 18).
class GrindingSelectionProjectDetailScreen extends StatefulWidget {
  const GrindingSelectionProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  State<GrindingSelectionProjectDetailScreen> createState() =>
      _GrindingSelectionProjectDetailScreenState();
}

class _GrindingSelectionProjectDetailScreenState
    extends State<GrindingSelectionProjectDetailScreen> {
  GrindingSelectionProject? _project;
  GrindingProjectMachines _machines = const GrindingProjectMachines();
  GrindingMachine? _selectedMachine;
  bool _selectedMachineUnavailable = false;
  GrindingSeries? _selectedSeries;
  List<GrindingMachine> _shortlistMachines = const [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final projectProvider = context.read<GrindingSelectionProjectProvider>();
    final grindingProvider = context.read<GrindingMachineProvider>();
    final proposalProvider = context.read<GrindingProposalProvider>();
    unawaited(proposalProvider.loadForProject(widget.projectId));
    final project = await projectProvider.getProject(widget.projectId);
    if (project == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tìm thấy dự án này.';
        _isLoading = false;
      });
      return;
    }
    final machines = await projectProvider.getProjectMachines(widget.projectId);

    GrindingMachine? selectedMachine;
    GrindingSeries? selectedSeries;
    var unavailable = false;
    if (machines.primaryMachineId != null) {
      selectedMachine = await grindingProvider.getMachine(machines.primaryMachineId!);
      if (selectedMachine == null) {
        unavailable = true;
      } else {
        selectedSeries = await grindingProvider.getSeries(selectedMachine.seriesCode);
      }
    }

    final shortlist = <GrindingMachine>[];
    for (final id in machines.shortlistMachineIds) {
      final m = await grindingProvider.getMachine(id);
      if (m != null) shortlist.add(m);
    }

    if (!mounted) return;
    setState(() {
      _project = project;
      _machines = machines;
      _selectedMachine = selectedMachine;
      _selectedMachineUnavailable = unavailable;
      _selectedSeries = selectedSeries;
      _shortlistMachines = shortlist;
      _isLoading = false;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this project?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<GrindingSelectionProjectProvider>().deleteProject(widget.projectId);
    if (!mounted) return;
    context.pop();
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    final project = _project;
    if (project == null) return;
    setState(() => _isExporting = true);
    try {
      final grindingProvider = context.read<GrindingMachineProvider>();
      // Chạy lại Selection Service bằng criteria đã lưu + dữ liệu máy HIỆN
      // TẠI (mục 9/13) — không dùng dữ liệu cũ/đoán, PDF phản ánh đúng
      // database lúc xuất.
      List<GrindingMachineMatch> recommendations = const [];
      if (project.requiredCapacityKgH != null ||
          project.requiredFinenessValue != null ||
          project.maxMotorKw != null ||
          project.feedSizeMm != null ||
          project.materialId != null ||
          project.application != null) {
        final seriesByCode = {
          for (final s in grindingProvider.series) s.seriesCode: s,
        };
        final seriesTags = await grindingProvider.getAllSelectionTagsGrouped();
        final materialSeriesMap = project.materialId == null
            ? const <dynamic>[]
            : await grindingProvider.getMaterialSeriesMapFor(project.materialId!);
        recommendations = GrindingMachineSelectionService.evaluate(
          criteria: GrindingSelectionCriteria(
            materialId: project.materialId,
            materialName: project.materialName,
            capacityKgH: project.requiredCapacityKgH,
            finenessValue: project.requiredFinenessValue,
            finenessUnit: project.requiredFinenessUnit,
            feedSizeMm: project.feedSizeMm,
            maxMotorKw: project.maxMotorKw,
            application: project.application,
          ),
          machines: grindingProvider.machines,
          seriesByCode: seriesByCode,
          seriesTags: seriesTags,
          materialSeriesMap: materialSeriesMap.cast(),
        );
      }

      final bytes = await GrindingSelectionExportService.buildPdf(
        project: project,
        recommendations: recommendations,
        selectedMachine: _selectedMachine,
        selectedSeries: _selectedSeries,
        comparisonMachines: _shortlistMachines,
      );
      if (!mounted) return;
      final fileName =
          'GrindingSelection-${project.id}-${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
          title: 'Grinding Machine Selection Report',
          text: project.projectName,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xuất PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Mở dialog chọn ngày + note follow-up (mục 16) — cho phép Save hoặc
  /// Clear (chỉ hiện nút Clear khi đang có follow-up). KHÔNG tự đặt ngày
  /// mặc định hôm nay nếu người dùng chưa chọn (mục 15).
  Future<void> _setFollowUp() async {
    final project = _project;
    if (project == null) return;
    final result = await showDialog<_FollowUpDialogResult>(
      context: context,
      builder: (dialogContext) => _FollowUpDialog(initial: project),
    );
    if (result == null || !mounted) return;
    final provider = context.read<GrindingSelectionProjectProvider>();
    if (result.clear) {
      await provider.updateProject(
        project.copyWith(clearNextFollowUpAt: true, clearFollowUpNote: true),
      );
    } else {
      await provider.updateProject(
        project.copyWith(
          nextFollowUpAt: result.date,
          followUpNote: result.note.isEmpty ? null : result.note,
          clearFollowUpNote: result.note.isEmpty,
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final project = _project;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(project?.projectName ?? 'Chi tiết dự án'),
        actions: [
          if (project != null) ...[
            IconButton(
              key: const Key('grinding_project_export_button'),
              tooltip: 'Export PDF',
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _isExporting ? null : _exportPdf,
            ),
            IconButton(
              key: const Key('grinding_project_delete_button'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: palette.muted)),
            )
          : _DetailBody(
              project: project!,
              machines: _machines,
              selectedMachine: _selectedMachine,
              selectedMachineUnavailable: _selectedMachineUnavailable,
              selectedSeries: _selectedSeries,
              shortlistMachines: _shortlistMachines,
              onEdit: () => context.push(
                '/grinding_machine/selector',
                extra: widget.projectId,
              ),
              onCompare: _shortlistMachines.length >= 2
                  ? () => context.push(
                      '/grinding_machine/compare',
                      extra: _shortlistMachines.map((m) => m.machineId).toList(),
                    )
                  : null,
              onSetFollowUp: _setFollowUp,
              projectId: widget.projectId,
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.project,
    required this.machines,
    required this.selectedMachine,
    required this.selectedMachineUnavailable,
    required this.selectedSeries,
    required this.shortlistMachines,
    required this.onEdit,
    required this.onCompare,
    required this.onSetFollowUp,
    required this.projectId,
  });

  final GrindingSelectionProject project;
  final GrindingProjectMachines machines;
  final GrindingMachine? selectedMachine;
  final bool selectedMachineUnavailable;
  final GrindingSeries? selectedSeries;
  final List<GrindingMachine> shortlistMachines;
  final int projectId;
  final VoidCallback onEdit;
  final VoidCallback? onCompare;
  final VoidCallback onSetFollowUp;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Section(
          title: 'Project',
          rows: [
            ('Project name', project.projectName),
            ('Customer', project.customerName),
            ('Contact', [project.contactName, project.contactInfo].whereType<String>().join(' · ')),
            ('Status', project.status.value),
            (
              'Follow-up',
              project.nextFollowUpAt == null
                  ? null
                  : '${DateFormat('dd/MM/yyyy').format(project.nextFollowUpAt!)}'
                        '${project.followUpNote == null ? '' : ' — ${project.followUpNote}'}',
            ),
            ('Created', DateFormat('yyyy-MM-dd HH:mm').format(project.createdAt)),
            ('Updated', DateFormat('yyyy-MM-dd HH:mm').format(project.updatedAt)),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('grinding_project_set_followup_button'),
          onPressed: onSetFollowUp,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(project.nextFollowUpAt == null ? 'Set Follow-up' : 'Update Follow-up'),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Customer Requirement',
          rows: [
            ('Material', project.materialName),
            (
              'Capacity',
              project.requiredCapacityKgH == null
                  ? null
                  : '${_num(project.requiredCapacityKgH!)} kg/h',
            ),
            (
              'Fineness',
              project.requiredFinenessValue == null
                  ? null
                  : '${_num(project.requiredFinenessValue!)} ${project.requiredFinenessUnit ?? ''}',
            ),
            (
              'Feed size',
              project.feedSizeMm == null ? null : '${_num(project.feedSizeMm!)} mm',
            ),
            (
              'Max motor',
              project.maxMotorKw == null ? null : '${_num(project.maxMotorKw!)} kW',
            ),
            ('Application', project.application),
            ('Notes', project.notes),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('grinding_project_selected_machine_section'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Machines',
                style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (selectedMachine != null) ...[
                Text(
                  selectedMachine!.model,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (selectedSeries != null)
                  Text(
                    selectedSeries!.nameVi,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('grinding_project_view_machine_button'),
                        onPressed: () => context.push(
                          '/grinding_machine/detail/${selectedMachine!.machineId}',
                        ),
                        child: const Text('View Machine'),
                      ),
                    ),
                    if (onCompare != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('grinding_project_compare_button'),
                          onPressed: onCompare,
                          child: const Text('Compare'),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (selectedMachineUnavailable) ...[
                Text(
                  'Machine no longer available in current database',
                  key: const Key('grinding_project_machine_unavailable'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ] else ...[
                Text(
                  'No machine selected',
                  key: const Key('grinding_project_no_machine'),
                  style: TextStyle(color: palette.muted),
                ),
              ],
              if (shortlistMachines.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Shortlist (${shortlistMachines.length})',
                  style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: shortlistMachines
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.cyan.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            m.model,
                            style: TextStyle(color: palette.navy, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommercialSummarySection(projectId: projectId),
        const SizedBox(height: 12),
        _ProposalsSection(projectId: projectId),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('grinding_project_edit_button'),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Project'),
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
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
          Text(title, style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(label, style: TextStyle(color: palette.muted, fontSize: 12.5)),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(color: palette.ink, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Tóm tắt thương mại của Project (Phase 10, mục 30) — Proposal chains,
/// Latest proposal (chain cập nhật gần nhất), Accepted proposal nếu có,
/// Total latest proposal value (tách currency, KHÔNG cộng lặp revision cũ —
/// dùng đúng `chain.last` như Dashboard). `hasIncompleteData` bị loại khỏi
/// tổng, giống rule Dashboard (mục 9) để nhất quán 2 nơi.
class _CommercialSummarySection extends StatelessWidget {
  const _CommercialSummarySection({required this.projectId});

  final int projectId;

  Future<Map<String, double>> _computeTotals(
    GrindingProposalProvider provider,
    List<List<GrindingProposal>> chains,
  ) async {
    final totals = <String, double>{};
    for (final chain in chains) {
      final latest = chain.last;
      if (latest.status == GrindingProposalStatus.rejected || latest.id == null) {
        continue;
      }
      final items = await provider.getLineItems(latest.id!);
      final calc = GrindingProposalCalculator.calculate(latest, items);
      if (calc.hasIncompleteData) continue;
      totals[latest.currency] = (totals[latest.currency] ?? 0) + calc.grandTotal;
    }
    return totals;
  }

  static String _statusLabel(GrindingProposalStatus status) => switch (status) {
    GrindingProposalStatus.draft => 'Draft',
    GrindingProposalStatus.final_ => 'Final',
    GrindingProposalStatus.sent => 'Sent',
    GrindingProposalStatus.accepted => 'Accepted',
    GrindingProposalStatus.rejected => 'Rejected',
  };

  static String _money(double v) => NumberFormat.decimalPattern('vi_VN').format(v);

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Consumer<GrindingProposalProvider>(
      builder: (context, provider, _) {
        final chains = GrindingProposal.groupByChain(provider.proposals);
        if (chains.isEmpty) return const SizedBox.shrink();
        final sortedByUpdated = [...chains]
          ..sort((a, b) => b.last.updatedAt.compareTo(a.last.updatedAt));
        final latest = sortedByUpdated.first.last;
        final accepted = chains
            .map((c) => c.last)
            .where((p) => p.status == GrindingProposalStatus.accepted)
            .toList();

        return FutureBuilder<Map<String, double>>(
          future: _computeTotals(provider, chains),
          builder: (context, snapshot) {
            final totals = snapshot.data ?? const <String, double>{};
            return Container(
              key: const Key('grinding_project_commercial_summary'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commercial Summary',
                    style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _row(palette, 'Proposal chains', '${chains.length}'),
                  _row(
                    palette,
                    'Latest proposal',
                    '${latest.proposalNumber ?? '—'} R${latest.revision} · ${_statusLabel(latest.status)}',
                  ),
                  _row(
                    palette,
                    'Accepted',
                    accepted.isEmpty
                        ? 'None'
                        : accepted
                              .map((p) => '${p.proposalNumber ?? '—'} R${p.revision}')
                              .join(', '),
                  ),
                  _row(
                    palette,
                    'Total latest value',
                    totals.isEmpty
                        ? '—'
                        : totals.entries.map((e) => '${_money(e.value)} ${e.key}').join(' · '),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(DtcPaletteData palette, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: palette.muted, fontSize: 12.5))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: palette.ink, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _FollowUpDialogResult {
  const _FollowUpDialogResult._({required this.clear, this.date, this.note = ''});

  factory _FollowUpDialogResult.clear() => const _FollowUpDialogResult._(clear: true);
  factory _FollowUpDialogResult.save(DateTime date, String note) =>
      _FollowUpDialogResult._(clear: false, date: date, note: note);

  final bool clear;
  final DateTime? date;
  final String note;
}

class _FollowUpDialog extends StatefulWidget {
  const _FollowUpDialog({required this.initial});
  final GrindingSelectionProject initial;

  @override
  State<_FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<_FollowUpDialog> {
  DateTime? _date;
  late final _noteController = TextEditingController(text: widget.initial.followUpNote ?? '');

  @override
  void initState() {
    super.initState();
    _date = widget.initial.nextFollowUpAt;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Follow-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const Key('grinding_project_followup_date_button'),
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(_date == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(_date!)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('grinding_project_followup_note_field'),
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initial.nextFollowUpAt != null)
          TextButton(
            key: const Key('grinding_project_followup_clear_button'),
            onPressed: () => Navigator.pop(context, _FollowUpDialogResult.clear()),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('grinding_project_followup_save_button'),
          onPressed: _date == null
              ? null
              : () => Navigator.pop(
                  context,
                  _FollowUpDialogResult.save(_date!, _noteController.text.trim()),
                ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Danh sách Proposal đã lưu cho Project này, NHÓM THEO CHAIN
/// (`rootProposalId`) — mỗi chain hiện "Latest: R`n`" + status của bản mới
/// nhất + toàn bộ lịch sử revision dạng chip tap được (Phase 9, mục 14-15).
/// KHÔNG hiện từng revision như 1 proposal độc lập không liên kết. Dùng
/// [Consumer] để tự cập nhật ngay khi tạo/xóa Proposal/Revision ở
/// GrindingProposalEditorScreen, không cần reload thủ công màn Detail này.
class _ProposalsSection extends StatelessWidget {
  const _ProposalsSection({required this.projectId});

  final int projectId;

  static String _statusLabel(GrindingProposalStatus status) => switch (status) {
    GrindingProposalStatus.draft => 'DRAFT',
    GrindingProposalStatus.final_ => 'FINAL',
    GrindingProposalStatus.sent => 'SENT',
    GrindingProposalStatus.accepted => 'ACCEPTED',
    GrindingProposalStatus.rejected => 'REJECTED',
  };

  static Color _statusColor(DtcPaletteData palette, Color errorColor, GrindingProposalStatus status) =>
      switch (status) {
        GrindingProposalStatus.draft => palette.muted,
        GrindingProposalStatus.final_ => palette.navy,
        GrindingProposalStatus.sent => palette.navy,
        GrindingProposalStatus.accepted => Colors.green.shade700,
        GrindingProposalStatus.rejected => errorColor,
      };

  /// Nhóm [proposals] (đã load qua `provider.proposals`, phẳng) theo
  /// `rootProposalId` — mỗi chain sắp revision TĂNG DẦN; các chain sắp theo
  /// hoạt động gần nhất trước, y hệt `Repository.getProposalChainsByProject`
  /// nhưng làm đồng bộ tại chỗ để khớp ngay với Consumer, không cần gọi lại
  /// DB.
  static List<List<GrindingProposal>> _groupByChain(List<GrindingProposal> proposals) {
    final byRoot = <int, List<GrindingProposal>>{};
    for (final p in proposals) {
      final rootId = p.rootProposalId ?? p.id;
      if (rootId == null) continue;
      byRoot.putIfAbsent(rootId, () => []).add(p);
    }
    final chains = byRoot.values.toList();
    for (final chain in chains) {
      chain.sort((a, b) => a.revision.compareTo(b.revision));
    }
    chains.sort((a, b) => b.last.updatedAt.compareTo(a.last.updatedAt));
    return chains;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      key: const Key('grinding_project_proposals_section'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Consumer<GrindingProposalProvider>(
        builder: (context, provider, _) {
          final chains = _groupByChain(provider.proposals);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Proposals',
                      style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('grinding_project_create_proposal_button'),
                    onPressed: () => context.push(
                      '/grinding_machine/projects/$projectId/proposals/new',
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Proposal'),
                  ),
                ],
              ),
              if (chains.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Chưa có Proposal nào.',
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
                )
              else
                for (final chain in chains)
                  _ProposalChainTile(
                    key: Key('grinding_project_proposal_chain_${chain.first.rootProposalId ?? chain.first.id}'),
                    projectId: projectId,
                    chain: chain,
                    statusLabel: _statusLabel,
                    statusColor: (status) => _statusColor(palette, errorColor, status),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ProposalChainTile extends StatelessWidget {
  const _ProposalChainTile({
    super.key,
    required this.projectId,
    required this.chain,
    required this.statusLabel,
    required this.statusColor,
  });

  final int projectId;
  final List<GrindingProposal> chain;
  final String Function(GrindingProposalStatus) statusLabel;
  final Color Function(GrindingProposalStatus) statusColor;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final latest = chain.last;
    final hasAccepted = chain.any((p) => p.status == GrindingProposalStatus.accepted);
    void openRevision(GrindingProposal p) => context.push(
      '/grinding_machine/projects/$projectId/proposals/${p.id}',
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: hasAccepted
          ? BoxDecoration(
              color: Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('grinding_project_proposal_${latest.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => openRevision(latest),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        latest.proposalNumber ?? '—',
                        style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Text(
                      'Latest: R${latest.revision}',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor(latest.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel(latest.status),
                        style: TextStyle(
                          color: statusColor(latest.status),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (chain.length > 1) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text('History:', style: TextStyle(color: palette.muted, fontSize: 11)),
                      for (final revision in chain)
                        InkWell(
                          key: Key('grinding_project_proposal_history_${revision.id}'),
                          onTap: () => openRevision(revision),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor(revision.status).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'R${revision.revision}',
                              style: TextStyle(
                                color: statusColor(revision.status),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
