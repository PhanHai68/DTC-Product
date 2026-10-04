import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/fault_record.dart';
import '../providers/fault_bank_provider.dart';
import '../utils/fault_duration.dart';
import '../utils/fault_groups.dart';
import '../utils/fault_ids.dart';
import '../widgets/fault_photo_thumb.dart';
import '../widgets/fault_record_card.dart';
import '../widgets/machine_model_dialogs.dart';

/// Ghi nhận sự cố mới, hoặc sửa khi có [recordId].
class FaultRecordFormScreen extends StatefulWidget {
  const FaultRecordFormScreen({super.key, this.recordId});

  final String? recordId;

  bool get isEditing => recordId != null;

  @override
  State<FaultRecordFormScreen> createState() => _FaultRecordFormScreenState();
}

class _StepDraft {
  _StepDraft({required this.id, String content = '', this.photo})
    : controller = TextEditingController(text: content);

  final String id;
  final TextEditingController controller;
  FaultAttachment? photo;
}

class _FaultRecordFormScreenState extends State<FaultRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serial = TextEditingController();
  final _symptom = TextEditingController();
  final _cause = TextEditingController();
  final _parts = TextEditingController();
  final _tools = TextEditingController();
  final _duration = TextEditingController();
  final _customGroup = TextEditingController();

  /// Mã lỗi và cảnh báo an toàn đã bỏ khỏi form — giữ nguyên giá trị cũ
  /// của bản ghi khi sửa để không mất dữ liệu đã ghi trước đó.
  String? _errorCode;
  String? _safety;

  late final String _recordId;
  String? _machineModelId;
  String? _group;
  final List<_StepDraft> _steps = [];
  final List<FaultAttachment> _photos = [];

  /// Ảnh chụp/chọn trong phiên này, chưa lưu — xóa file nếu bỏ không lưu.
  final Set<String> _newFiles = {};

  List<FaultRecordSummary> _similar = const [];
  Timer? _similarDebounce;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FaultBankProvider>();
    if (widget.isEditing) {
      _recordId = widget.recordId!;
      _loadExisting(provider);
    } else {
      // Sinh mã trước để đặt tên file ảnh theo mã bản ghi.
      _recordId = FaultIds.newRecordId(provider.profile!.engineerCode);
      _steps.add(_StepDraft(id: FaultIds.newChildId()));
      _loading = false;
    }
  }

  Future<void> _loadExisting(FaultBankProvider provider) async {
    final record = await provider.getRecord(_recordId);
    if (!mounted) return;
    if (record == null) {
      setState(() => _loading = false);
      return;
    }
    _machineModelId = record.machineModelId;
    _serial.text = record.serialNumber ?? '';
    _errorCode = record.errorCode;
    _symptom.text = record.symptom;
    _cause.text = record.cause;
    _parts.text = record.parts ?? '';
    _tools.text = record.tools ?? '';
    final minutes = record.durationMinutes;
    _duration.text = minutes == null ? '' : FaultDuration.hoursText(minutes);
    _safety = record.safetyWarning;
    final group = record.faultGroup;
    if (group != null) {
      if (provider.groupOptions.contains(group)) {
        _group = group;
      } else {
        _group = FaultGroups.other;
        _customGroup.text = group;
      }
    }
    _steps.addAll(
      record.steps.map(
        (s) => _StepDraft(id: s.id, content: s.content, photo: s.photo),
      ),
    );
    if (_steps.isEmpty) _steps.add(_StepDraft(id: FaultIds.newChildId()));
    _photos.addAll(record.photos);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _similarDebounce?.cancel();
    for (final c in [
      _serial,
      _symptom,
      _cause,
      _parts,
      _tools,
      _duration,
      _customGroup,
    ]) {
      c.dispose();
    }
    for (final s in _steps) {
      s.controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  // ------------------------------------------------------------ Gợi ý trùng

  void _onSymptomChanged(String value) {
    _markDirty();
    _similarDebounce?.cancel();
    _similarDebounce = Timer(
      const Duration(milliseconds: 400),
      _refreshSimilar,
    );
  }

  Future<void> _refreshSimilar() async {
    final results = await context.read<FaultBankProvider>().findSimilar(
      _symptom.text,
      machineModelId: _machineModelId,
      excludeId: widget.isEditing ? _recordId : null,
    );
    if (mounted) setState(() => _similar = results);
  }

  // ------------------------------------------------------------------ Ảnh

  Future<FaultAttachment?> _pickPhoto({String? stepId}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return null;
    try {
      final photo = await context.read<FaultBankProvider>().photoService.pick(
        source: source,
        recordId: _recordId,
        stepId: stepId,
      );
      if (photo != null) {
        _newFiles.add(photo.fileName);
        _markDirty();
      }
      return photo;
    } on PlatformException catch (error) {
      _showSnack('Không lấy được ảnh: ${error.message ?? error.code}');
    } catch (error) {
      _showSnack('Không lấy được ảnh: $error');
    }
    return null;
  }

  /// Gỡ ảnh khỏi form. Ảnh mới chụp trong phiên thì xóa file luôn; ảnh đã
  /// lưu trước đó chỉ xóa file sau khi bấm Lưu.
  Future<void> _discardPhoto(FaultAttachment photo) async {
    if (_newFiles.remove(photo.fileName)) {
      await context.read<FaultBankProvider>().photoService.delete(photo);
    }
    _markDirty();
  }

  Future<void> _addRecordPhoto() async {
    final photo = await _pickPhoto();
    if (photo != null) setState(() => _photos.add(photo));
  }

  Future<void> _setStepPhoto(_StepDraft step) async {
    final photo = await _pickPhoto(stepId: step.id);
    if (photo == null) return;
    final old = step.photo;
    setState(() => step.photo = photo);
    if (old != null) await _discardPhoto(old);
  }

  // ---------------------------------------------------------------- Bước

  void _addStep() {
    setState(() => _steps.add(_StepDraft(id: FaultIds.newChildId())));
    _markDirty();
  }

  Future<void> _removeStep(_StepDraft step) async {
    setState(() => _steps.remove(step));
    if (step.photo != null) await _discardPhoto(step.photo!);
    step.controller.dispose();
    _markDirty();
  }

  /// [newIndex] đã được Flutter điều chỉnh sau khi gỡ phần tử ở [oldIndex].
  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() => _steps.insert(newIndex, _steps.removeAt(oldIndex)));
    _markDirty();
  }

  // ----------------------------------------------------------------- Lưu

  String? get _faultGroupValue {
    if (_group == null) return null;
    if (_group == FaultGroups.other) {
      final custom = FaultGroups.normalize(_customGroup.text);
      return custom.isEmpty ? FaultGroups.other : custom;
    }
    return _group;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();
    final filledSteps = _steps
        .where((s) => s.controller.text.trim().isNotEmpty)
        .toList();
    if (!formOk || _machineModelId == null || filledSteps.isEmpty) {
      _showSnack('Vui lòng điền đủ các mục bắt buộc (*).');
      return;
    }
    // Bước để trống bị bỏ khi lưu — ảnh mới của bước đó cũng bỏ.
    for (final step in _steps.where((s) => !filledSteps.contains(s))) {
      if (step.photo != null) await _discardPhoto(step.photo!);
    }

    final draft = FaultRecordDraft(
      machineModelId: _machineModelId!,
      serialNumber: _serial.text,
      errorCode: _errorCode,
      faultGroup: _faultGroupValue,
      symptom: _symptom.text,
      cause: _cause.text,
      steps: [
        for (var i = 0; i < filledSteps.length; i++)
          SolutionStep(
            id: filledSteps[i].id,
            order: i + 1,
            content: filledSteps[i].controller.text.trim(),
            photo: filledSteps[i].photo,
          ),
      ],
      photos: List.of(_photos),
      parts: _parts.text,
      tools: _tools.text,
      durationMinutes: FaultDuration.parseHours(_duration.text),
      safetyWarning: _safety,
    );

    if (!mounted) return;
    setState(() => _saving = true);
    final provider = context.read<FaultBankProvider>();
    try {
      if (widget.isEditing) {
        await provider.updateRecord(_recordId, draft);
      } else {
        await provider.createRecord(draft, recordId: _recordId);
      }
      _newFiles.clear();
      _dirty = false;
      if (!mounted) return;
      if (widget.isEditing) {
        context.pop();
      } else {
        context.pushReplacement('/fault-bank/record/$_recordId');
      }
      _showSnack('Đã lưu bản ghi.');
    } catch (error) {
      if (mounted) setState(() => _saving = false);
      _showSnack('Không lưu được: $error');
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Nội dung vừa nhập sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục nhập'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ'),
          ),
        ],
      ),
    );
    if (discard != true) return false;
    final service = mounted
        ? context.read<FaultBankProvider>().photoService
        : null;
    for (final fileName in _newFiles) {
      await service?.storage.deletePhoto(fileName);
    }
    _newFiles.clear();
    return true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ Giao diện

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Sửa sự cố' : 'Ghi nhận sự cố'),
        ),
        bottomNavigationBar: _loading
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const Key('fault_form_save'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                  ),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(key: _formKey, child: _buildFields(context)),
      ),
    );
  }

  Widget _buildFields(BuildContext context) {
    final palette = DtcPalette.of(context);
    final provider = context.watch<FaultBankProvider>();
    final machine = provider.machineModelById(_machineModelId);
    final groupOptions = provider.groupOptions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _FormSection(
          title: 'Thông tin máy',
          children: [
            InkWell(
              key: const Key('fault_form_machine'),
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final id = await showMachineModelPicker(
                  context,
                  selectedId: _machineModelId,
                );
                if (id == null || id.isEmpty) return;
                setState(() => _machineModelId = id);
                _markDirty();
                unawaited(_refreshSimilar());
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Model máy *',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                  errorText: _submitted && machine == null
                      ? 'Chọn model máy'
                      : null,
                ),
                isEmpty: machine == null,
                child: machine == null ? null : Text(machine.name),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fault_form_tagname'),
              controller: _serial,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(labelText: 'Tagname'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('fault_form_group'),
              initialValue: groupOptions.contains(_group) ? _group : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nhóm lỗi'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('— Không chọn —'),
                ),
                for (final g in groupOptions)
                  DropdownMenuItem(
                    value: g,
                    child: Text(
                      g == FaultGroups.other ? 'KHÁC (nhập nhóm mới)' : g,
                    ),
                  ),
              ],
              onChanged: (value) {
                setState(() => _group = value);
                _markDirty();
              },
            ),
            if (_group == FaultGroups.other) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('fault_form_custom_group'),
                controller: _customGroup,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  labelText: 'Tên nhóm lỗi mới',
                  hintText: 'VD: BĂNG TẢI',
                ),
              ),
            ],
          ],
        ),
        _FormSection(
          title: 'Sự cố',
          children: [
            TextFormField(
              key: const Key('fault_form_symptom'),
              controller: _symptom,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onSymptomChanged,
              decoration: const InputDecoration(
                labelText: 'Mô tả lỗi *',
                hintText: 'Máy báo lỗi gì, hiện tượng quan sát được',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập mô tả lỗi' : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Hình ảnh mô tả',
              style: TextStyle(
                color: palette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  FaultPhotoThumb(
                    key: ValueKey(photo.id),
                    photo: photo,
                    onRemove: () async {
                      setState(() => _photos.remove(photo));
                      await _discardPhoto(photo);
                    },
                  ),
                InkWell(
                  key: const Key('fault_form_add_photo'),
                  onTap: _addRecordPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 120,
                    height: 88,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: palette.cyan),
                        const SizedBox(height: 4),
                        Text(
                          'Chèn hình ảnh mô tả',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_similar.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SimilarPanel(records: _similar),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fault_form_cause'),
              controller: _cause,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(
                labelText: 'Nguyên nhân *',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập nguyên nhân' : null,
            ),
          ],
        ),
        _FormSection(
          title: 'Cách xử lý *',
          subtitle: 'Nhập từng bước. Giữ biểu tượng ≡ để kéo đổi thứ tự.',
          children: [
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _steps.length,
              onReorderItem: _reorderSteps,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return _StepEditor(
                  key: ValueKey(step.id),
                  index: index,
                  step: step,
                  canRemove: _steps.length > 1,
                  onChanged: _markDirty,
                  onRemove: () => _removeStep(step),
                  onPickPhoto: () => _setStepPhoto(step),
                  onRemovePhoto: () async {
                    final photo = step.photo!;
                    setState(() => step.photo = null);
                    await _discardPhoto(photo);
                  },
                );
              },
            ),
            if (_submitted &&
                _steps.every((s) => s.controller.text.trim().isEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Cần ít nhất 1 bước xử lý',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('fault_form_add_step'),
                onPressed: _addStep,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm bước'),
              ),
            ),
          ],
        ),
        _FormSection(
          title: 'Vật tư & thời gian',
          children: [
            TextFormField(
              controller: _parts,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(
                labelText: 'Vật tư cần thay thế',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tools,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(labelText: 'Dụng cụ'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fault_form_duration'),
              controller: _duration,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                // Tối đa 3 chữ số phần nguyên, 2 chữ số lẻ: "1,5", "0.75".
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}([.,]\d{0,2})?'),
                ),
              ],
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(
                labelText: 'Thời gian xử lý',
                hintText: 'VD: 1,5',
                suffixText: 'giờ',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _StepEditor extends StatelessWidget {
  const _StepEditor({
    super.key,
    required this.index,
    required this.step,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final int index;
  final _StepDraft step;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: palette.navy,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.drag_handle_rounded, color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: Key('fault_form_step_$index'),
                  controller: step.controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(hintText: 'Bước ${index + 1}'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (step.photo != null)
                      FaultPhotoThumb(
                        key: ValueKey(step.photo!.id),
                        photo: step.photo!,
                        size: 64,
                        onRemove: onRemovePhoto,
                      )
                    else
                      TextButton.icon(
                        onPressed: onPickPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: const Text('Ảnh bước'),
                      ),
                    const Spacer(),
                    if (canRemove)
                      IconButton(
                        tooltip: 'Xóa bước',
                        onPressed: onRemove,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarPanel extends StatelessWidget {
  const _SimilarPanel({required this.records});

  final List<FaultRecordSummary> records;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      key: const Key('fault_form_similar'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đã có ${records.length} bản ghi tương tự trên máy — '
            'xem trước để tránh ghi trùng:',
            style: TextStyle(
              color: palette.navy,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FaultRecordCard(
                summary: r,
                dense: true,
                onTap: () => context.push('/fault-bank/record/${r.id}'),
              ),
            ),
        ],
      ),
    );
  }
}
