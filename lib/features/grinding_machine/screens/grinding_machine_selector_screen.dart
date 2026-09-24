import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine_match.dart';
import '../models/grinding_material.dart';
import '../models/grinding_selection_criteria.dart';
import '../models/grinding_selection_project.dart';
import '../providers/grinding_machine_provider.dart';
import '../providers/grinding_selection_project_provider.dart';
import '../services/grinding_machine_selection_service.dart';
import '../utils/grinding_number_parser.dart';

/// "Machine Selector" (Phase 6, mục 8-13; Phase 7, mục 4-5-9-11-12: Project
/// Information + Save/Update Project + Selected machine + Shortlist +
/// Re-evaluate) — form yêu cầu khách hàng, đối chiếu qua
/// [GrindingMachineSelectionService] (3 trạng thái MATCH/NOT_MATCH/UNKNOWN
/// theo từng tiêu chí), hiển thị kết quả kèm lý do minh bạch. Khác
/// [GrindingMachineSelectionScreen] cũ (vẫn giữ để tránh regression, không
/// còn hiển thị trên Home): luồng này KHÔNG loại máy khỏi kết quả chỉ vì
/// thiếu dữ liệu.
///
/// [existingProjectId] khác `null` -> mở ở chế độ SỬA 1 hồ sơ đã lưu (mục
/// 8): nạp sẵn Project Information + criteria + selected/shortlist machine,
/// KHÔNG tự chạy lại recommendation (mục 9, tránh ghi đè âm thầm) — người
/// dùng phải bấm "Re-evaluate" mới chạy lại
/// [GrindingMachineSelectionService].
class GrindingMachineSelectorScreen extends StatefulWidget {
  const GrindingMachineSelectorScreen({super.key, this.existingProjectId});

  final int? existingProjectId;

  @override
  State<GrindingMachineSelectorScreen> createState() =>
      _GrindingMachineSelectorScreenState();
}

