import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/maintenance_checklist_task.dart';
import '../models/maintenance_item.dart';
import '../models/maintenance_parameter.dart';
import '../models/maintenance_part.dart';
import '../models/maintenance_photo.dart';
import '../models/maintenance_report.dart';
import '../providers/maintenance_report_provider.dart';
import '../services/maintenance_report_share.dart';
import '../widgets/maintenance_before_after_view.dart';

/// Màn hình làm việc chính của 1 Maintenance Report: Start Maintenance →
/// Maintenance Items (Before/After) → Checklist → Parts → Final Machine
/// Condition → Final Result → Generate/Share PDF. Toàn bộ nằm trên 1 màn
/// cuộn dọc để hạn chế số lần bấm/điều hướng tại hiện trường.
class MaintenanceReportWorkspaceScreen extends StatefulWidget {
  const MaintenanceReportWorkspaceScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<MaintenanceReportWorkspaceScreen> createState() =>
      _MaintenanceReportWorkspaceScreenState();
}

class _MaintenanceReportWorkspaceScreenState
    extends State<MaintenanceReportWorkspaceScreen> {
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context
          .read<MaintenanceReportProvider>()
          .loadReportDetail(widget.reportId),
    );
  }

  Future<void> _startMaintenance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bắt đầu bảo trì?'),
        content: const Text(
          'Hệ thống sẽ tạo Mã phiên bảo trì và bắt đầu tính thời gian '
          'bảo trì. Mọi ảnh Trước/Sau sau đó đều thuộc phiên này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MaintenanceReportProvider>().startMaintenance();
  }

  Future<void> _completeMaintenance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hoàn tất bảo trì?'),
        content: const Text(
          'Sau khi hoàn tất, ảnh gốc đã chụp sẽ không thể thay đổi. '
          'Bạn vẫn có thể sửa nội dung khác của báo cáo sau đó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MaintenanceReportProvider>().completeMaintenance();
  }

  Future<void> _generateAndShare() async {
    final provider = context.read<MaintenanceReportProvider>();
    final report = provider.currentReport;
    if (report == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _generatingPdf = true);
    try {
      final (verifiedCount, total) = await provider.verifyAllPhotos();
      if (total > 0 && verifiedCount < total && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Cảnh báo: $verifiedCount/$total ảnh gốc còn hợp lệ — vẫn tiếp tục tạo PDF.',
            ),
          ),
        );
      }
      final bytes = await provider.generatePdfBytes(report.id);
      if (!mounted) return;
      final fileName = maintenanceReportFileName(report);
      await shareMaintenanceReportPdf(
        bytes: bytes,
        fileName: fileName,
        report: report,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Chưa thể tạo/chia sẻ PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceReportProvider>(
      builder: (context, provider, _) {
        final report = provider.currentReport;
        if (provider.isLoadingDetail && report == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (report == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Báo cáo bảo trì')),
            body: Center(
              child: Text(provider.detailError ?? 'Không tìm thấy báo cáo.'),
            ),
          );
        }

        final locked = report.isCompleted;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              report.customerName.isEmpty
                  ? 'Báo cáo bảo trì'
                  : report.customerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Sửa thông tin',
                onPressed: () =>
                    context.push('/maintenance_report/${report.id}/edit', extra: report),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _HeaderCard(report: report),
              const SizedBox(height: 16),
              if (!report.hasStarted)
                FilledButton.icon(
                  key: const Key('maintenance_start_button'),
                  onPressed: _startMaintenance,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Bắt đầu bảo trì'),
                )
              else ...[
                _SessionCard(report: report),
                const SizedBox(height: 16),
                _ItemsSection(locked: locked),
                const SizedBox(height: 16),
                _ChecklistSection(
                  checklist: provider.checklist,
                  locked: locked,
                ),
                const SizedBox(height: 16),
                _PartsSection(parts: provider.parts, locked: locked),
                const SizedBox(height: 16),
                _ParametersSection(
                  parameters: provider.parameters,
                  locked: locked,
                ),
                const SizedBox(height: 16),
                _FinalResultSection(report: report, locked: locked),
                const SizedBox(height: 20),
                if (!locked)
                  FilledButton.icon(
                    key: const Key('maintenance_complete_button'),
                    onPressed: _completeMaintenance,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Hoàn tất bảo trì'),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('maintenance_generate_pdf_button'),
                  onPressed: _generatingPdf ? null : _generateAndShare,
                  icon: _generatingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Tạo PDF & Chia sẻ'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.report});

  final MaintenanceReport report;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.machineName.isEmpty
                        ? 'Chưa đặt tên máy'
                        : report.machineName,
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (report.isCompleted ? palette.cyan : const Color(0xFFEA580C))
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.status.label,
                    style: TextStyle(
                      color: report.isCompleted
                          ? palette.cyan
                          : const Color(0xFFEA580C),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (report.machineModel.isNotEmpty)
              Text(
                report.machineModel,
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            const SizedBox(height: 8),
            Text(
              [
                if (report.customerName.isNotEmpty) report.customerName,
                if (report.factorySite.isNotEmpty) report.factorySite,
              ].join(' — '),
              style: TextStyle(color: palette.ink, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('dd/MM/yyyy').format(report.maintenanceDate)}'
              '${report.engineerName.isEmpty ? '' : ' · ${report.engineerName}'}',
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.report});

  final MaintenanceReport report;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final timeFormat = DateFormat('HH:mm dd/MM');
    return Card(
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: palette.cyan),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.sessionId ?? '',
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    report.startTime == null
                        ? ''
                        : 'Bắt đầu ${timeFormat.format(report.startTime!)}'
                              '${report.endTime == null ? '' : ' — Hoàn tất ${timeFormat.format(report.endTime!)}'}',
                    style: TextStyle(color: palette.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Maintenance Items — Before / After
// ---------------------------------------------------------------------

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.locked});

  final bool locked;

  Future<void> _addItem(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AddItemDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context.read<MaintenanceReportProvider>().addItem(name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceReportProvider>();
    return _SectionCard(
      title: 'HẠNG MỤC BẢO TRÌ',
      trailing: IconButton(
        key: const Key('maintenance_add_item_button'),
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'Thêm hạng mục bảo trì',
      ),
      children: [
        if (provider.items.isEmpty)
          Text(
            'Chưa có hạng mục nào. Bấm "+" để thêm (VD: Lọc gió, Lọc dầu...).',
            style: TextStyle(color: DtcPalette.of(context).muted, fontSize: 13),
          ),
        for (final item in provider.items)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ItemCard(
              key: ValueKey('item_${item.id}'),
              item: item,
              photos: provider.photosForItem(item.id),
              locked: locked,
              isCapturingPhoto: provider.isCapturingPhoto,
            ),
          ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm hạng mục bảo trì'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tên hạng mục',
              hintText: 'VD: Lọc gió',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestedMaintenanceItemNames
                .map(
                  (name) => ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(context, name),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.photos,
    required this.locked,
    required this.isCapturingPhoto,
  });

  final MaintenanceItem item;
  final List<MaintenancePhoto> photos;
  final bool locked;
  final bool isCapturingPhoto;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _findingController;
  late final TextEditingController _actionController;
  late final TextEditingController _resultController;
  late final FocusNode _findingFocus;
  late final FocusNode _actionFocus;
  late final FocusNode _resultFocus;

  @override
  void initState() {
    super.initState();
    _findingController = TextEditingController(text: widget.item.beforeFinding);
    _actionController = TextEditingController(text: widget.item.actionTaken);
    _resultController = TextEditingController(text: widget.item.afterResult);
    _findingFocus = FocusNode()..addListener(() => _onFocusChange(_findingFocus));
    _actionFocus = FocusNode()..addListener(() => _onFocusChange(_actionFocus));
    _resultFocus = FocusNode()..addListener(() => _onFocusChange(_resultFocus));
  }

  @override
  void dispose() {
    _findingController.dispose();
    _actionController.dispose();
    _resultController.dispose();
    _findingFocus.dispose();
    _actionFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _onFocusChange(FocusNode node) {
    if (node.hasFocus) return;
    context.read<MaintenanceReportProvider>().updateItem(
      widget.item.copyWith(
        beforeFinding: _findingController.text,
        actionTaken: _actionController.text,
        afterResult: _resultController.text,
      ),
    );
  }

  Future<void> _capture(MaintenancePhotoKind kind) async {
    final provider = context.read<MaintenanceReportProvider>();
    final ok = await provider.captureVerifiedPhoto(
      kind: kind,
      itemId: widget.item.id,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã huỷ chụp ảnh.')),
      );
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hạng mục này?'),
        content: Text('"${widget.item.name}" và toàn bộ ảnh liên quan sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MaintenanceReportProvider>().deleteItem(widget.item.id);
  }

  Future<void> _deletePhoto(MaintenancePhoto photo) async {
    await context.read<MaintenanceReportProvider>().deletePhoto(photo);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final before = widget.photos
        .where((p) => p.kind == MaintenancePhotoKind.before)
        .toList();
    final after = widget.photos
        .where((p) => p.kind == MaintenancePhotoKind.after)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.name,
                  style: TextStyle(
                    color: palette.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              DropdownButton<MaintenanceItemStatus>(
                value: widget.item.status,
                underline: const SizedBox.shrink(),
                style: TextStyle(color: palette.ink, fontSize: 12.5),
                items: MaintenanceItemStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: widget.locked
                    ? null
                    : (status) {
                        if (status == null) return;
                        context.read<MaintenanceReportProvider>().updateItem(
                          widget.item.copyWith(status: status),
                        );
                      },
              ),
              if (!widget.locked)
                IconButton(
                  onPressed: _deleteItem,
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          MaintenanceBeforeAfterView(
            beforePhotos: before,
            afterPhotos: after,
            onDeletePhoto: widget.locked ? null : _deletePhoto,
            onAddBefore: widget.locked || widget.isCapturingPhoto
                ? null
                : () => _capture(MaintenancePhotoKind.before),
            onAddAfter: widget.locked || widget.isCapturingPhoto
                ? null
                : () => _capture(MaintenancePhotoKind.after),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _findingController,
            focusNode: _findingFocus,
            readOnly: widget.locked,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi nhận'),
          ),
          TextField(
            controller: _actionController,
            focusNode: _actionFocus,
            readOnly: widget.locked,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Đã xử lý'),
          ),
          TextField(
            controller: _resultController,
            focusNode: _resultFocus,
            readOnly: widget.locked,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Kết quả'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Maintenance Performed — Checklist
// ---------------------------------------------------------------------

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.checklist, required this.locked});

  final List<MaintenanceChecklistTask> checklist;
  final bool locked;

  Future<void> _addTask(BuildContext context) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm công việc'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (label == null || label.trim().isEmpty || !context.mounted) return;
    await context.read<MaintenanceReportProvider>().addCustomTask(label);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CÔNG VIỆC ĐÃ THỰC HIỆN',
      trailing: IconButton(
        onPressed: locked ? null : () => _addTask(context),
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'Thêm công việc',
      ),
      children: [
        for (final task in checklist)
          CheckboxListTile(
            key: ValueKey('task_${task.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: task.isChecked,
            title: Text(task.label),
            onChanged: locked
                ? null
                : (checked) => context
                      .read<MaintenanceReportProvider>()
                      .toggleChecklistTask(task.id, checked ?? false),
            secondary: task.isCustom && !locked
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => context
                        .read<MaintenanceReportProvider>()
                        .deleteChecklistTask(task.id),
                  )
                : null,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Parts Used
// ---------------------------------------------------------------------

class _PartsSection extends StatelessWidget {
  const _PartsSection({required this.parts, required this.locked});

  final List<MaintenancePart> parts;
  final bool locked;

  Future<void> _addPart(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => const _AddPartDialog(),
    );
    if (result == null || !context.mounted) return;
    await context.read<MaintenanceReportProvider>().addPart(
      partName: result['partName'] ?? '',
      partNumber: result['partNumber'] ?? '',
      quantity: double.tryParse(result['quantity'] ?? '1') ?? 1,
      unit: result['unit'] ?? 'pcs',
      note: result['note'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return _SectionCard(
      title: 'VẬT TƯ ĐÃ SỬ DỤNG',
      trailing: IconButton(
        onPressed: locked ? null : () => _addPart(context),
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'Thêm vật tư',
      ),
      children: [
        if (parts.isEmpty)
          Text('Chưa có phụ tùng nào.', style: TextStyle(color: palette.muted)),
        for (final part in parts)
          ListTile(
            key: ValueKey('part_${part.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(part.partName),
            subtitle: Text(
              [
                if (part.partNumber.isNotEmpty) part.partNumber,
                '${part.quantity == part.quantity.roundToDouble() ? part.quantity.toInt() : part.quantity} ${part.unit}',
                if (part.note.isNotEmpty) part.note,
              ].join(' · '),
            ),
            trailing: locked
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => context
                        .read<MaintenanceReportProvider>()
                        .deletePart(part.id),
                  ),
          ),
      ],
    );
  }
}

class _AddPartDialog extends StatefulWidget {
  const _AddPartDialog();

  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'pcs');
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm vật tư'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên vật tư'),
            ),
            TextField(
              controller: _numberController,
              decoration: const InputDecoration(labelText: 'Mã vật tư'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số lượng'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Đơn vị'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'partName': _nameController.text,
              'partNumber': _numberController.text,
              'quantity': _quantityController.text,
              'unit': _unitController.text,
              'note': _noteController.text,
            });
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Final Machine Condition — Parameters
// ---------------------------------------------------------------------

class _ParametersSection extends StatelessWidget {
  const _ParametersSection({required this.parameters, required this.locked});

  final List<MaintenanceParameter> parameters;
  final bool locked;

  Future<void> _addParameter(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => const _AddParameterDialog(),
    );
    if (result == null || !context.mounted) return;
    await context.read<MaintenanceReportProvider>().addParameter(
      label: result['label'] ?? '',
      value: result['value'] ?? '',
      unit: result['unit'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return _SectionCard(
      title: 'TÌNH TRẠNG MÁY SAU BẢO TRÌ',
      trailing: IconButton(
        onPressed: locked ? null : () => _addParameter(context),
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'Thêm thông số',
      ),
      children: [
        if (parameters.isEmpty)
          Text('Chưa có thông số nào.', style: TextStyle(color: palette.muted)),
        for (final parameter in parameters)
          ListTile(
            key: ValueKey('param_${parameter.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(parameter.label),
            trailing: locked
                ? Text('${parameter.value} ${parameter.unit}'.trim())
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${parameter.value} ${parameter.unit}'.trim()),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => context
                            .read<MaintenanceReportProvider>()
                            .deleteParameter(parameter.id),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _AddParameterDialog extends StatefulWidget {
  const _AddParameterDialog();

  @override
  State<_AddParameterDialog> createState() => _AddParameterDialogState();
}

class _AddParameterDialogState extends State<_AddParameterDialog> {
  final _labelController = TextEditingController();
  final _valueController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm thông số'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _labelController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Thông số'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valueController,
                  decoration: const InputDecoration(labelText: 'Giá trị'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestedMaintenanceParameterLabels
                .map(
                  (label) => ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _labelController.text = label,
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_labelController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'label': _labelController.text,
              'value': _valueController.text,
              'unit': _unitController.text,
            });
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Final Result
// ---------------------------------------------------------------------

class _FinalResultSection extends StatefulWidget {
  const _FinalResultSection({required this.report, required this.locked});

  final MaintenanceReport report;
  final bool locked;

  @override
  State<_FinalResultSection> createState() => _FinalResultSectionState();
}

class _FinalResultSectionState extends State<_FinalResultSection> {
  late final TextEditingController _commentController;
  late final TextEditingController _recommendationController;
  late final TextEditingController _nextHoursController;
  late final FocusNode _commentFocus;
  late final FocusNode _recommendationFocus;
  late final FocusNode _nextHoursFocus;
  DateTime? _nextMaintenanceDate;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.report.finalComment);
    _recommendationController =
        TextEditingController(text: widget.report.recommendation);
    _nextHoursController =
        TextEditingController(text: widget.report.nextMaintenanceRunningHours);
    _nextMaintenanceDate = widget.report.nextMaintenanceDate;
    _commentFocus = FocusNode()..addListener(_save);
    _recommendationFocus = FocusNode()..addListener(_save);
    _nextHoursFocus = FocusNode()..addListener(_save);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _recommendationController.dispose();
    _nextHoursController.dispose();
    _commentFocus.dispose();
    _recommendationFocus.dispose();
    _nextHoursFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (_commentFocus.hasFocus ||
        _recommendationFocus.hasFocus ||
        _nextHoursFocus.hasFocus) {
      return;
    }
    context.read<MaintenanceReportProvider>().updateReport(
      widget.report.copyWith(
        finalComment: _commentController.text,
        recommendation: _recommendationController.text,
        nextMaintenanceRunningHours: _nextHoursController.text,
        nextMaintenanceDate: _nextMaintenanceDate,
        clearNextMaintenanceDate: _nextMaintenanceDate == null,
      ),
    );
  }

  Future<void> _pickNextDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _nextMaintenanceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    setState(() => _nextMaintenanceDate = value);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return _SectionCard(
      title: 'KẾT QUẢ CUỐI CÙNG',
      children: [
        DropdownButtonFormField<MaintenanceOverallResult>(
          initialValue: widget.report.overallResult,
          decoration: const InputDecoration(labelText: 'Kết quả tổng thể'),
          items: MaintenanceOverallResult.values
              .map(
                (result) =>
                    DropdownMenuItem(value: result, child: Text(result.label)),
              )
              .toList(),
          onChanged: widget.locked
              ? null
              : (result) => context.read<MaintenanceReportProvider>().updateReport(
                  widget.report.copyWith(overallResult: result),
                ),
        ),
        TextField(
          controller: _commentController,
          focusNode: _commentFocus,
          readOnly: widget.locked,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Nhận xét'),
        ),
        TextField(
          controller: _recommendationController,
          focusNode: _recommendationFocus,
          readOnly: widget.locked,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Đề xuất'),
        ),
        const SizedBox(height: 8),
        Text(
          'Bảo trì tiếp theo',
          style: TextStyle(color: palette.muted, fontSize: 12.5),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nextHoursController,
                focusNode: _nextHoursFocus,
                readOnly: widget.locked,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giờ vận hành'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  _nextMaintenanceDate == null
                      ? 'Chọn ngày'
                      : DateFormat('dd/MM/yyyy').format(_nextMaintenanceDate!),
                ),
                trailing: widget.locked
                    ? null
                    : const Icon(Icons.event_outlined, size: 20),
                onTap: widget.locked ? null : _pickNextDate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
