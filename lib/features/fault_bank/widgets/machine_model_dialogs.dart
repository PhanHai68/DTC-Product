import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/fault_machine_model.dart';
import '../providers/fault_bank_provider.dart';
import '../utils/vietnamese_fold.dart';

/// Thêm (hoặc sửa khi có [existing]) 1 dòng máy. Cảnh báo nếu đã có dòng
/// máy tên gần giống ("SC16Pro" ≈ "SC16 Pro") để tránh lệch tên giữa các
/// kỹ sư. Trả về dòng máy đã lưu, hoặc dòng máy có sẵn nếu người dùng chọn
/// dùng lại; null nếu hủy.
Future<FaultMachineModel?> showMachineModelEditor(
  BuildContext context, {
  FaultMachineModel? existing,
  String initialName = '',
}) {
  return showDialog<FaultMachineModel>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FaultBankProvider>(),
      child: _MachineModelEditor(existing: existing, initialName: initialName),
    ),
  );
}

class _MachineModelEditor extends StatefulWidget {
  const _MachineModelEditor({this.existing, required this.initialName});

  final FaultMachineModel? existing;
  final String initialName;

  @override
  State<_MachineModelEditor> createState() => _MachineModelEditorState();
}

class _MachineModelEditorState extends State<_MachineModelEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  FaultMachineModel? _similar;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FaultBankProvider>();
    final similar = await provider.findSimilarMachineModel(
      _name.text,
      excludeId: widget.existing?.id,
    );
    if (!mounted) return;
    // Lần bấm đầu: hiện cảnh báo trùng; bấm "Vẫn lưu" lần 2 thì lưu.
    if (similar != null && _similar?.id != similar.id) {
      setState(() => _similar = similar);
      return;
    }
    setState(() => _saving = true);
    try {
      final FaultMachineModel saved;
      if (widget.existing == null) {
        saved = await provider.addMachineModel(name: _name.text);
      } else {
        // Hãng / nhóm thiết bị không còn trên form — giữ giá trị cũ nếu có.
        saved = FaultMachineModel(
          id: widget.existing!.id,
          name: _name.text.trim(),
          manufacturer: widget.existing!.manufacturer,
          equipmentGroup: widget.existing!.equipmentGroup,
        );
        await provider.updateMachineModel(saved);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không lưu được: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final similar = _similar;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Thêm model máy' : 'Sửa model máy'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('fault_model_name_field'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tên model máy *',
                  hintText: 'VD: SC16 Pro',
                ),
                onChanged: (_) {
                  if (_similar != null) setState(() => _similar = null);
                },
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nhập tên model máy' : null,
              ),
              if (similar != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã có model máy "${similar.name}" gần giống.',
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nên dùng lại để tra cứu và gộp dữ liệu không bị '
                        'tách làm 2 model máy.',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                      if (widget.existing == null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('fault_model_use_existing'),
                            onPressed: () => Navigator.pop(context, similar),
                            child: const Text('Dùng model máy này'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('fault_model_save'),
          onPressed: _saving ? null : _save,
          child: Text(similar == null ? 'Lưu' : 'Vẫn lưu'),
        ),
      ],
    );
  }
}

/// Bảng chọn dòng máy (có ô tìm, bỏ dấu) + nút thêm mới ngay tại chỗ.
/// [allowAll] thêm lựa chọn "Tất cả dòng máy" (dùng cho bộ lọc); trả về ''
/// khi chọn mục này.
Future<String?> showMachineModelPicker(
  BuildContext context, {
  String? selectedId,
  bool allowAll = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FaultBankProvider>(),
      child: _MachineModelPicker(selectedId: selectedId, allowAll: allowAll),
    ),
  );
}

class _MachineModelPicker extends StatefulWidget {
  const _MachineModelPicker({this.selectedId, required this.allowAll});

  final String? selectedId;
  final bool allowAll;

  @override
  State<_MachineModelPicker> createState() => _MachineModelPickerState();
}

class _MachineModelPickerState extends State<_MachineModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final models = context.watch<FaultBankProvider>().machineModels;
    final query = VietnameseFold.fold(_query);
    final filtered = query.isEmpty
        ? models
        : models
              .where((m) => VietnameseFold.fold(m.name).contains(query))
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Chọn model máy',
                  style: TextStyle(
                    color: palette.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const Key('fault_model_picker_search'),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Tìm model máy',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.allowAll)
                      ListTile(
                        leading: const Icon(Icons.select_all_rounded),
                        title: const Text('Tất cả model máy'),
                        selected: widget.selectedId == null,
                        onTap: () => Navigator.pop(context, ''),
                      ),
                    for (final model in filtered)
                      ListTile(
                        key: Key('fault_model_option_${model.name}'),
                        leading: Icon(
                          Icons.label_outline_rounded,
                          color: palette.cyan,
                        ),
                        title: Text(model.name),
                        selected: model.id == widget.selectedId,
                        trailing: model.id == widget.selectedId
                            ? Icon(Icons.check_rounded, color: palette.cyan)
                            : null,
                        onTap: () => Navigator.pop(context, model.id),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          models.isEmpty
                              ? 'Chưa có model máy nào. Thêm model máy đầu tiên.'
                              : 'Không có model máy khớp "$_query".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.allowAll)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: OutlinedButton.icon(
                    key: const Key('fault_model_add_button'),
                    onPressed: () async {
                      final created = await showMachineModelEditor(
                        context,
                        initialName: _query.trim(),
                      );
                      if (created != null && context.mounted) {
                        Navigator.pop(context, created.id);
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm model máy mới'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
