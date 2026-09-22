import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/project_stage.dart';
import '../providers/project_provider.dart';

const _colorOnTime = Color(0xFF1E88E5);
const _colorOverdue = Color(0xFFE53935);
const _colorDone = Color(0xFF43A047);
const _colorWarning = Color(0xFFEF6C00);

/// Số ngày lệch giữa 2 mốc, chỉ tính theo NGÀY (bỏ giờ/phút) để tránh sai số
/// biên khi so sánh "hôm nay" với 1 hạn đặt vào buổi sáng.
int _daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

({String label, Color color}) _stageStatusInfo(ProjectStage stage) {
  if (stage.status == ProjectStageStatus.completed) {
    if (stage.plannedEndDate != null && stage.completedDate != null) {
      final lateDays = _daysBetween(
        stage.plannedEndDate!,
        stage.completedDate!,
      );
      if (lateDays > 0) {
        return (label: 'Hoàn thành trễ $lateDays ngày', color: _colorWarning);
      }
    }
    return (label: 'Hoàn thành đúng hạn', color: _colorDone);
  }
  if (stage.plannedEndDate == null) {
    return (label: stage.status.label, color: Colors.grey);
  }
  final diff = _daysBetween(stage.plannedEndDate!, DateTime.now());
  if (diff > 0) return (label: 'Trễ $diff ngày', color: _colorOverdue);
  if (diff == 0) return (label: 'Hạn hôm nay', color: _colorWarning);
  return (label: 'Còn ${-diff} ngày', color: _colorOnTime);
}

/// Màn hình "Lịch trình dự án" — xem nhanh nhiều dự án cùng lúc theo ngày kế
/// hoạch của từng giai đoạn. Mỗi giai đoạn hiển thị dạng dòng có tên + hạn +
/// trạng thái trễ/còn bao nhiêu ngày — ưu tiên đọc rõ số liệu trên màn hình
/// điện thoại hơn là vẽ thanh Gantt (quá nhỏ để hiện chữ ở bề rộng này).
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
        dot(_colorOnTime, 'Còn hạn'),
        dot(_colorOverdue, 'Trễ hạn'),
        dot(_colorWarning, 'Hạn hôm nay / hoàn thành trễ'),
        dot(_colorDone, 'Hoàn thành đúng hạn'),
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

  @override
  Widget build(BuildContext context) {
    final dated = stages.where((s) => s.plannedEndDate != null).toList();
    final overdueCount = dated.where((s) => s.isOverdue).length;

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
                  if (overdueCount > 0) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: _colorOverdue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$overdueCount trễ hạn',
                      style: const TextStyle(
                        color: _colorOverdue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
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
              const SizedBox(height: 8),
              if (dated.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Chưa đặt ngày kế hoạch cho giai đoạn nào.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...dated.map((stage) => _StageStatusRow(stage: stage)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageStatusRow extends StatelessWidget {
  const _StageStatusRow({required this.stage});

  final ProjectStage stage;

  @override
  Widget build(BuildContext context) {
    final info = _stageStatusInfo(stage);
    final dateFormat = _shortDate(stage.plannedEndDate!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: info.color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.stageName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Hạn: $dateFormat',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            info.label,
            style: TextStyle(color: info.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
