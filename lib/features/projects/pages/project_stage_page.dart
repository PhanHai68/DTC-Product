import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../widgets/stored_image.dart';
import '../models/project.dart';
import '../models/project_attachment.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';
import '../providers/project_provider.dart';
import '../services/project_photo_service.dart';

class ProjectStagePage extends StatefulWidget {
  const ProjectStagePage({
    super.key,
    required this.projectId,
    required this.stageId,
  });

  final String projectId;
  final String stageId;

  @override
  State<ProjectStagePage> createState() => _ProjectStagePageState();
}

class _ProjectStagePageState extends State<ProjectStagePage> {
  final _photoService = ProjectPhotoService();
  final _result = TextEditingController();
  final _productivity = TextEditingController();
  final _acceptanceNote = TextEditingController();
  DateTime _workDate = DateTime.now();
  String _machineType = 'colorSorter';
  String? _machineId;
  late String _draftGroup;

  @override
  void initState() {
    super.initState();
    _resetDraftGroup();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ProjectProvider>();
      if (provider.currentProject?.id != widget.projectId) {
        await provider.loadProjectDetail(widget.projectId);
      }
      if (mounted) {
        final machines = provider.currentProject?.machines ?? const [];
        if (machines.length == 1) {
          setState(() => _machineId = machines.first.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _result.dispose();
    _productivity.dispose();
    _acceptanceNote.dispose();
    super.dispose();
  }

  void _resetDraftGroup() {
    _draftGroup = 'daily_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final stage = provider.stages
        .where((item) => item.id == widget.stageId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(stage?.stageName ?? 'Giai đoạn')),
      body: stage == null
          ? provider.isLoadingDetail
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('Không tìm thấy giai đoạn'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _StageTimeCard(
                  stage: stage,
                  onPickStart: () => _pickStageStart(provider, stage),
                ),
                const SizedBox(height: 12),
                _buildDailyEditor(provider, stage),
                const SizedBox(height: 12),
                _HistorySection(
                  submissions: provider
                      .submissionsFor(stage.id)
                      .where((item) => !item.isFinalConfirmation)
                      .toList(),
                  attachments: provider.attachments,
                  onEditPhoto: (photo) => _editPhoto(stage, photo),
                ),
              ],
            ),
      bottomNavigationBar: stage == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed:
                      provider.isSaving ||
                          stage.status == ProjectStageStatus.completed
                      ? null
                      : () => _complete(provider, stage),
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(
                    stage.status == ProjectStageStatus.completed
                        ? 'Đã hoàn thành'
                        : 'Xác nhận hoàn thành',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDailyEditor(ProjectProvider provider, ProjectStage stage) {
    final draftPhotos = provider.attachments
        .where(
          (item) =>
              item.stageId == stage.id && item.category.startsWith(_draftGroup),
        )
        .toList();
    final isAcceptance = stage.stageName == 'Nghiệm thu';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cập nhật công việc theo ngày',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Ngày thực hiện'),
              subtitle: Text(_formatDate(_workDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickWorkDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _result,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kết quả công việc',
                hintText: 'Mô tả cụ thể kết quả đạt được trong ngày',
                alignLabelWithHint: true,
              ),
            ),
            if (isAcceptance) ...[
              const SizedBox(height: 16),
              _buildAcceptanceOptions(provider, stage, draftPhotos),
            ] else ...[
              const SizedBox(height: 16),
              _DraftPhotoSection(
                title: 'Ảnh hiện trường',
                subtitle: 'Có thể thêm một hoặc nhiều ảnh trong ngày.',
                photos: draftPhotos,
                onAdd: () => _pickAndSave(stage, 'evidence'),
                onEdit: (photo) => _editPhoto(stage, photo),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: provider.isSaving
                  ? null
                  : () => _saveDailyUpdate(provider, stage),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu cập nhật ngày'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptanceOptions(
    ProjectProvider provider,
    ProjectStage stage,
    List<ProjectAttachment> draftPhotos,
  ) {
    final machines = provider.currentProject?.machines ?? const [];
    List<ProjectAttachment> category(String value) => draftPhotos
        .where((item) => item.category == '$_draftGroup|$value')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Loại máy nghiệm thu',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'colorSorter',
              icon: Icon(Icons.grain_outlined),
              label: Text('Máy tách màu'),
            ),
            ButtonSegment(
              value: 'compressor',
              icon: Icon(Icons.air_outlined),
              label: Text('Máy nén khí'),
            ),
          ],
          selected: {_machineType},
          onSelectionChanged: (value) =>
              setState(() => _machineType = value.first),
        ),
        if (machines.length > 1) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: machines.any((item) => item.id == _machineId)
                ? _machineId
                : null,
            decoration: const InputDecoration(labelText: 'Model máy'),
            items: machines
                .map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.model),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _machineId = value),
          ),
        ],
        const SizedBox(height: 16),
        if (_machineType == 'colorSorter') ...[
          TextField(
            controller: _productivity,
            decoration: const InputDecoration(
              labelText: 'Thông số năng suất',
              hintText: 'Ví dụ: 8 tấn/giờ',
              prefixIcon: Icon(Icons.speed_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _DraftPhotoSection(
            order: 1,
            title: 'Nguyên liệu',
            photos: category('rawMaterial'),
            onAdd: () => _pickAndSave(stage, 'rawMaterial'),
            onEdit: (photo) => _editPhoto(stage, photo),
          ),
          const SizedBox(height: 12),
          _DraftPhotoSection(
            order: 2,
            title: 'Thành phẩm',
            photos: category('finishedProduct'),
            onAdd: () => _pickAndSave(stage, 'finishedProduct'),
            onEdit: (photo) => _editPhoto(stage, photo),
          ),
          const SizedBox(height: 12),
          _DraftPhotoSection(
            order: 3,
            title: 'Phế phẩm',
            photos: category('rejectProduct'),
            onAdd: () => _pickAndSave(stage, 'rejectProduct'),
            onEdit: (photo) => _editPhoto(stage, photo),
          ),
        ] else
          _DraftPhotoSection(
            title: 'Kết quả vận hành bằng hình ảnh',
            subtitle: 'Chụp rõ kết quả hoặc màn hình thông số vận hành.',
            photos: category('compressorResult'),
            onAdd: () => _pickAndSave(stage, 'compressorResult'),
            onEdit: (photo) => _editPhoto(stage, photo),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _acceptanceNote,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Ghi chú nghiệm thu',
            hintText: 'Thông tin bổ sung của lần chạy nghiệm thu trong ngày',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Future<void> _pickStageStart(
    ProjectProvider provider,
    ProjectStage stage,
  ) async {
    final initial = stage.startDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await provider.setStageStart(stage, value);
  }

  Future<void> _pickWorkDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _workDate = value);
  }

  Future<void> _saveDailyUpdate(
    ProjectProvider provider,
    ProjectStage stage,
  ) async {
    if (stage.startDate == null) {
      _message('Vui lòng nhập thời gian bắt đầu giai đoạn trước.');
      return;
    }
    if (_result.text.trim().isEmpty) {
      _message('Vui lòng nhập kết quả công việc trong ngày.');
      return;
    }
    final photos = provider.attachments
        .where(
          (item) =>
              item.stageId == stage.id && item.category.startsWith(_draftGroup),
        )
        .toList();
    if (photos.isEmpty) {
      _message('Vui lòng thêm ít nhất một hình ảnh.');
      return;
    }
    if (stage.stageName == 'Nghiệm thu' && _machineType == 'colorSorter') {
      if (_productivity.text.trim().isEmpty) {
        _message('Vui lòng nhập thông số năng suất.');
        return;
      }
      for (final category in const [
        'rawMaterial',
        'finishedProduct',
        'rejectProduct',
      ]) {
        if (!photos.any((item) => item.category.endsWith('|$category'))) {
          _message('Cần đủ ảnh Nguyên liệu, Thành phẩm và Phế phẩm.');
          return;
        }
      }
    } else if (stage.stageName == 'Nghiệm thu' &&
        !photos.any((item) => item.category.endsWith('|compressorResult'))) {
      _message('Vui lòng thêm ảnh kết quả vận hành máy nén khí.');
      return;
    }
    final savedDateLabel = _formatDate(_workDate);
    final type = _submissionType(stage);
    final ok = await provider.saveDailyUpdate(
      stage: stage,
      type: type,
      workDate: _workDate,
      result: _result.text,
      machineId: _machineId,
      confirmedBy: provider.currentProject?.technicalEngineer ?? '',
      data: {
        'machineType': _machineType,
        'productivity': _productivity.text.trim(),
        'acceptanceNote': _acceptanceNote.text.trim(),
        'photoIds': photos.map((item) => item.id).toList(),
        'photoOrder': const ['rawMaterial', 'finishedProduct', 'rejectProduct'],
      },
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _result.clear();
        _productivity.clear();
        _acceptanceNote.clear();
        _workDate = DateTime.now();
        _resetDraftGroup();
      });
      _message('Đã lưu kết quả và hình ảnh của ngày $savedDateLabel.');
    } else {
      _message('Không thể lưu cập nhật ngày.');
    }
  }

  Future<void> _complete(ProjectProvider provider, ProjectStage stage) async {
    if (stage.startDate == null) {
      _message('Vui lòng nhập thời gian bắt đầu giai đoạn trước.');
      return;
    }
    final dailyUpdates = provider
        .submissionsFor(stage.id)
        .where((item) => !item.isFinalConfirmation)
        .toList();
    if (dailyUpdates.isEmpty) {
      _message('Giai đoạn cần ít nhất một cập nhật công việc theo ngày.');
      return;
    }
    final engineer = TextEditingController(
      text: provider.currentProject?.technicalEngineer ?? stage.assignedUser,
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận hoàn thành?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ứng dụng sẽ ghi chính xác thời gian hiện tại làm thời điểm hoàn thành.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: engineer,
              decoration: const InputDecoration(labelText: 'Kỹ sư phụ trách'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      engineer.dispose();
      return;
    }
    final ok = await provider.completeStage(
      stage: stage,
      type: _submissionType(stage),
      machineId: _machineId,
      confirmedBy: engineer.text,
    );
    engineer.dispose();
    if (mounted) {
      _message(
        ok
            ? 'Đã hoàn thành và ghi thời gian thực.'
            : 'Không thể hoàn thành giai đoạn.',
      );
    }
  }

  ProjectSubmissionType _submissionType(ProjectStage stage) =>
      switch (stage.stageName) {
        'Giao máy' => ProjectSubmissionType.delivery,
        'Khui thùng' => ProjectSubmissionType.unpacking,
        'Nghiệm thu' when _machineType == 'compressor' =>
          ProjectSubmissionType.acceptanceCompressor,
        'Nghiệm thu' => ProjectSubmissionType.acceptanceColorSorter,
        _ => ProjectSubmissionType.installation,
      };

  Future<void> _pickAndSave(
    ProjectStage stage,
    String category, {
    ProjectAttachment? replacing,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Thư viện ảnh'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final List<ProjectPickedPhoto> pickedPhotos;
      if (replacing == null) {
        pickedPhotos = await _photoService.pickMany(
          projectId: widget.projectId,
          source: source,
        );
      } else {
        final picked = await _photoService.pick(
          projectId: widget.projectId,
          source: source,
        );
        pickedPhotos = picked == null ? [] : [picked];
      }
      if (pickedPhotos.isEmpty || !mounted) return;
      final now = DateTime.now();
      final projectProvider = context.read<ProjectProvider>();
      final createdBy = projectProvider.currentProject?.technicalEngineer ?? '';
      for (var index = 0; index < pickedPhotos.length; index++) {
        final picked = pickedPhotos[index];
        final attachment = replacing == null
            ? ProjectAttachment(
                id: 'attachment_${now.microsecondsSinceEpoch}_$index',
                projectId: widget.projectId,
                machineId: _machineId,
                stageId: stage.id,
                category: '$_draftGroup|$category',
                fileType: ProjectFileType.photo,
                fileName: picked.fileName,
                localPath: picked.path,
                createdBy: createdBy,
                createdAt: now,
                updatedAt: now,
              )
            : replacing.copyWith(
                fileName: picked.fileName,
                localPath: picked.path,
                syncStatus: SyncStatus.pending,
                updatedAt: now,
              );
        await projectProvider.saveAttachment(attachment);
      }
    } catch (error) {
      if (mounted) _message('Không thể lưu ảnh: $error');
    }
  }

  Future<void> _editPhoto(ProjectStage stage, ProjectAttachment photo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.find_replace_outlined),
              title: const Text('Thay bằng ảnh khác'),
              onTap: () => Navigator.pop(sheetContext, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa ảnh'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'replace') {
      await _pickAndSave(
        stage,
        _categorySuffix(photo.category),
        replacing: photo,
      );
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xóa ảnh?'),
          content: const Text('Ảnh sẽ bị gỡ khỏi dữ liệu giai đoạn.'),
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
        await context.read<ProjectProvider>().deleteAttachment(photo);
      }
    }
  }

  String _categorySuffix(String value) =>
      value.contains('|') ? value.split('|').last : value;

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _StageTimeCard extends StatelessWidget {
  const _StageTimeCard({required this.stage, required this.onPickStart});
  final ProjectStage stage;
  final VoidCallback onPickStart;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thời gian thực hiện',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(stage.status.label)),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Bắt đầu'),
            subtitle: Text(
              stage.startDate == null
                  ? 'Chưa nhập'
                  : _formatDateTime(stage.startDate!),
            ),
            trailing: TextButton(
              onPressed: onPickStart,
              child: Text(stage.startDate == null ? 'Nhập' : 'Sửa'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined),
            title: const Text('Hoàn thành'),
            subtitle: Text(
              stage.completedDate == null
                  ? 'Chưa hoàn thành'
                  : _formatDateTime(stage.completedDate!),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DraftPhotoSection extends StatelessWidget {
  const _DraftPhotoSection({
    required this.title,
    this.subtitle = '',
    this.order,
    required this.photos,
    required this.onAdd,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final int? order;
  final List<ProjectAttachment> photos;
  final VoidCallback onAdd;
  final ValueChanged<ProjectAttachment> onEdit;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (order != null) ...[
                CircleAvatar(radius: 13, child: Text('$order')),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: 'Thêm ảnh',
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => _PhotoPreview(
                  photo: photos[index],
                  onTap: () => onEdit(photos[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.submissions,
    required this.attachments,
    required this.onEditPhoto,
  });

  final List<ProjectStageSubmission> submissions;
  final List<ProjectAttachment> attachments;
  final ValueChanged<ProjectAttachment> onEditPhoto;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Chưa có kết quả công việc theo ngày.'),
        ),
      );
    }
    final byId = {for (final item in attachments) item.id: item};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Lịch sử cập nhật',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...submissions.map((submission) {
          final ids =
              (submission.data['photoIds'] as List<dynamic>? ?? const []).map(
                (item) => '$item',
              );
          final photos = ids
              .map((id) => byId[id])
              .whereType<ProjectAttachment>()
              .toList();
          final productivity = '${submission.data['productivity'] ?? ''}'
              .trim();
          final note = '${submission.data['acceptanceNote'] ?? ''}'.trim();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _formatDate(submission.workDate),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(submission.result),
                  if (productivity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Năng suất: $productivity'),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Ghi chú: $note'),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => _PhotoPreview(
                          photo: photos[index],
                          onTap: () => onEditPhoto(photos[index]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.onTap});
  final ProjectAttachment photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: storedImageCanDisplay(photo.displayPath)
              ? StoredImage(path: photo.displayPath, fit: BoxFit.cover)
              : const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
