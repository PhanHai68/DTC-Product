import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../../grinding_machine/models/grinding_machine_match.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';
import '../providers/equipment_catalog_provider.dart';
import '../services/equipment_selection_service.dart';

/// Công cụ "Chọn máy phù hợp" cho 1 catalog thiết bị — cùng cách làm việc
/// với bộ chọn máy nghiền: nhập yêu cầu, mỗi model được đối chiếu từng tiêu
/// chí (✓ đạt / ✗ không đạt / ? chưa có dữ liệu), không suy đoán khi
/// catalog thiếu số liệu. Form dựng từ danh sách tiêu chí trong catalog.
class EquipmentSelectorScreen extends StatefulWidget {
  const EquipmentSelectorScreen({super.key, required this.config});

  final EquipmentCatalogConfig config;

  @override
  State<EquipmentSelectorScreen> createState() =>
      _EquipmentSelectorScreenState();
}

class _EquipmentSelectorScreenState extends State<EquipmentSelectorScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, SelectorUnit> _units = {};
  final Map<String, String> _choices = {};
  List<EquipmentMatch>? _results;
  final Set<String> _shortlist = {};

  EquipmentCatalogConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<EquipmentCatalogProvider>().load(_config),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  static double? _parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  void _submit(LoadedEquipmentCatalog catalog) {
    FocusScope.of(context).unfocus();
    final requirements = <String, Object>{};
    for (final c in catalog.criteria) {
      if (c.isNumeric) {
        final value = _parse(_controllerFor(c.key).text);
        if (value == null) continue;
        final unit = _units[c.key] ?? (c.units.isEmpty ? null : c.units.first);
        requirements[c.key] = value * (unit?.factor ?? 1);
      } else if (_choices[c.key] case final option?) {
        requirements[c.key] = option;
      }
    }
    if (requirements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ít nhất 1 yêu cầu để chọn máy.')),
      );
      return;
    }
    setState(() {
      _shortlist.clear();
      _results = EquipmentSelectionService.evaluate(
        criteria: catalog.criteria,
        requirements: requirements,
        machines: catalog.machines,
        seriesByCode: catalog.seriesByCode,
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
    final catalog = context.watch<EquipmentCatalogProvider>().catalog(_config);
    final results = _results;
    final id = _config.id;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: Text('Chọn ${_config.productLabel} phù hợp')),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                for (final c in catalog.criteria) ...[
                  const SizedBox(height: 14),
                  if (c.isNumeric) _numericField(c) else _choiceGroup(c),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: Key('${id}_selector_submit_button'),
                  onPressed: () => _submit(catalog),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Tìm máy phù hợp'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                if (results != null) ...[
                  const SizedBox(height: 24),
                  _ResultsSection(
                    config: _config,
                    catalog: catalog,
                    results: results,
                    shortlist: _shortlist,
                    onToggleShortlist: _toggleShortlist,
                  ),
                ],
                if (_shortlist.length >= 2) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: Key('${id}_selector_compare_shortlist_button'),
                    onPressed: () => context.push(
                      '${_config.routeBase}/compare',
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

  Widget _numericField(SelectorCriterion c) {
    final id = _config.id;
    final field = TextField(
      key: Key('${id}_selector_${c.key}_field'),
      controller: _controllerFor(c.key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: c.inputLabel,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    if (c.units.length < 2) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: DropdownButtonFormField<SelectorUnit>(
            key: Key('${id}_selector_${c.key}_unit'),
            initialValue: _units[c.key] ?? c.units.first,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final u in c.units)
                DropdownMenuItem(value: u, child: Text(u.label)),
            ],
            onChanged: (u) {
              if (u != null) setState(() => _units[c.key] = u);
            },
          ),
        ),
      ],
    );
  }

  /// Nhóm chip chọn 1 giá trị (bấm lại để bỏ chọn).
  Widget _choiceGroup(SelectorCriterion c) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.inputLabel,
          style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in c.options)
              ChoiceChip(
                key: Key('${_config.id}_selector_${c.key}_${option.value}'),
                label: Text(option.label),
                selected: _choices[c.key] == option.value,
                onSelected: (on) => setState(() {
                  if (on) {
                    _choices[c.key] = option.value;
                  } else {
                    _choices.remove(c.key);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    required this.config,
    required this.catalog,
    required this.results,
    required this.shortlist,
    required this.onToggleShortlist,
  });

  final EquipmentCatalogConfig config;
  final LoadedEquipmentCatalog catalog;
  final List<EquipmentMatch> results;
  final Set<String> shortlist;
  final ValueChanged<String> onToggleShortlist;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final strong = results
        .where((r) => r.label == GrindingMatchLabel.strong)
        .toList();
    final hasExactMatch = strong.isNotEmpty;
    // Hiện mọi model khớp hoàn toàn (tối đa 10); không có thì 5 model gần
    // đúng nhất để kỹ sư thấy rõ tiêu chí còn thiếu.
    final shown = hasExactMatch
        ? [...strong.take(10), ...results.skip(strong.length).take(2)]
        : results.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasExactMatch
              ? 'Máy được đề xuất (${strong.length})'
              : 'Không tìm thấy máy khớp hoàn toàn',
          key: Key('${config.id}_selector_results_title'),
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
        ] else if (strong.length > 10) ...[
          const SizedBox(height: 4),
          Text(
            'Đang hiện 10 model đầu tiên — nhập thêm tiêu chí để thu hẹp.',
            style: TextStyle(color: palette.muted, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        for (final match in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MatchCard(
              config: config,
              imagePath: catalog.imageOf(match.machine),
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
    required this.config,
    required this.imagePath,
    required this.match,
    required this.isShortlisted,
    required this.onToggleShortlist,
  });

  final EquipmentCatalogConfig config;
  final String? imagePath;
  final EquipmentMatch match;
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
    final machineId = match.machine.machineId;
    return Container(
      key: Key('${config.id}_selector_match_$machineId'),
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
              if (imagePath case final path?) ...[
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
                    path,
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
                  key: Key('${config.id}_selector_detail_$machineId'),
                  onPressed: () =>
                      context.push('${config.routeBase}/detail/$machineId'),
                  child: const Text('Xem chi tiết'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('${config.id}_selector_shortlist_$machineId'),
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
