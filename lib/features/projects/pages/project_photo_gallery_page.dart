import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/stored_image.dart';
import '../models/project_attachment.dart';
import '../providers/project_provider.dart';

class ProjectPhotoGalleryPage extends StatefulWidget {
  const ProjectPhotoGalleryPage({
    super.key,
    required this.projectId,
    this.embedded = false,
  });
  final String projectId;
  final bool embedded;

  @override
  State<ProjectPhotoGalleryPage> createState() =>
      _ProjectPhotoGalleryPageState();
}

class _ProjectPhotoGalleryPageState extends State<ProjectPhotoGalleryPage> {
  String? _machineId;
  String? _stageId;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProjectProvider>();
      if (provider.currentProject?.id != widget.projectId) {
        provider.loadProjectDetail(widget.projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final photos = provider.attachments.where((item) {
      if (item.fileType != ProjectFileType.photo) return false;
      if (_machineId != null && item.machineId != _machineId) return false;
      if (_stageId != null && item.stageId != _stageId) return false;
      if (_date != null &&
          (item.updatedAt.year != _date!.year ||
              item.updatedAt.month != _date!.month ||
              item.updatedAt.day != _date!.day)) {
        return false;
      }
      return true;
    }).toList();
    final body = Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tất cả'),
                selected:
                    _machineId == null && _stageId == null && _date == null,
                onSelected: (_) => setState(() {
                  _machineId = null;
                  _stageId = null;
                  _date = null;
                }),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                onSelected: (value) => setState(() => _machineId = value),
                itemBuilder: (_) => [
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả máy'),
                  ),
                  ...?provider.currentProject?.machines.map(
                    (item) => PopupMenuItem(
                      value: item.id,
                      child: Text(item.machineName),
                    ),
                  ),
                ],
                child: Chip(
                  avatar: const Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 18,
                  ),
                  label: Text(_machineName(provider)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                onSelected: (value) => setState(() => _stageId = value),
                itemBuilder: (_) => [
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả giai đoạn'),
                  ),
                  ...provider.stages.map(
                    (item) => PopupMenuItem(
                      value: item.id,
                      child: Text(item.stageName),
                    ),
                  ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(_stageName(provider)),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  _date == null
                      ? 'Ngày'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                ),
                onPressed: _pickDate,
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoadingDetail
              ? const Center(child: CircularProgressIndicator())
              : photos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 56,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(height: 10),
                      Text('Chưa có ảnh phù hợp'),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 600
                        ? 3
                        : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .78,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (_, index) => _PhotoTile(
                        photo: photos[index],
                        stageName:
                            provider.stages
                                .where(
                                  (item) => item.id == photos[index].stageId,
                                )
                                .map((item) => item.stageName)
                                .firstOrNull ??
                            'Dự án',
                        machineName:
                            provider.currentProject?.machines
                                .where(
                                  (item) => item.id == photos[index].machineId,
                                )
                                .map((item) => item.machineName)
                                .firstOrNull ??
                            'Dùng chung',
                        onTap: () => _openPhoto(photos[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Ảnh dự án')),
            body: body,
          );
  }

  String _machineName(ProjectProvider provider) =>
      provider.currentProject?.machines
          .where((item) => item.id == _machineId)
          .map((item) => item.machineName)
          .firstOrNull ??
      'Máy';
  String _stageName(ProjectProvider provider) =>
      provider.stages
          .where((item) => item.id == _stageId)
          .map((item) => item.stageName)
          .firstOrNull ??
      'Giai đoạn';

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  void _openPhoto(ProjectAttachment photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(photo.fileName),
            actions: [
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (confirmContext) => AlertDialog(
                      title: const Text('Xóa ảnh?'),
                      content: const Text('Liên kết ảnh sẽ bị xóa khỏi dự án.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmContext, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(confirmContext, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await context.read<ProjectProvider>().deleteAttachment(
                      photo,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: storedImageCanDisplay(photo.displayPath)
                  ? StoredImage(path: photo.displayPath, fit: BoxFit.contain)
                  : const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 70,
                    ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Cập nhật ${_format(photo.updatedAt)} • ${photo.createdBy}\n${photo.description}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _format(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.stageName,
    required this.machineName,
    required this.onTap,
  });
  final ProjectAttachment photo;
  final String stageName;
  final String machineName;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: storedImageCanDisplay(photo.displayPath)
                ? StoredImage(path: photo.displayPath)
                : const ColoredBox(
                    color: Color(0xFFE8EEF1),
                    child: Icon(Icons.broken_image_outlined),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  machineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'Cập nhật ${photo.updatedAt.day}/${photo.updatedAt.month} ${photo.updatedAt.hour.toString().padLeft(2, '0')}:${photo.updatedAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
