import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_material.dart';
import '../models/grinding_selection_request.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_format.dart';

/// Form "Chọn máy phù hợp" (mục 7) — nhập yêu cầu rồi đẩy sang
/// [GrindingMachineRecommendationScreen] để Selection Engine chấm điểm.
class GrindingMachineSelectionScreen extends StatefulWidget {
  const GrindingMachineSelectionScreen({super.key});

  @override
  State<GrindingMachineSelectionScreen> createState() =>
      _GrindingMachineSelectionScreenState();
}

class _GrindingMachineSelectionScreenState
    extends State<GrindingMachineSelectionScreen> {
  final _capacityController = TextEditingController();
  final _finenessController = TextEditingController();
  final _inputSizeController = TextEditingController();

  List<GrindingMaterial> _materials = const [];
  List<String> _allTags = const [];
  bool _isLoading = true;

  String? _materialId;
  String _capacityUnit = 'kg/h';
  String _finenessUnit = 'mesh';
  final Set<String> _selectedTags = {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GrindingMachineProvider>();
      final materials = await provider.getAllMaterials();
      final tags = await provider.getAllDistinctTags();
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _allTags = tags;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _finenessController.dispose();
    _inputSizeController.dispose();
    super.dispose();
  }

  void _submit() {
    final materialId = _materialId;
    final capacity = double.tryParse(
      _capacityController.text.replaceAll(',', '.'),
    );
    final fineness = double.tryParse(
      _finenessController.text.replaceAll(',', '.'),
    );
    final inputSize = double.tryParse(
      _inputSizeController.text.replaceAll(',', '.'),
    );

    if (materialId == null || capacity == null || fineness == null) {
      setState(
        () => _formError =
            'Vui lòng nhập đủ Nguyên liệu, Công suất và Độ mịn yêu cầu.',
      );
      return;
    }
    setState(() => _formError = null);

    final capacityKgH = _capacityUnit == 't/h' ? capacity * 1000 : capacity;
    final material = _materials.firstWhere((m) => m.materialId == materialId);

    final request = GrindingSelectionRequest(
      materialId: materialId,
      capacityKgH: capacityKgH,
      finenessValue: fineness,
      finenessUnit: _finenessUnit,
      inputSizeMm: inputSize,
      specialTags: Set.of(_selectedTags),
    );

    context.push(
      '/grinding_machine/recommendation',
      extra: {'request': request, 'materialName': material.nameVi},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Chọn máy phù hợp')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _FormSection(
                  title: 'Nguyên liệu',
                  child: DropdownButtonFormField<String>(
                    key: const Key('grinding_selection_material_field'),
                    initialValue: _materialId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _materials
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.materialId,
                            child: Text(m.nameVi),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _materialId = value),
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Công suất yêu cầu',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('grinding_selection_capacity_field'),
                          controller: _capacityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'kg/h', label: Text('kg/h')),
                          ButtonSegment(value: 't/h', label: Text('t/h')),
                        ],
                        selected: {_capacityUnit},
                        onSelectionChanged: (value) =>
                            setState(() => _capacityUnit = value.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Độ mịn yêu cầu',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('grinding_selection_fineness_field'),
                          controller: _finenessController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _finenessUnit,
                        items: const [
                          DropdownMenuItem(value: 'mesh', child: Text('mesh')),
                          DropdownMenuItem(value: 'µm', child: Text('µm')),
                          DropdownMenuItem(value: 'mm', child: Text('mm')),
                        ],
                        onChanged: (value) =>
                            setState(() => _finenessUnit = value!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Kích thước nguyên liệu đầu vào (không bắt buộc)',
                  child: TextField(
                    key: const Key('grinding_selection_input_size_field'),
                    controller: _inputSizeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: 'mm',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Yêu cầu đặc biệt (không bắt buộc)',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allTags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return FilterChip(
                        key: Key('grinding_selection_tag_$tag'),
                        label: Text(GrindingFormat.tagLabel(tag)),
                        selected: selected,
                        onSelected: (isSelected) => setState(() {
                          if (isSelected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('grinding_selection_submit_button'),
                  onPressed: _submit,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Tìm model phù hợp'),
                ),
              ],
            ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
