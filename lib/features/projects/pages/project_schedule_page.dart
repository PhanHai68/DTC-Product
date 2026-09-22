import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/project_stage.dart';
import '../providers/project_provider.dart';

/// Màn hình "Lịch trình dự án" — xem nhanh nhiều dự án cùng lúc theo ngày kế
/// hoạch của từng giai đoạn (plannedStartDate/plannedEndDate). Mỗi dự án là
/// 1 dải thời gian riêng (không dùng chung 1 trục ngày toàn màn hình) để giữ
/// đơn giản — đủ để phát hiện nhanh giai đoạn nào sắp/đã trễ hạn.
class ProjectSchedulePage extends StatefulWidget {
  const ProjectSchedulePage({super.key});

  @override
  State<ProjectSchedulePage> createState() => _ProjectSchedulePageState();
}

class _ProjectSchedulePageState extends State<ProjectSchedulePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProjectProvider>().loadSchedule(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final activeProjects = provider.projects
        .where((item) => item.status != ProjectStatus.completed)
        .toList()
      ..sort((a, b) => a.projectName.compareTo(b.projectName));

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch trình dự án')),
      body: provider.isLoadingSchedule && provider.projects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.loadSchedule,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const _Legend(),
                  const SizedBox(height: 12),
                  if (activeProjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text('Chưa có dự án đang triển khai.'),
                      ),
                    )
                  else
                    ...activeProjects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ProjectTimelineCard(
                          project: project,
                          stages: provider.scheduleStagesFor(project.id),
                          onTap: () => context.push('/projects/${project.id}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        dot(const Color(0xFF1E88E5), 'Đúng tiến độ'),
        dot(const Color(0xFFE53935), 'Trễ hạn'),
        dot(const Color(0xFF43A047), 'Hoàn thành'),
      ],
    );
  }
}

class _ProjectTimelineCard extends StatelessWidget {
  const _ProjectTimelineCard({
    required this.project,
    required this.stages,
    required this.onTap,
  });

  final Project project;
  final List<ProjectStage> stages;
  final VoidCallback onTap;

  static const _dayWidth = 26.0;
  static const _barHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    final dated = stages
        .where((s) => s.plannedStartDate != null || s.plannedEndDate != null)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(
                      project.status.label,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (project.customerName.isNotEmpty)
                Text(
                  project.customerName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              const SizedBox(height: 10),
              if (dated.isEmpty)
                Text(
                  'Chưa đặt ngày kế hoạch cho giai đoạn nào.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                _buildTimeline(context, dated),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<ProjectStage> dated) {
    final starts = dated.map((s) => s.plannedStartDate ?? s.plannedEndDate!);
    final ends = dated.map((s) => s.plannedEndDate ?? s.plannedStartDate!);
    final minDate = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = maxDate.difference(minDate).inDays + 1;
    final totalWidth = totalDays * _dayWidth;
    final today = DateTime.now();
    final todayOffset = today.isBefore(minDate) || today.isAfter(maxDate)
        ? null
        : today.difference(minDate).inDays * _dayWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        height: dated.length * (_barHeight + 4) + 4,
        child: Stack(
          children: [
            if (todayOffset != null)
              Positioned(
                left: todayOffset,
                top: 0,
                bottom: 0,
                child: Container(width: 1.5, color: Colors.black26),
              ),
            for (var i = 0; i < dated.length; i++)
              _buildBar(context, dated[i], minDate, i),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(
    BuildContext context,
    ProjectStage stage,
    DateTime minDate,
    int index,
  ) {
    final start = stage.plannedStartDate ?? stage.plannedEndDate!;
    final end = stage.plannedEndDate ?? stage.plannedStartDate!;
    final left = start.difference(minDate).inDays * _dayWidth;
    final width = ((end.difference(start).inDays + 1) * _dayWidth).clamp(
      _dayWidth,
      double.infinity,
    );
    final color = stage.status == ProjectStageStatus.completed
        ? const Color(0xFF43A047)
        : stage.isOverdue
        ? const Color(0xFFE53935)
        : const Color(0xFF1E88E5);

    return Positioned(
      left: left,
      top: index * (_barHeight + 4),
      width: width,
      height: _barHeight,
      child: Tooltip(
        message: stage.stageName,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            stage.stageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
