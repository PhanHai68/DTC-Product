import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../../grinding_machine/models/grinding_machine_match.dart';
import '../models/packing_catalog.dart';
import '../providers/packing_machine_provider.dart';
import '../services/packing_machine_selection_service.dart';

/// Công cụ "Chọn máy phù hợp" cho máy đóng gói — cùng cách làm việc với bộ
/// chọn máy nghiền: nhập yêu cầu, mỗi model được đối chiếu từng tiêu chí
/// (✓ đạt / ✗ không đạt / ? chưa có dữ liệu), không suy đoán khi catalog
/// thiếu số liệu.
class PackingMachineSelectorScreen extends StatefulWidget {
  const PackingMachineSelectorScreen({super.key});

  @override
  State<PackingMachineSelectorScreen> createState() =>
      _PackingMachineSelectorScreenState();
}

enum _WeightUnit { g, kg }

class _PackingMachineSelectorScreenState
    extends State<PackingMachineSelectorScreen> {
  final _weightController = TextEditingController();
  final _speedController = TextEditingController();
  final _powerController = TextEditingController();
  _WeightUnit _weightUnit = _WeightUnit.g;
  PackingMaterialForm? _form;
  PackingPackaging? _packaging;
  PackingAutomation? _automation;
  List<PackingMachineMatch>? _results;
  final Set<String> _shortlist = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PackingMachineProvider>().load(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _speedController.dispose();
    _powerController.dispose();
    super.dispose();
  }

  static double? _parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final weight = _parse(_weightController.text);
    final criteria = PackingSelectionCriteria(
      form: _form,
      packWeightG: weight == null
          ? null
          : (_weightUnit == _WeightUnit.kg ? weight * 1000 : weight),
      speedPerMin: _parse(_speedController.text),
      packaging: _packaging,
      automation: _automation,
      maxPowerKw: _parse(_powerController.text),
    );
    if (criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ít nhất 1 yêu cầu để chọn máy.')),
      );
      return;
    }
    final provider = context.read<PackingMachineProvider>();
    setState(() {
      _shortlist.clear();
      _results = PackingMachineSelectionService.evaluate(
        criteria: criteria,
        machines: provider.machines,
        seriesByCode: {for (final s in provider.series) s.seriesCode: s},
      );
    });
  }

  void _toggleShortlist(String machineId) {
    setState(() {
      if (!_shortlist.remove(machineId) && _shortlist.length < 3) {
        _shortlist.add(machineId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final results = _results;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Chọn máy đóng gói phù hợp')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
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
          _ChoiceGroup<PackingMaterialForm>(
            title: 'Dạng nguyên liệu',
            keyPrefix: 'packing_selector_form_',
            values: PackingMaterialForm.values,
            labelOf: (v) => v.label,
            selected: _form,
            onChanged: (v) => setState(() => _form = v),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('packing_selector_weight_field'),
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng mỗi gói / bao',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: DropdownButtonFormField<_WeightUnit>(
                  key: const Key('packing_selector_weight_unit'),
                  initialValue: _weightUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: _WeightUnit.g, child: Text('g')),
                    DropdownMenuItem(value: _WeightUnit.kg, child: Text('kg')),
                  ],
                  onChanged: (v) =>
                      setState(() => _weightUnit = v ?? _WeightUnit.g),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('packing_selector_speed_field'),
            controller: _speedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tốc độ cần đạt (túi / bao mỗi phút)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          _ChoiceGroup<PackingPackaging>(
            title: 'Loại bao bì',
            keyPrefix: 'packing_selector_packaging_',
            values: PackingPackaging.values,
            labelOf: (v) => v.label,
            selected: _packaging,
            onChanged: (v) => setState(() => _packaging = v),
          ),
          const SizedBox(height: 14),
          _ChoiceGroup<PackingAutomation>(
            title: 'Mức tự động',
            keyPrefix: 'packing_selector_automation_',
            values: PackingAutomation.values,
            labelOf: (v) => v.label,
            selected: _automation,
            onChanged: (v) => setState(() => _automation = v),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('packing_selector_power_field'),
            controller: _powerController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Công suất điện tối đa (kW)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('packing_selector_submit_button'),
            onPressed: _submit,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Tìm máy phù hợp'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
          if (results != null) ...[
            const SizedBox(height: 24),
            _ResultsSection(
              results: results,
              shortlist: _shortlist,
              onToggleShortlist: _toggleShortlist,
            ),
          ],
          if (_shortlist.length >= 2) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('packing_selector_compare_shortlist_button'),
              onPressed: () => context.push(
                '/packing_machine/compare',
                extra: _shortlist.toList(),
              ),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text('So sánh ${_shortlist.length} model đã chọn'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nhóm chip chọn 1 giá trị (bấm lại để bỏ chọn).
class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.keyPrefix,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String keyPrefix;
  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final value in values)
              ChoiceChip(
                key: Key('$keyPrefix${(value as Enum).name}'),
                label: Text(labelOf(value)),
                selected: value == selected,
                onSelected: (on) => onChanged(on ? value : null),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.results,
    required this.shortlist,
    required this.onToggleShortlist,
  });

  final List<PackingMachineMatch> results;
  final Set<String> shortlist;
  final ValueChanged<String> onToggleShortlist;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final strong = results
        .where((r) => r.label == GrindingMatchLabel.strong)
        .toList();
    final hasExactMatch = strong.isNotEmpty;
    // Hiện mọi model khớp hoàn toàn (thường ít); không có thì 5 model gần
    // đúng nhất để kỹ sư thấy rõ tiêu chí còn thiếu.
    final shown = hasExactMatch
        ? [...strong, ...results.skip(strong.length).take(2)]
        : results.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasExactMatch
              ? 'Máy được đề xuất (${strong.length})'
              : 'Không tìm thấy máy khớp hoàn toàn',
          key: const Key('packing_selector_results_title'),
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
        for (final match in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MatchCard(
              match: match,
              isShortlisted: shortlist.contains(match.machine.machineId),
              onToggleShortlist: () =>
                  onToggleShortlist(match.machine.machineId),
            ),
          ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isShortlisted,
    required this.onToggleShortlist,
  });

  final PackingMachineMatch match;
  final bool isShortlisted;
  final VoidCallback onToggleShortlist;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final (labelText, labelColor) = switch (match.label) {
      GrindingMatchLabel.strong => ('Phù hợp cao', palette.cyan),
      GrindingMatchLabel.possible => ('Có thể phù hợp', palette.navy),
      GrindingMatchLabel.closest => ('Chưa đáp ứng đủ', errorColor),
    };
    final imagePath = context.read<PackingMachineProvider>().imageOf(
      match.machine,
    );
    return Container(
      key: Key('packing_selector_match_${match.machine.machineId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isShortlisted ? palette.cyan : palette.border,
          width: isShortlisted ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (imagePath != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    cacheWidth: 144,
                  ),
                ),
                const SizedBox(width: 10),
              ],
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
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${criterion.label}: '
                                '${criterion.actualDisplay ?? 'Chưa có dữ liệu'}'
                                ' (yêu cầu ${criterion.requiredDisplay})',
                          ),
                          if (criterion.status != GrindingCriterionStatus.match)
                            TextSpan(
                              text: '\n${criterion.reason}',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
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
                    'packing_selector_detail_${match.machine.machineId}',
                  ),
                  onPressed: () => context.push(
                    '/packing_machine/detail/${match.machine.machineId}',
                  ),
                  child: const Text('Xem chi tiết'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key(
                    'packing_selector_shortlist_${match.machine.machineId}',
                  ),
                  onPressed: onToggleShortlist,
                  icon: Icon(
                    isShortlisted
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                  ),
                  label: const Text('So sánh'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