class _GrindingMachineSelectorScreenState
    extends State<GrindingMachineSelectorScreen> {
  final _projectNameController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _capacityController = TextEditingController();
  final _finenessController = TextEditingController();
  final _feedSizeController = TextEditingController();
  final _motorController = TextEditingController();
  final _materialFreeTextController = TextEditingController();
  final _applicationController = TextEditingController();
  final _notesController = TextEditingController();

  String _finenessUnit = 'µm';
  GrindingMaterial? _selectedMaterial;
  List<GrindingMaterial> _materials = const [];
  bool _isLoadingMaterials = true;
  bool _isLoadingProject = false;
  bool _isSearching = false;
  bool _isSaving = false;
  List<GrindingMachineMatch>? _results;

  int? _projectId;
  DateTime? _createdAt;
  GrindingProjectStatus _status = GrindingProjectStatus.draft;
  String? _primaryMachineId;
  final Set<String> _shortlistMachineIds = {};

  @override
  void initState() {
    super.initState();
    _projectId = widget.existingProjectId;
    _isLoadingProject = widget.existingProjectId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final grindingProvider = context.read<GrindingMachineProvider>();
    final materials = await grindingProvider.getAllMaterials();
    if (!mounted) return;
    setState(() {
      _materials = materials;
      _isLoadingMaterials = false;
    });

    final projectId = widget.existingProjectId;
    if (projectId == null) return;
    final projectProvider = context.read<GrindingSelectionProjectProvider>();
    final project = await projectProvider.getProject(projectId);
    final machines = await projectProvider.getProjectMachines(projectId);
    if (!mounted || project == null) return;
    setState(() {
      _projectNameController.text = project.projectName;
      _customerNameController.text = project.customerName ?? '';
      _contactNameController.text = project.contactName ?? '';
      _contactInfoController.text = project.contactInfo ?? '';
      _capacityController.text = project.requiredCapacityKgH == null
          ? ''
          : _fmt(project.requiredCapacityKgH!);
      _finenessController.text = project.requiredFinenessValue == null
          ? ''
          : _fmt(project.requiredFinenessValue!);
      if (project.requiredFinenessUnit != null) {
        _finenessUnit = project.requiredFinenessUnit!;
      }
      _feedSizeController.text = project.feedSizeMm == null
          ? ''
          : _fmt(project.feedSizeMm!);
      _motorController.text = project.maxMotorKw == null
          ? ''
          : _fmt(project.maxMotorKw!);
      _applicationController.text = project.application ?? '';
      _notesController.text = project.notes ?? '';
      _status = project.status;
      _createdAt = project.createdAt;
      _primaryMachineId = machines.primaryMachineId;
      _shortlistMachineIds
        ..clear()
        ..addAll(machines.shortlistMachineIds);
      if (project.materialId != null) {
        final match = _materials
            .where((m) => m.materialId == project.materialId)
            .toList();
        if (match.isNotEmpty) _selectedMaterial = match.first;
      }
      if (_selectedMaterial == null && project.materialName != null) {
        _materialFreeTextController.text = project.materialName!;
      }
      _isLoadingProject = false;
    });
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _customerNameController.dispose();
    _contactNameController.dispose();
    _contactInfoController.dispose();
    _capacityController.dispose();
    _finenessController.dispose();
    _feedSizeController.dispose();
    _motorController.dispose();
    _materialFreeTextController.dispose();
    _applicationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parse(String text) => GrindingNumberParser.parseDouble(text);
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  String? _textOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    final capacity = _parse(_capacityController.text);
    final fineness = _parse(_finenessController.text);
    final feedSize = _parse(_feedSizeController.text);
    final motor = _parse(_motorController.text);
    final materialName = _selectedMaterial?.nameVi ??
        (_materialFreeTextController.text.trim().isEmpty
            ? null
            : _materialFreeTextController.text.trim());
    final application = _applicationController.text.trim().isEmpty
        ? null
        : _applicationController.text.trim();

    if (capacity == null &&
        fineness == null &&
        feedSize == null &&
        motor == null &&
        _selectedMaterial == null &&
        application == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập ít nhất 1 tiêu chí để tìm máy phù hợp.'),
        ),
      );
      return;
    }

    setState(() => _isSearching = true);
    final provider = context.read<GrindingMachineProvider>();
    final criteria = GrindingSelectionCriteria(
      materialId: _selectedMaterial?.materialId,
      materialName: materialName,
      capacityKgH: capacity,
      finenessValue: fineness,
      finenessUnit: fineness == null ? null : _finenessUnit,
      feedSizeMm: feedSize,
      maxMotorKw: motor,
      application: application,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final seriesByCode = {for (final s in provider.series) s.seriesCode: s};
    final seriesTags = await provider.getAllSelectionTagsGrouped();
    final materialSeriesMap = _selectedMaterial == null
        ? const <dynamic>[]
        : await provider.getMaterialSeriesMapFor(_selectedMaterial!.materialId);

    final results = GrindingMachineSelectionService.evaluate(
      criteria: criteria,
      machines: provider.machines,
      seriesByCode: seriesByCode,
      seriesTags: seriesTags,
      materialSeriesMap: materialSeriesMap.cast(),
    );

    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  void _togglePrimary(String machineId) {
    setState(() {
      _primaryMachineId = _primaryMachineId == machineId ? null : machineId;
    });
  }

  void _toggleShortlist(String machineId) {
    setState(() {
      if (_shortlistMachineIds.contains(machineId)) {
        _shortlistMachineIds.remove(machineId);
      } else {
        _shortlistMachineIds.add(machineId);
      }
    });
  }

  void _compareShortlist() {
    context.push(
      '/grinding_machine/compare',
      extra: _shortlistMachineIds.toList(),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    var name = _projectNameController.text.trim();
    if (name.isEmpty) {
      // Chỉ dùng thời điểm THỰC (DateTime.now()), không hard-code (mục 5).
      name = 'Grinding Project ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
    }
    setState(() => _isSaving = true);
    final now = DateTime.now();
    final materialName = _selectedMaterial?.nameVi ?? _textOrNull(_materialFreeTextController);
    final finenessValue = _parse(_finenessController.text);
    final project = GrindingSelectionProject(
      id: _projectId,
      projectName: name,
      customerName: _textOrNull(_customerNameController),
      contactName: _textOrNull(_contactNameController),
      contactInfo: _textOrNull(_contactInfoController),
      materialId: _selectedMaterial?.materialId,
      materialName: materialName,
      requiredCapacityKgH: _parse(_capacityController.text),
      requiredFinenessValue: finenessValue,
      requiredFinenessUnit: finenessValue == null ? null : _finenessUnit,
      feedSizeMm: _parse(_feedSizeController.text),
      maxMotorKw: _parse(_motorController.text),
      application: _textOrNull(_applicationController),
      notes: _textOrNull(_notesController),
      status: _status,
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );

    final projectProvider = context.read<GrindingSelectionProjectProvider>();
    try {
      final int id;
      if (_projectId == null) {
        id = await projectProvider.createProject(
          project,
          primaryMachineId: _primaryMachineId,
          shortlistMachineIds: _shortlistMachineIds.toList(),
        );
      } else {
        await projectProvider.updateProject(
          project,
          primaryMachineId: _primaryMachineId,
          clearPrimaryMachine: _primaryMachineId == null,
          shortlistMachineIds: _shortlistMachineIds.toList(),
        );
        id = _projectId!;
      }
      if (!mounted) return;
      setState(() {
        _projectId = id;
        _createdAt = project.createdAt;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu dự án.')),
      );
      context.push('/grinding_machine/projects/$id');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu dự án: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final results = _results;
    final isEditMode = widget.existingProjectId != null;

    if (_isLoadingProject) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Chọn máy phù hợp')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(isEditMode ? 'Sửa dự án' : 'Chọn máy phù hợp'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ProjectInfoSection(
            projectNameController: _projectNameController,
            customerNameController: _customerNameController,
            contactNameController: _contactNameController,
            contactInfoController: _contactInfoController,
            status: _status,
            onStatusChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 18),
          Text(
            'Nhập yêu cầu khách hàng',
            style: TextStyle(
              color: palette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bỏ trống tiêu chí chưa biết — hệ thống sẽ đánh dấu rõ '
            '"Chưa có dữ liệu" thay vì suy đoán.',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text('Nguyên liệu', style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _isLoadingMaterials
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              : DropdownButtonFormField<GrindingMaterial?>(
                  key: const Key('grinding_selector_material_field'),
                  initialValue: _selectedMaterial,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Chọn từ database',
                  ),
                  items: [
                    const DropdownMenuItem<GrindingMaterial?>(
                      child: Text('— Không chọn —'),
                    ),
                    for (final m in _materials)
                      DropdownMenuItem<GrindingMaterial?>(
                        value: m,
                        child: Text(m.nameVi),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedMaterial = value),
                ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('grinding_selector_material_free_text'),
            controller: _materialFreeTextController,
            enabled: _selectedMaterial == null,
            decoration: const InputDecoration(
              labelText: 'Hoặc nhập nguyên liệu khác',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('grinding_selector_capacity_field'),
            controller: _capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Công suất yêu cầu (kg/h)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('grinding_selector_fineness_field'),
                  controller: _finenessController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Độ mịn yêu cầu',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: const Key('grinding_selector_fineness_unit'),
                value: _finenessUnit,
                items: const [
                  DropdownMenuItem(value: 'mm', child: Text('mm')),
                  DropdownMenuItem(value: 'mesh', child: Text('mesh')),
                  DropdownMenuItem(value: 'µm', child: Text('µm')),
                ],
                onChanged: (value) =>
                    setState(() => _finenessUnit = value ?? 'µm'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('grinding_selector_feed_size_field'),
            controller: _feedSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Kích thước đầu vào (mm) — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('grinding_selector_motor_field'),
            controller: _motorController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Công suất động cơ tối đa (kW) — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('grinding_selector_application_field'),
            controller: _applicationController,
            decoration: const InputDecoration(
              labelText: 'Ứng dụng / quy trình — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('grinding_selector_notes_field'),
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('grinding_selector_submit_button'),
            onPressed: _isSearching ? null : _submit,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(isEditMode ? 'Re-evaluate' : 'Tìm máy phù hợp'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
          if (_primaryMachineId != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('grinding_selector_primary_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.cyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Selected: $_primaryMachineId',
                style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (results != null) ...[
            const SizedBox(height: 24),
            _ResultsSection(
              results: results,
              primaryMachineId: _primaryMachineId,
              shortlistMachineIds: _shortlistMachineIds,
              onTogglePrimary: _togglePrimary,
              onToggleShortlist: _toggleShortlist,
            ),
          ],
          if (_shortlistMachineIds.length >= 2) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('grinding_selector_compare_shortlist_button'),
              onPressed: _compareShortlist,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text('So sánh ${_shortlistMachineIds.length} model đã chọn'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('grinding_selector_save_button'),
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_projectId == null ? 'Lưu dự án' : 'Cập nhật dự án'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              backgroundColor: palette.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectInfoSection extends StatelessWidget {
  const _ProjectInfoSection({
    required this.projectNameController,
    required this.customerNameController,
    required this.contactNameController,
    required this.contactInfoController,
    required this.status,
    required this.onStatusChanged,
  });

  final TextEditingController projectNameController;
  final TextEditingController customerNameController;
  final TextEditingController contactNameController;
  final TextEditingController contactInfoController;
  final GrindingProjectStatus status;
  final ValueChanged<GrindingProjectStatus> onStatusChanged;

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
          Text(
            'Project Information',
            style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('grinding_selector_project_name_field'),
            controller: projectNameController,
            decoration: const InputDecoration(
              labelText: 'Project name — để trống sẽ tự đặt theo thời gian',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('grinding_selector_customer_name_field'),
            controller: customerNameController,
            decoration: const InputDecoration(
              labelText: 'Customer name — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('grinding_selector_contact_name_field'),
            controller: contactNameController,
            decoration: const InputDecoration(
              labelText: 'Contact person — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('grinding_selector_contact_info_field'),
            controller: contactInfoController,
            decoration: const InputDecoration(
              labelText: 'Contact info (SĐT/email) — tuỳ chọn',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<GrindingProjectStatus>(
            key: const Key('grinding_selector_status_field'),
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: GrindingProjectStatus.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onStatusChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.results,
    required this.primaryMachineId,
    required this.shortlistMachineIds,
    required this.onTogglePrimary,
    required this.onToggleShortlist,
  });

  final List<GrindingMachineMatch> results;
  final String? primaryMachineId;
  final Set<String> shortlistMachineIds;
  final ValueChanged<String> onTogglePrimary;
  final ValueChanged<String> onToggleShortlist;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Database chưa có model nào để đối chiếu.',
          style: TextStyle(color: palette.muted),
        ),
      );
    }
    final best = results.first;
    final hasExactMatch = best.label == GrindingMatchLabel.strong;
    final topResults = results.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasExactMatch ? 'Recommended Machines' : 'Không tìm thấy máy khớp hoàn toàn',
          key: const Key('grinding_selector_results_title'),
          style: TextStyle(
            color: palette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (!hasExactMatch) ...[
          const SizedBox(height: 4),
          Text(
            'Dưới đây là các model gần đúng nhất — xem rõ tiêu chí nào chưa '
            'đáp ứng hoặc chưa có dữ liệu trước khi quyết định.',
            style: TextStyle(color: palette.muted, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        for (final match in topResults)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MatchCard(
              match: match,
              isPrimary: match.machine.machineId == primaryMachineId,
              isShortlisted: shortlistMachineIds.contains(match.machine.machineId),
              onTogglePrimary: () => onTogglePrimary(match.machine.machineId),
              onToggleShortlist: () => onToggleShortlist(match.machine.machineId),
            ),
          ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isPrimary,
    required this.isShortlisted,
    required this.onTogglePrimary,
    required this.onToggleShortlist,
  });

  final GrindingMachineMatch match;
  final bool isPrimary;
  final bool isShortlisted;
  final VoidCallback onTogglePrimary;
  final VoidCallback onToggleShortlist;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final (labelText, labelColor) = switch (match.label) {
      GrindingMatchLabel.strong => ('Strong Match', palette.cyan),
      GrindingMatchLabel.possible => ('Possible Match', palette.navy),
      GrindingMatchLabel.closest => ('Insufficient Data', errorColor),
    };

    return Container(
      key: Key('grinding_selector_match_${match.machine.machineId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? palette.cyan : palette.border,
          width: isPrimary ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.machine.model,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (match.series != null)
                      Text(
                        match.series!.nameVi,
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labelText,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final criterion in match.criteria)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (criterion.status) {
                      GrindingCriterionStatus.match => '✓ ',
                      GrindingCriterionStatus.notMatch => '✗ ',
                      GrindingCriterionStatus.unknown => '? ',
                    },
                    style: TextStyle(
                      color: switch (criterion.status) {
                        GrindingCriterionStatus.match => palette.cyan,
                        GrindingCriterionStatus.notMatch => errorColor,
                        GrindingCriterionStatus.unknown => palette.muted,
                      },
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${criterion.label}: ${criterion.actualDisplay ?? 'Chưa có dữ liệu'}'
                      ' (yêu cầu ${criterion.requiredDisplay})',
                      style: TextStyle(color: palette.ink, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key(
                    'grinding_selector_detail_${match.machine.machineId}',
                  ),
                  onPressed: () => context.push(
                    '/grinding_machine/detail/${match.machine.machineId}',
                  ),
                  child: const Text('Xem chi tiết'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key(
                    'grinding_selector_shortlist_${match.machine.machineId}',
                  ),
                  onPressed: onToggleShortlist,
                  icon: Icon(
                    isShortlisted ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                  ),
                  label: const Text('Shortlist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: isPrimary
                ? FilledButton.icon(
                    key: Key(
                      'grinding_selector_select_${match.machine.machineId}',
                    ),
                    onPressed: onTogglePrimary,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Đã chọn — Bấm để bỏ chọn'),
                  )
                : OutlinedButton.icon(
                    key: Key(
                      'grinding_selector_select_${match.machine.machineId}',
                    ),
                    onPressed: onTogglePrimary,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Chọn máy này'),
                  ),
          ),
        ],
      ),
    );
  }
}
