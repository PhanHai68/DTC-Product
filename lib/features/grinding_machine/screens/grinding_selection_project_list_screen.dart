import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_selection_project.dart';
import '../providers/grinding_machine_provider.dart';
import '../providers/grinding_selection_project_provider.dart';

/// Danh sách hồ sơ "chọn máy phù hợp" đã lưu (Phase 7, mục 6). Search chạy
/// trong RAM trên danh sách đã load — cùng nguyên tắc với
/// GrindingMachineListScreen (Phase 6, mục 16).
class GrindingSelectionProjectListScreen extends StatefulWidget {
  const GrindingSelectionProjectListScreen({super.key, this.initialStatusFilter});

  /// Preset filter status khi mở từ Dashboard (Phase 10, mục 21) — `null`
  /// (mặc định) hiện toàn bộ, y hệt hành vi trước Phase 10. Người dùng vẫn
  /// đổi/xóa filter được trong màn hình qua [_StatusFilterChips].
  final GrindingProjectStatus? initialStatusFilter;

  @override
  State<GrindingSelectionProjectListScreen> createState() =>
      _GrindingSelectionProjectListScreenState();
}

class _GrindingSelectionProjectListScreenState
    extends State<GrindingSelectionProjectListScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _isLoading = true;
  Map<int, String?> _primaryMachineIdByProject = const {};
  GrindingProjectStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<GrindingSelectionProjectProvider>();
    await provider.loadAll();
    if (!mounted) return;
    final byProject = <int, String?>{};
    for (final project in provider.projects) {
      final id = project.id;
      if (id == null) continue;
      final machines = await provider.getProjectMachines(id);
      byProject[id] = machines.primaryMachineId;
    }
    if (!mounted) return;
    setState(() {
      _primaryMachineIdByProject = byProject;
      _isLoading = false;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _query = value.trim().toLowerCase()),
    );
  }

  List<GrindingSelectionProject> _filtered(List<GrindingSelectionProject> all) {
    var result = all;
    if (_statusFilter != null) {
      result = result.where((p) => p.status == _statusFilter).toList();
    }
    if (_query.isEmpty) return result;
    return result.where((p) {
      final machineModel = _machineDisplay(p.id);
      final haystack = [
        p.projectName,
        p.customerName ?? '',
        p.materialName ?? '',
        machineModel ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  String? _machineDisplay(int? projectId) {
    if (projectId == null) return null;
    final machineId = _primaryMachineIdByProject[projectId];
    if (machineId == null) return null;
    final provider = context.read<GrindingMachineProvider>();
    final machine = provider.machines
        .where((m) => m.machineId == machineId)
        .toList();
    return machine.isEmpty ? machineId : machine.first.model;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Saved Projects')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('grinding_project_create_fab'),
        onPressed: () => context.push('/grinding_machine/selector'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Project'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<GrindingSelectionProjectProvider>(
              builder: (context, provider, _) {
                if (provider.projects.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No saved projects yet',
                            style: TextStyle(
                              color: palette.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            key: const Key('grinding_project_empty_create_button'),
                            onPressed: () =>
                                context.push('/grinding_machine/selector'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Project'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final filtered = _filtered(provider.projects);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        key: const Key('grinding_project_search_field'),
                        controller: _controller,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          hintText: 'Tìm project, customer, nguyên liệu, model...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Wrap(
                        key: const Key('grinding_project_status_filter_chips'),
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('grinding_project_status_filter_all'),
                            label: const Text('All'),
                            selected: _statusFilter == null,
                            onSelected: (_) => setState(() => _statusFilter = null),
                          ),
                          for (final status in GrindingProjectStatus.values)
                            ChoiceChip(
                              key: Key('grinding_project_status_filter_${status.value}'),
                              label: Text(status.value),
                              selected: _statusFilter == status,
                              onSelected: (_) => setState(() => _statusFilter = status),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy dự án phù hợp.',
                                style: TextStyle(color: palette.muted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final project = filtered[index];
                                return _ProjectCard(
                                  project: project,
                                  machineDisplay: _machineDisplay(project.id),
                                  onTap: () => context.push(
                                    '/grinding_machine/projects/${project.id}',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.machineDisplay,
    required this.onTap,
  });

  final GrindingSelectionProject project;
  final String? machineDisplay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final requirement = <String>[
      if (project.materialName != null) project.materialName!,
      if (project.requiredCapacityKgH != null)
        '${_num(project.requiredCapacityKgH!)} kg/h',
      if (project.requiredFinenessValue != null && project.requiredFinenessUnit != null)
        '${_num(project.requiredFinenessValue!)} ${project.requiredFinenessUnit}',
    ];

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grinding_project_card_${project.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.projectName,
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusChip(status: project.status),
                      ],
                    ),
                    if (project.customerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        project.customerName!,
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                    if (requirement.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: requirement
                            .map(
                              (r) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.cyan.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    color: palette.navy,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      machineDisplay == null
                          ? 'No machine selected'
                          : 'Selected: $machineDisplay',
                      style: TextStyle(
                        color: machineDisplay == null ? palette.muted : palette.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${DateFormat('yyyy-MM-dd HH:mm').format(project.updatedAt)}',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.cyan),
            ],
          ),
        ),
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GrindingProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final color = switch (status) {
      GrindingProjectStatus.draft => palette.muted,
      GrindingProjectStatus.evaluating => palette.cyan,
      GrindingProjectStatus.selected => palette.navy,
      GrindingProjectStatus.completed => Colors.green.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.value,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
