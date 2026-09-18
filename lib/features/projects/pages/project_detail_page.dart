import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project.dart';
import '../models/project_activity.dart';
import '../models/project_attachment.dart';
import '../models/project_stage.dart';
import '../providers/project_provider.dart';
import '../services/project_file_storage.dart';
import '../services/project_report_pdf_service.dart';
import '../widgets/project_progress.dart';
import 'project_photo_gallery_page.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          context.read<ProjectProvider>().loadProjectDetail(widget.projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết dự án'),
          actions: [
            if (project != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteProject(project);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Xóa dự án')),
                ],
              ),
          ],
        ),
        body: provider.isLoadingDetail
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null || project == null
            ? _ErrorBody(
                message: provider.error ?? 'Không tìm thấy dự án',
                onRetry: () => provider.loadProjectDetail(widget.projectId),
              )
            : Column(
                children: [
                  _ProjectHeader(project: project),
                  const Material(
                    color: Colors.white,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: 'Tổng quan'),
                        Tab(text: 'Máy'),
                        Tab(text: 'Timeline'),
                        Tab(text: 'Hình ảnh'),
                        Tab(text: 'Tài liệu'),
                        Tab(text: 'Nghiệm thu'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(project: project),
                        _MachinesTab(project: project),
                        _TimelineTab(activities: provider.activities),
                        ProjectPhotoGalleryPage(
                          projectId: project.id,
                          embedded: true,
                        ),
                        _DocumentsTab(project: project),
                        _AcceptanceTab(project: project),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: project == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _exporting
                        ? null
                        : () => _exportReport(provider, project),
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_rounded),
                    label: const Text('Chia sẻ pdf báo cáo'),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dự án?'),
        content: Text(
          'Toàn bộ dữ liệu liên kết của “${project.projectName}” sẽ bị xóa khỏi thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<ProjectProvider>().deleteProject(
        project.id,
      );
      if (ok && mounted) context.pop();
    }
  }

  Future<void> _exportReport(ProjectProvider provider, Project project) async {
    setState(() => _exporting = true);
    try {
      final bytes = await ProjectReportPdfService.build(
        project: project,
        stages: provider.stages,
        submissions: provider.submissions,
        attachments: provider.attachments,
      );
      final fileName =
          '${_safeFilePart(project.trackingTitle)} ${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedPath = await saveProjectReport(
        projectId: project.id,
        bytes: bytes,
        fileName: fileName,
      );
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
          ],
          title: project.trackingTitle,
          text: '${project.trackingTitle}\nĐã lưu: $savedPath',
          sharePositionOrigin: origin,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xuất báo cáo PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _safeFilePart(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          project.trackingTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              project.location,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text(project.status.label),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ProjectProgress(value: project.progress),
      ],
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Info(label: 'Địa điểm', value: project.location),
                _Info(
                  label: 'Kỹ sư phụ trách',
                  value: project.technicalEngineer.isEmpty
                      ? '—'
                      : project.technicalEngineer,
                ),
                if (project.description.isNotEmpty)
                  _Info(label: 'Mô tả', value: project.description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Giai đoạn (${provider.stages.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...provider.stages.map(
          (stage) => Card(
            child: ListTile(
              leading: _StageIcon(status: stage.status),
              title: Text(
                '${stage.stageOrder + 1}. ${stage.stageName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                stage.assignedUser.isEmpty
                    ? _stageSubtitle(stage)
                    : '${_stageSubtitle(stage)} • ${stage.assignedUser}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/projects/${project.id}/stages/${stage.id}'),
            ),
          ),
        ),
      ],
    );
  }

  static String _stageSubtitle(ProjectStage stage) {
    if (stage.startDate == null) return stage.status.label;
    if (stage.completedDate == null) {
      return '${stage.status.label} • Bắt đầu ${_dateTime(stage.startDate!)}';
    }
    final duration = stage.completedDate!.difference(stage.startDate!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${stage.status.label} • ${hours}g ${minutes}p';
  }

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _MachinesTab extends StatelessWidget {
  const _MachinesTab({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: project.machines.isEmpty
            ? const Center(child: Text('Chưa có máy trong dự án.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: project.machines.length,
                itemBuilder: (_, index) {
                  final machine = project.machines[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.precision_manufacturing_outlined,
                      ),
                      title: Text(
                        machine.machineName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${machine.model} • ${machine.serialNumber}\n${machine.status}',
                      ),
                      isThreeLine: true,
                      onTap: () =>
                          context.push('/projects/${project.id}/machines'),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => context.push('/projects/${project.id}/machines'),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Quản lý máy'),
        ),
      ),
    ],
  );
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.activities});
  final List<ProjectActivity> activities;
  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Center(child: Text('Chưa có hoạt động.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: activities.length,
      itemBuilder: (_, index) {
        final item = activities[index];
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        _activityIcon(item.activityType),
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (index != activities.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateTime(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (item.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(item.description),
                            ),
                          if (item.userId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Người thực hiện: ${item.userId}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          if (item.attachmentIds.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                'Ảnh / tệp: ${item.attachmentIds.length}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static IconData _activityIcon(ProjectActivityType type) => switch (type) {
    ProjectActivityType.projectCreated => Icons.create_new_folder_outlined,
    ProjectActivityType.machineAdded => Icons.precision_manufacturing_outlined,
    ProjectActivityType.stageUpdated => Icons.account_tree_outlined,
    ProjectActivityType.checklistUpdated => Icons.check_box_outlined,
    ProjectActivityType.attachmentAdded => Icons.attach_file_rounded,
    ProjectActivityType.acceptanceUpdated => Icons.fact_check_outlined,
    ProjectActivityType.note => Icons.notes_rounded,
  };
  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} – ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final documents = provider.attachments
        .where((item) => item.fileType != ProjectFileType.photo)
        .toList();
    return Column(
      children: [
        Expanded(
          child: documents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có tài liệu. Có thể lưu bản vẽ, manual, checklist, báo cáo test, SAT, nghiệm thu và bảo hành.\n\nĐường dẫn local và Cloud URL được lưu tách biệt để sẵn sàng đồng bộ.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: documents.length,
                  itemBuilder: (_, index) {
                    final item = documents[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          item.fileType == ProjectFileType.pdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.description_outlined,
                        ),
                        title: Text(
                          item.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          item.description.isEmpty
                              ? item.displayPath
                              : item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Xóa tệp đính kèm',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, provider, item),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _addReference(context, provider),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Thêm tài liệu'),
          ),
        ),
      ],
    );
  }

  Future<void> _addReference(
    BuildContext context,
    ProjectProvider provider,
  ) async {
    final name = TextEditingController();
    final path = TextEditingController();
    final description = TextEditingController();
    var type = ProjectFileType.document;
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('Thêm tài liệu'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Tên tệp / tài liệu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProjectFileType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Loại tệp'),
                    items: ProjectFileType.values
                        .where((item) => item != ProjectFileType.photo)
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: path,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn local hoặc Cloud URL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (bản vẽ, manual, SAT...)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (add == true && name.text.trim().isNotEmpty && context.mounted) {
      final now = DateTime.now();
      final rawPath = path.text.trim();
      await provider.saveAttachment(
        ProjectAttachment(
          id: 'attachment_${now.microsecondsSinceEpoch}',
          projectId: project.id,
          fileType: type,
          fileName: name.text.trim(),
          localPath: rawPath.startsWith('http') ? '' : rawPath,
          cloudUrl: rawPath.startsWith('http') ? rawPath : '',
          createdBy: project.technicalEngineer,
          createdAt: now,
          updatedAt: now,
          description: description.text.trim(),
        ),
      );
    }
    name.dispose();
    path.dispose();
    description.dispose();
  }

  Future<void> _delete(
    BuildContext context,
    ProjectProvider provider,
    ProjectAttachment item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: Text(item.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteAttachment(item);
    }
  }
}

class _AcceptanceTab extends StatelessWidget {
  const _AcceptanceTab({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final stage = provider.stages
        .where((item) => item.stageName == 'Nghiệm thu')
        .firstOrNull;
    final latest = stage == null
        ? null
        : provider.submissionsFor(stage.id).firstOrNull;
    final machineType = latest?.data['machineType'] == 'compressor'
        ? 'Máy nén khí'
        : 'Máy tách màu';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  latest == null
                      ? Icons.fact_check_outlined
                      : Icons.verified_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  latest == null
                      ? 'Chưa xác nhận nghiệm thu'
                      : 'Đã xác nhận $machineType',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (latest != null) ...[
                  const SizedBox(height: 14),
                  _Info(
                    label: 'Thời gian',
                    value: _TimelineTab._dateTime(latest.confirmedAt),
                  ),
                  _Info(label: 'Loại máy', value: machineType),
                  _Info(
                    label: 'Người xác nhận',
                    value: latest.confirmedBy.isEmpty
                        ? '—'
                        : latest.confirmedBy,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: stage == null
                      ? null
                      : () => context.push(
                          '/projects/${project.id}/stages/${stage.id}',
                        ),
                  icon: const Icon(Icons.edit_document),
                  label: Text(
                    latest == null ? 'Lập nghiệm thu' : 'Cập nhật nghiệm thu',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.status});
  final ProjectStageStatus status;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ProjectStageStatus.completed => (Icons.check_rounded, Colors.green),
      ProjectStageStatus.inProgress => (
        Icons.play_arrow_rounded,
        Theme.of(context).colorScheme.primary,
      ),
      ProjectStageStatus.blocked => (Icons.priority_high_rounded, Colors.red),
      ProjectStageStatus.notStarted => (Icons.circle_outlined, Colors.blueGrey),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .12),
      child: Icon(icon, color: color),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
