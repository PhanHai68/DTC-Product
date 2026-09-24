import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_selection_project.dart';
import '../models/grinding_series.dart';
import '../models/grinding_technical_snapshot.dart';
import '../providers/grinding_machine_provider.dart';
import '../providers/grinding_proposal_provider.dart';
import '../providers/grinding_selection_project_provider.dart';
import '../services/grinding_proposal_calculator.dart';
import '../services/grinding_proposal_pdf_service.dart';
import '../services/grinding_proposal_validation_service.dart';
import '../utils/grinding_format.dart';
import '../utils/grinding_number_parser.dart';

/// Tạo/sửa/Finalize/quản lý workflow thương mại 1 Proposal. [proposalId]
/// `null` -> tạo mới (lấy máy chính của Project làm mặc định); có giá trị ->
/// mở hồ sơ đã lưu (đúng revision đó, không tự chuyển sang revision khác).
///
/// CHỈ Draft mới sửa được field (mục 23, Phase 9) — Final/Sent/Accepted/
/// Rejected hiển thị chỉ đọc; sửa tiếp phải "Create Revision" tạo bản Draft
/// mới cùng chain, KHÔNG có nghiệp vụ "un-finalize" bản đang xem.
class GrindingProposalEditorScreen extends StatefulWidget {
  const GrindingProposalEditorScreen({
    super.key,
    required this.projectId,
    this.proposalId,
  });

  final int projectId;
  final int? proposalId;

  @override
  State<GrindingProposalEditorScreen> createState() =>
      _GrindingProposalEditorScreenState();
}

class _GrindingProposalEditorScreenState
    extends State<GrindingProposalEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;

  GrindingSelectionProject? _project;
  int? _proposalDbId;
  String? _proposalNumber;
  GrindingProposalStatus _status = GrindingProposalStatus.draft;
  DateTime? _createdAt;
  DateTime? _finalizedAt;
  GrindingTechnicalSnapshot? _snapshot;

  int? _rootProposalId;
  int _revision = 0;
  DateTime? _sentAt;
  DateTime? _acceptedAt;
  DateTime? _rejectedAt;
  String? _responseNote;
  List<GrindingProposal> _revisions = const [];

  String _currency = 'VND';
  String? _machineId;
  GrindingMachine? _currentMachine;
  GrindingSeries? _currentSeries;
  bool _machineUnavailable = false;

  final _machineUnitPriceController = TextEditingController();
  final _machineQuantityController = TextEditingController();
  final _discountController = TextEditingController();
  final _vatController = TextEditingController();
  final _notesController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _validityDaysController = TextEditingController();

  final List<GrindingProposalLineItem> _accessories = [];
  final List<GrindingProposalLineItem> _additionalCosts = [];

  bool get _isEditable => _status == GrindingProposalStatus.draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _machineUnitPriceController.dispose();
    _machineQuantityController.dispose();
    _discountController.dispose();
    _vatController.dispose();
    _notesController.dispose();
    _deliveryTimeController.dispose();
    _warrantyController.dispose();
    _paymentTermsController.dispose();
    _validityDaysController.dispose();
    super.dispose();
  }

  double? _parse(String text) => GrindingNumberParser.parseDouble(text);
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _load() async {
    final projectProvider = context.read<GrindingSelectionProjectProvider>();
    final grindingProvider = context.read<GrindingMachineProvider>();
    final proposalProvider = context.read<GrindingProposalProvider>();
    final project = await projectProvider.getProject(widget.projectId);

    if (widget.proposalId == null) {
      // Tạo mới -> lấy máy chính của Project (nếu có) làm mặc định.
      final machines = await projectProvider.getProjectMachines(widget.projectId);
      _machineId = machines.primaryMachineId;
    } else {
      final proposal = await proposalProvider.getProposal(widget.proposalId!);
      final items = await proposalProvider.getLineItems(widget.proposalId!);
      if (proposal != null) {
        _proposalDbId = proposal.id;
        _proposalNumber = proposal.proposalNumber;
        _status = proposal.status;
        _createdAt = proposal.createdAt;
        _finalizedAt = proposal.finalizedAt;
        _snapshot = proposal.technicalSnapshot;
        _rootProposalId = proposal.rootProposalId ?? proposal.id;
        _revision = proposal.revision;
        _sentAt = proposal.sentAt;
        _acceptedAt = proposal.acceptedAt;
        _rejectedAt = proposal.rejectedAt;
        _responseNote = proposal.responseNote;
        _currency = proposal.currency;
        _machineId = proposal.machineId;
        if (proposal.machineUnitPrice != null) {
          _machineUnitPriceController.text = _fmt(proposal.machineUnitPrice!);
        }
        if (proposal.machineQuantity != null) {
          _machineQuantityController.text = _fmt(proposal.machineQuantity!);
        }
        if (proposal.discount != null) {
          _discountController.text = _fmt(proposal.discount!);
        }
        if (proposal.vatPercent != null) {
          _vatController.text = _fmt(proposal.vatPercent!);
        }
        _notesController.text = proposal.notes ?? '';
        _deliveryTimeController.text = proposal.deliveryTime ?? '';
        _warrantyController.text = proposal.warranty ?? '';
        _paymentTermsController.text = proposal.paymentTerms ?? '';
        _validityDaysController.text = proposal.validityDays?.toString() ?? '';
        _accessories.addAll(
          items.where((i) => i.kind == GrindingProposalLineItemKind.accessory),
        );
        _additionalCosts.addAll(
          items.where((i) => i.kind == GrindingProposalLineItemKind.additionalCost),
        );
        if (_rootProposalId != null) {
          _revisions = await proposalProvider.getRevisions(_rootProposalId!);
        }
      }
    }

    if (_machineId != null) {
      final machine = await grindingProvider.getMachine(_machineId!);
      if (machine == null) {
        _machineUnavailable = true;
      } else {
        _currentMachine = machine;
        _currentSeries = await grindingProvider.getSeries(machine.seriesCode);
      }
    }

    if (!mounted) return;
    setState(() {
      _project = project;
      _isLoading = false;
    });
  }

  int? _parseInt(String text) => GrindingNumberParser.parseInt(text);

  GrindingProposal _buildProposal() {
    final now = DateTime.now();
    return GrindingProposal(
      id: _proposalDbId,
      projectId: widget.projectId,
      proposalNumber: _proposalNumber,
      status: _status,
      currency: _currency,
      machineId: _machineId,
      machineUnitPrice: _parse(_machineUnitPriceController.text),
      machineQuantity: _parse(_machineQuantityController.text),
      discount: _parse(_discountController.text),
      vatPercent: _parse(_vatController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      technicalSnapshot: _snapshot,
      rootProposalId: _rootProposalId,
      revision: _revision,
      validityDays: _parseInt(_validityDaysController.text),
      deliveryTime: _deliveryTimeController.text.trim().isEmpty
          ? null
          : _deliveryTimeController.text.trim(),
      warranty: _warrantyController.text.trim().isEmpty
          ? null
          : _warrantyController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim().isEmpty
          ? null
          : _paymentTermsController.text.trim(),
      sentAt: _sentAt,
      acceptedAt: _acceptedAt,
      rejectedAt: _rejectedAt,
      responseNote: _responseNote,
      createdAt: _createdAt ?? now,
      updatedAt: now,
      finalizedAt: _finalizedAt,
    );
  }

  List<GrindingProposalLineItem> get _allLineItems => [..._accessories, ..._additionalCosts];

  /// Chặn Save/Finalize từ tầng UI khi dữ liệu thương mại không hợp lệ
  /// (mục 19-21, Phase 11) — KHÔNG để input sai đi tới Repository. Trả
  /// `true` nếu hợp lệ (không hiện gì); `false` nếu có lỗi (đã hiện
  /// SnackBar liệt kê lỗi đầu tiên).
  bool _validateBeforeSave() {
    final proposal = _buildProposal();
    final errors = GrindingProposalValidationService.validate(proposal, _allLineItems);
    if (errors.isEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errors.first)),
    );
    return false;
  }

  Future<void> _saveDraft() async {
    // Guard ĐỒNG BỘ, kiểm tra field trực tiếp — KHÔNG chỉ dựa vào
    // `onPressed: _isSaving ? null : ...` để disable nút, vì `setState`
    // không rebuild kịp thời (rebuild ở frame kế tiếp) nếu 2 tap tới rất
    // gần nhau (double-tap thật) -> nút vẫn còn bind callback cũ khi tap
    // thứ 2 tới, gây tạo trùng proposal (mục 27, bug phát hiện qua test).
    if (_isSaving) return;
    if (!_validateBeforeSave()) return;
    setState(() => _isSaving = true);
    final provider = context.read<GrindingProposalProvider>();
    final proposal = _buildProposal();
    try {
      if (_proposalDbId == null) {
        final id = await provider.createProposal(proposal, _allLineItems);
        final saved = await provider.getProposal(id);
        if (!mounted) return;
        setState(() {
          _proposalDbId = id;
          _proposalNumber = saved?.proposalNumber;
          _createdAt = saved?.createdAt;
          _isSaving = false;
        });
      } else {
        await provider.updateProposal(proposal, lineItems: _allLineItems);
        if (!mounted) return;
        setState(() => _isSaving = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu Proposal (Draft).')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu: $error')),
      );
    }
  }

  Future<void> _finalize() async {
    if (_isSaving) return;
    if (!_validateBeforeSave()) return;
    if (_proposalDbId == null) {
      await _saveDraft();
      if (_proposalDbId == null || !mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalize this proposal?'),
        content: const Text(
          'Thông số kỹ thuật của máy sẽ được đóng băng (Technical Snapshot). '
          'Sau khi Finalize, Proposal sẽ ở chế độ chỉ đọc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_currentMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có máy hợp lệ để chụp Technical Snapshot.')),
      );
      return;
    }
    final proposalProvider = context.read<GrindingProposalProvider>();
    setState(() => _isSaving = true);
    final snapshot = await _captureSnapshotFromCurrentMachine();

    // Lưu draft mới nhất trước rồi mới Finalize để không mất chỉnh sửa dang dở.
    await proposalProvider.updateProposal(_buildProposal(), lineItems: _allLineItems);
    await proposalProvider.finalizeProposal(
      _proposalDbId!,
      projectId: widget.projectId,
      snapshot: snapshot,
    );
    final reloaded = await proposalProvider.getProposal(_proposalDbId!);
    if (!mounted || reloaded == null) return;
    setState(() {
      _status = reloaded.status;
      _snapshot = reloaded.technicalSnapshot;
      _finalizedAt = reloaded.finalizedAt;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã Finalize — Technical Snapshot đã được lưu.')),
    );
  }

  Future<GrindingTechnicalSnapshot> _captureSnapshotFromCurrentMachine() async {
    final grindingProvider = context.read<GrindingMachineProvider>();
    final extraSpecs = await grindingProvider.getExtraSpecs(_currentMachine!.machineId);
    return GrindingTechnicalSnapshot(
      machineId: _currentMachine!.machineId,
      model: _currentMachine!.model,
      seriesDisplayCode: _currentSeries?.displayCode,
      seriesNameVi: _currentSeries?.nameVi,
      capacityDisplay: GrindingFormat.capacityRange(_currentMachine!),
      finenessDisplay: GrindingFormat.finenessRange(_currentMachine!),
      motorDisplay: GrindingFormat.motorRange(_currentMachine!),
      dimensionsDisplay: _currentMachine!.dimensionsDisplay,
      weightDisplay: _currentMachine!.weightKg == null
          ? null
          : '${_fmt(_currentMachine!.weightKg!)} kg',
      extraSpecs: extraSpecs
          .where((s) => s.displayValue.isNotEmpty)
          .map((s) => GrindingSnapshotExtraSpec(label: s.specKey, value: s.displayValue))
          .toList(),
      capturedAt: DateTime.now(),
    );
  }

  /// Chỉ dùng cho revision Draft (revision > 0) khi máy hiện tại còn tồn
  /// tại — chụp lại snapshot MỚI từ catalog hiện tại, thay snapshot cũ copy
  /// từ revision trước. KHÔNG tự động chạy — luôn qua confirm dialog (mục
  /// 24), snapshot chỉ thật sự lưu DB khi Save Draft/Finalize revision này.
  Future<void> _refreshTechnicalData() async {
    if (_isSaving || _currentMachine == null) return;
    final confirmed = await _confirmDialog(
      title: 'Refresh Technical Data?',
      message:
          'Thay thông số kỹ thuật đang dùng (copy từ revision trước) bằng '
          'thông số MỚI NHẤT từ catalog máy hiện tại. Chỉ áp dụng cho bản '
          'Draft đang chỉnh sửa này — không ảnh hưởng các revision khác.',
    );
    if (confirmed != true || !mounted) return;
    final snapshot = await _captureSnapshotFromCurrentMachine();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật Technical Data từ catalog hiện tại.')),
    );
  }

  Future<bool?> _confirmDialog({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  /// `null` nếu người dùng Hủy; chuỗi rỗng nếu Xác nhận nhưng không nhập note.
  Future<String?> _confirmWithNoteDialog({
    required String title,
    required String message,
    required String noteLabel,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: noteLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return null;
    return controller.text.trim();
  }

  void _applyReloaded(GrindingProposal reloaded) {
    _status = reloaded.status;
    _sentAt = reloaded.sentAt;
    _acceptedAt = reloaded.acceptedAt;
    _rejectedAt = reloaded.rejectedAt;
    _responseNote = reloaded.responseNote;
  }

  Future<void> _markSent() async {
    if (_isSaving || _proposalDbId == null) return;
    final confirmed = await _confirmDialog(
      title: 'Mark as Sent?',
      message:
          'Đánh dấu proposal đã gửi cho khách hàng. Ứng dụng KHÔNG gửi email '
          'tự động — chỉ ghi lại thời điểm gửi.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<GrindingProposalProvider>();
      await provider.markSent(_proposalDbId!, projectId: widget.projectId);
      final reloaded = await provider.getProposal(_proposalDbId!);
      if (!mounted) return;
      setState(() {
        if (reloaded != null) _applyReloaded(reloaded);
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã chuyển sang Sent.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chuyển Sent: $error')));
    }
  }

  Future<void> _markAccepted() async {
    if (_isSaving || _proposalDbId == null) return;
    final note = await _confirmWithNoteDialog(
      title: 'Mark Accepted?',
      message: 'Khách hàng đã đồng ý báo giá này.',
      noteLabel: 'Ghi chú phản hồi — tuỳ chọn',
    );
    if (note == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<GrindingProposalProvider>();
      final ok = await provider.markAccepted(
        _proposalDbId!,
        projectId: widget.projectId,
        responseNote: note.isEmpty ? null : note,
      );
      final reloaded = await provider.getProposal(_proposalDbId!);
      if (!mounted) return;
      setState(() {
        if (reloaded != null) _applyReloaded(reloaded);
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Đã đánh dấu Accepted.'
                : 'Another revision is already marked Accepted.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể Accept: $error')));
    }
  }

  Future<void> _markRejected() async {
    if (_isSaving || _proposalDbId == null) return;
    final note = await _confirmWithNoteDialog(
      title: 'Mark Rejected?',
      message: 'Khách hàng đã từ chối báo giá này.',
      noteLabel: 'Ghi chú phản hồi — tuỳ chọn',
    );
    if (note == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<GrindingProposalProvider>();
      await provider.markRejected(
        _proposalDbId!,
        projectId: widget.projectId,
        responseNote: note.isEmpty ? null : note,
      );
      final reloaded = await provider.getProposal(_proposalDbId!);
      if (!mounted) return;
      setState(() {
        if (reloaded != null) _applyReloaded(reloaded);
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã đánh dấu Rejected.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể Reject: $error')));
    }
  }

  Future<void> _createRevision() async {
    if (_isSaving || _proposalDbId == null) return;
    final confirmed = await _confirmDialog(
      title: 'Create Revision?',
      message:
          'Tạo bản Draft mới (revision kế tiếp) từ proposal này — sao chép '
          'dữ liệu thương mại, line items và Technical Snapshot làm điểm '
          'khởi đầu. Bản hiện tại (R$_revision) KHÔNG bị thay đổi.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<GrindingProposalProvider>();
      final newId = await provider.createRevision(
        _proposalDbId!,
        projectId: widget.projectId,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GrindingProposalEditorScreen(
            projectId: widget.projectId,
            proposalId: newId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tạo Revision: $error')),
      );
    }
  }

  Future<void> _deleteDraft() async {
    if (_isSaving || _proposalDbId == null) return;
    final confirmed = await _confirmDialog(
      title: 'Delete this draft?',
      message: 'Xoá proposal Draft này — không thể hoàn tác.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<GrindingProposalProvider>();
      await provider.deleteProposal(_proposalDbId!, projectId: widget.projectId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xoá: $error')));
    }
  }

  void _openRevision(int proposalId) {
    if (proposalId == _proposalDbId) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrindingProposalEditorScreen(
          projectId: widget.projectId,
          proposalId: proposalId,
        ),
      ),
    );
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final proposal = _buildProposal();
      final bytes = await GrindingProposalPdfService.buildPdf(
        project: _project!,
        proposal: proposal,
        lineItems: _allLineItems,
        currentMachine: _currentMachine,
        currentSeries: _currentSeries,
        machineUnavailable: _machineUnavailable,
      );
      if (!mounted) return;
      final fileName =
          '${_proposalNumber ?? 'Proposal'}-${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
          title: 'Grinding Machine Technical Proposal',
          text: _proposalNumber ?? _project?.projectName ?? '',
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

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final isEditable = _isEditable;
    final isFinal = _status == GrindingProposalStatus.final_;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Proposal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final proposal = _buildProposal();
    final totals = GrindingProposalCalculator.calculate(proposal, _allLineItems);
    final expiresAt = proposal.expiresAt;
    final expired = proposal.isExpired();

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(
          _proposalNumber == null ? 'New Proposal' : '$_proposalNumber R$_revision',
        ),
        actions: [
          IconButton(
            key: const Key('grinding_proposal_export_button'),
            tooltip: isEditable ? 'Preview' : 'Export PDF / Share',
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _isExporting ? null : _exportAndShare,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              _StatusBadge(status: _status),
              if (_machineUnavailable) ...[
                const SizedBox(width: 8),
                Text(
                  'Current machine no longer exists in database',
                  key: const Key('grinding_proposal_machine_unavailable'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11.5),
                ),
              ],
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 6),
            Text(
              expired
                  ? 'Expired'
                  : 'Valid until: ${DateFormat('dd/MM/yyyy').format(expiresAt)}',
              key: const Key('grinding_proposal_expiry_text'),
              style: TextStyle(
                color: expired ? Theme.of(context).colorScheme.error : palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Currency', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          !isEditable
              ? Text(_currency, style: TextStyle(color: palette.ink))
              : DropdownButtonFormField<String>(
                  key: const Key('grinding_proposal_currency_field'),
                  initialValue: _currency,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'VND', child: Text('VND')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (v) => setState(() => _currency = v ?? 'VND'),
                ),
          const SizedBox(height: 16),
          _MachineSection(
            machine: _currentMachine,
            series: _currentSeries,
            unavailable: _machineUnavailable,
            hasMachineId: _machineId != null,
          ),
          const SizedBox(height: 12),
          if (isEditable && _revision > 0 && _currentMachine != null) ...[
            OutlinedButton.icon(
              key: const Key('grinding_proposal_refresh_technical_button'),
              onPressed: _isSaving ? null : _refreshTechnicalData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Technical Data'),
            ),
            const SizedBox(height: 12),
          ],
          if (!isEditable)
            _ReadOnlyMoneyRows(
              currency: _currency,
              rows: [
                ('Unit price', proposal.machineUnitPrice),
                ('Quantity', proposal.machineQuantity),
              ],
            )
          else ...[
            TextFormField(
              key: const Key('grinding_proposal_machine_price_field'),
              controller: _machineUnitPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Machine unit price',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('grinding_proposal_machine_quantity_field'),
              controller: _machineQuantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _LineItemSection(
            title: 'Accessories / Options',
            addKey: const Key('grinding_proposal_add_accessory'),
            items: _accessories,
            readOnly: !isEditable,
            onAdd: () => setState(
              () => _accessories.add(
                const GrindingProposalLineItem(
                  kind: GrindingProposalLineItemKind.accessory,
                  name: '',
                ),
              ),
            ),
            onRemove: (i) => setState(() => _accessories.removeAt(i)),
            onChanged: (i, item) => setState(() => _accessories[i] = item),
            currency: _currency,
          ),
          const SizedBox(height: 16),
          _LineItemSection(
            title: 'Additional Costs (Shipping/Installation/Training/Other)',
            addKey: const Key('grinding_proposal_add_cost'),
            items: _additionalCosts,
            readOnly: !isEditable,
            onAdd: () => setState(
              () => _additionalCosts.add(
                const GrindingProposalLineItem(
                  kind: GrindingProposalLineItemKind.additionalCost,
                  name: '',
                ),
              ),
            ),
            onRemove: (i) => setState(() => _additionalCosts.removeAt(i)),
            onChanged: (i, item) => setState(() => _additionalCosts[i] = item),
            currency: _currency,
          ),
          const SizedBox(height: 20),
          if (!isEditable)
            _ReadOnlyMoneyRows(
              currency: _currency,
              rows: [
                ('Discount', proposal.discount),
                ('VAT (%)', proposal.vatPercent),
              ],
            )
          else ...[
            TextFormField(
              key: const Key('grinding_proposal_discount_field'),
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Discount (amount) — tuỳ chọn',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('grinding_proposal_vat_field'),
              controller: _vatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'VAT (%) — tuỳ chọn',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('grinding_proposal_notes_field'),
            controller: _notesController,
            readOnly: !isEditable,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          _TermsSection(
            editable: isEditable,
            deliveryTimeController: _deliveryTimeController,
            warrantyController: _warrantyController,
            paymentTermsController: _paymentTermsController,
            validityDaysController: _validityDaysController,
          ),
          const SizedBox(height: 20),
          _CalculationSummary(totals: totals, currency: _currency),
          const SizedBox(height: 24),
          if (isEditable) ...[
            FilledButton.icon(
              key: const Key('grinding_proposal_save_draft_button'),
              onPressed: _isSaving ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('grinding_proposal_finalize_button'),
              onPressed: _isSaving ? null : _finalize,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Finalize'),
            ),
            if (_proposalDbId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('grinding_proposal_delete_button'),
                onPressed: _isSaving ? null : _deleteDraft,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
          if (isFinal) ...[
            FilledButton.icon(
              key: const Key('grinding_proposal_mark_sent_button'),
              onPressed: _isSaving ? null : _markSent,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Mark as Sent'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('grinding_proposal_create_revision_button'),
              onPressed: _isSaving ? null : _createRevision,
              icon: const Icon(Icons.difference_outlined),
              label: const Text('Create Revision'),
            ),
          ],
          if (_status == GrindingProposalStatus.sent) ...[
            FilledButton.icon(
              key: const Key('grinding_proposal_mark_accepted_button'),
              onPressed: _isSaving ? null : _markAccepted,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark Accepted'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('grinding_proposal_mark_rejected_button'),
              onPressed: _isSaving ? null : _markRejected,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Mark Rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('grinding_proposal_create_revision_button'),
              onPressed: _isSaving ? null : _createRevision,
              icon: const Icon(Icons.difference_outlined),
              label: const Text('Create Revision'),
            ),
          ],
          if (_status == GrindingProposalStatus.rejected) ...[
            OutlinedButton.icon(
              key: const Key('grinding_proposal_create_revision_button'),
              onPressed: _isSaving ? null : _createRevision,
              icon: const Icon(Icons.difference_outlined),
              label: const Text('Create Revision'),
            ),
          ],
          if (_revisions.length > 1) ...[
            const SizedBox(height: 24),
            _RevisionHistorySection(
              revisions: _revisions,
              currentId: _proposalDbId,
              onTap: _openRevision,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final GrindingProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final color = switch (status) {
      GrindingProposalStatus.draft => palette.muted,
      GrindingProposalStatus.final_ => palette.navy,
      GrindingProposalStatus.sent => palette.navy,
      GrindingProposalStatus.accepted => Colors.green.shade700,
      GrindingProposalStatus.rejected => Theme.of(context).colorScheme.error,
    };
    final label = switch (status) {
      GrindingProposalStatus.draft => 'DRAFT',
      GrindingProposalStatus.final_ => 'FINAL',
      GrindingProposalStatus.sent => 'SENT',
      GrindingProposalStatus.accepted => 'ACCEPTED',
      GrindingProposalStatus.rejected => 'REJECTED',
    };
    return Container(
      key: const Key('grinding_proposal_status_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.editable,
    required this.deliveryTimeController,
    required this.warrantyController,
    required this.paymentTermsController,
    required this.validityDaysController,
  });

  final bool editable;
  final TextEditingController deliveryTimeController;
  final TextEditingController warrantyController;
  final TextEditingController paymentTermsController;
  final TextEditingController validityDaysController;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    if (!editable) {
      final rows = [
        ('Delivery time', deliveryTimeController.text),
        ('Warranty', warrantyController.text),
        ('Payment terms', paymentTermsController.text),
        (
          'Validity',
          validityDaysController.text.isEmpty
              ? ''
              : '${validityDaysController.text} ngày',
        ),
      ];
      if (rows.every((r) => r.$2.isEmpty)) return const SizedBox.shrink();
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
            Text('Terms', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              if (value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '$label: $value',
                    style: TextStyle(color: palette.ink, fontSize: 13),
                  ),
                ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms — tuỳ chọn', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('grinding_proposal_delivery_time_field'),
          controller: deliveryTimeController,
          decoration: const InputDecoration(
            labelText: 'Delivery time',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('grinding_proposal_warranty_field'),
          controller: warrantyController,
          decoration: const InputDecoration(
            labelText: 'Warranty',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('grinding_proposal_payment_terms_field'),
          controller: paymentTermsController,
          decoration: const InputDecoration(
            labelText: 'Payment terms',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('grinding_proposal_validity_days_field'),
          controller: validityDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Validity (số ngày)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _RevisionHistorySection extends StatelessWidget {
  const _RevisionHistorySection({
    required this.revisions,
    required this.currentId,
    required this.onTap,
  });

  final List<GrindingProposal> revisions;
  final int? currentId;
  final ValueChanged<int> onTap;

  static String _statusLabel(GrindingProposalStatus status) => switch (status) {
    GrindingProposalStatus.draft => 'Draft',
    GrindingProposalStatus.final_ => 'Final',
    GrindingProposalStatus.sent => 'Sent',
    GrindingProposalStatus.accepted => 'Accepted',
    GrindingProposalStatus.rejected => 'Rejected',
  };

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      key: const Key('grinding_proposal_revision_history'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revision History', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final revision in revisions)
            InkWell(
              key: Key('grinding_proposal_revision_tile_${revision.revision}'),
              onTap: revision.id == null ? null : () => onTap(revision.id!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text(
                      'R${revision.revision}',
                      style: TextStyle(
                        color: revision.id == currentId ? palette.navy : palette.ink,
                        fontWeight: revision.id == currentId ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    Text(
                      _statusLabel(revision.status),
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(revision.updatedAt),
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                    if (revision.id == currentId)
                      Text(
                        '(đang xem)',
                        style: TextStyle(color: palette.muted, fontSize: 11.5, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MachineSection extends StatelessWidget {
  const _MachineSection({
    required this.machine,
    required this.series,
    required this.unavailable,
    required this.hasMachineId,
  });

  final GrindingMachine? machine;
  final GrindingSeries? series;
  final bool unavailable;
  final bool hasMachineId;

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
          Text('Selected Machine', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (machine != null) ...[
            Text(machine!.model, style: TextStyle(color: palette.ink, fontWeight: FontWeight.w800, fontSize: 15)),
            if (series != null) Text(series!.nameVi, style: TextStyle(color: palette.muted, fontSize: 12)),
          ] else if (!hasMachineId)
            Text('No machine selected', style: TextStyle(color: palette.muted))
          else
            Text(
              'Current machine no longer exists in database',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyMoneyRows extends StatelessWidget {
  const _ReadOnlyMoneyRows({required this.rows, required this.currency});
  final List<(String, double?)> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '$label: ${value == null ? 'Not specified' : '${_fmtNum(value)} $currency'}',
              style: TextStyle(color: palette.ink, fontSize: 13),
            ),
          ),
      ],
    );
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _LineItemSection extends StatelessWidget {
  const _LineItemSection({
    required this.title,
    required this.addKey,
    required this.items,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    required this.currency,
  });

  final String title;
  final Key addKey;
  final List<GrindingProposalLineItem> items;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, GrindingProposalLineItem) onChanged;
  final String currency;

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
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
              ),
              if (!readOnly)
                IconButton(
                  key: addKey,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: onAdd,
                ),
            ],
          ),
          if (items.isEmpty)
            Text('Chưa có dòng nào.', style: TextStyle(color: palette.muted, fontSize: 12.5))
          else
            for (var i = 0; i < items.length; i++)
              _LineItemRow(
                key: ValueKey('${title}_$i'),
                index: i,
                item: items[i],
                readOnly: readOnly,
                currency: currency,
                onRemove: () => onRemove(i),
                onChanged: (item) => onChanged(i, item),
              ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.readOnly,
    required this.currency,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final GrindingProposalLineItem item;
  final bool readOnly;
  final String currency;
  final VoidCallback onRemove;
  final ValueChanged<GrindingProposalLineItem> onChanged;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final _nameController = TextEditingController(text: widget.item.name);
  late final _quantityController = TextEditingController(
    text: widget.item.quantity == null ? '' : _num(widget.item.quantity!),
  );
  late final _priceController = TextEditingController(
    text: widget.item.unitPrice == null ? '' : _num(widget.item.unitPrice!),
  );

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      widget.item.copyWith(
        name: _nameController.text.trim(),
        quantity: GrindingNumberParser.parseDouble(_quantityController.text),
        clearQuantity: _quantityController.text.trim().isEmpty,
        unitPrice: GrindingNumberParser.parseDouble(_priceController.text),
        clearUnitPrice: _priceController.text.trim().isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    if (widget.readOnly) {
      final total = widget.item.lineTotal;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '${widget.item.name}: ${widget.item.quantity == null ? '—' : _num(widget.item.quantity!)} × '
          '${widget.item.unitPrice == null ? 'Not specified' : '${_num(widget.item.unitPrice!)} ${widget.currency}'}'
          ' = ${total == null ? 'Not specified' : '${_num(total)} ${widget.currency}'}',
          style: TextStyle(color: palette.ink, fontSize: 12.5),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('grinding_proposal_item_name_${widget.index}_${widget.key}'),
              controller: _nameController,
              onChanged: (_) => _emit(),
              decoration: const InputDecoration(hintText: 'Tên', isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _emit(),
              decoration: const InputDecoration(hintText: 'SL', isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _emit(),
              decoration: const InputDecoration(hintText: 'Đơn giá', isDense: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

class _CalculationSummary extends StatelessWidget {
  const _CalculationSummary({required this.totals, required this.currency});
  final GrindingProposalTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    String money(double? v) => v == null ? 'Not specified' : '${_num(v)} $currency';
    return Container(
      key: const Key('grinding_proposal_calculation_summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calculation', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _row(palette, 'Machine subtotal', money(totals.machineSubtotal)),
          _row(palette, 'Accessories subtotal', money(totals.accessoriesSubtotal)),
          _row(palette, 'Additional costs subtotal', money(totals.additionalCostsSubtotal)),
          _row(palette, 'Subtotal', money(totals.subtotal)),
          _row(palette, 'After discount', money(totals.afterDiscount)),
          _row(
            palette,
            'VAT',
            totals.vatPercent == null ? 'Not specified' : '${_num(totals.vatPercent!)}% (${money(totals.vatAmount)})',
          ),
          const Divider(),
          _row(palette, 'Grand Total', money(totals.grandTotal), bold: true),
          if (totals.hasIncompleteData) ...[
            const SizedBox(height: 6),
            Text(
              'Một số dòng chưa có giá/số lượng/VAT — tổng trên có thể chưa đầy đủ.',
              style: TextStyle(color: palette.muted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(DtcPaletteData palette, String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: palette.muted, fontSize: 12.5))),
        Text(
          value,
          style: TextStyle(
            color: palette.ink,
            fontSize: bold ? 15 : 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
