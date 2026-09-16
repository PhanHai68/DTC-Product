// Màn hình Chọn Máy theo Yêu Cầu (Machine Selector).
// Người dùng nhập tiêu chí → App tìm và rank máy phù hợp.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/packing_machine.dart';
import '../../core/input/localized_number.dart';
import '../../models/machine_match_result.dart';
import '../../providers/machine_selector_provider.dart';
import '../../routes/route_locations.dart';
import '../../widgets/packing/match_badge.dart';
import '../../widgets/packing/packing_back_button.dart';

class MachineSelectorScreen extends StatefulWidget {
  const MachineSelectorScreen({super.key});

  @override
  State<MachineSelectorScreen> createState() => _MachineSelectorScreenState();
}

class _MachineSelectorScreenState extends State<MachineSelectorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MachineSelectorProvider>().loadOptions();
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _onFind() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<MachineSelectorProvider>().findMachines();
  }

  void _onReset() {
    _weightController.clear();
    _capacityController.clear();
    context.read<MachineSelectorProvider>().resetForm();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'Chọn Máy Theo Yêu Cầu',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leadingWidth: 64,
        leading: PackingBackButton(
          foregroundColor: colorScheme.primary,
          tooltip: 'Về Cân đóng gói',
        ),
        actions: [TextButton(onPressed: _onReset, child: const Text('Xóa'))],
      ),
      body: Consumer<MachineSelectorProvider>(
        builder: (context, provider, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  children: [
                    // ── Form nhập liệu ────────────────────────────────────────
                    _SectionCard(
                      title: 'TIÊU CHÍ TÌM MÁY',
                      child: Column(
                        children: [
                          // Loại bao (PE / PP)
                          _DropdownField(
                            id: 'bag_material_dropdown',
                            label: 'Loại bao',
                            hint: 'Chọn loại bao...',
                            value: provider.selectedBagMaterial,
                            items: provider.bagMaterials,
                            onChanged: provider.setBagMaterial,
                            icon: Icons.inventory_2_outlined,
                          ),
                          const SizedBox(height: 12),

                          // Kiểu túi (2 cạnh / 6 cạnh / 2&6 cạnh)
                          _DropdownField(
                            id: 'bag_edges_dropdown',
                            label: 'Kiểu túi',
                            hint: 'Chọn kiểu túi...',
                            value: provider.selectedBagEdges,
                            items: provider.bagEdges,
                            onChanged: provider.setBagEdges,
                            icon: Icons.layers_outlined,
                            isRequired: false,
                            allLabel: 'Không yêu cầu kiểu túi',
                            helperText: provider.selectedBagMaterial == 'PP'
                                ? 'Dữ liệu Excel chưa khai báo kiểu túi cho máy PP; '
                                      'nếu chọn thêm tiêu chí này, ứng dụng sẽ báo rõ '
                                      'các model không phù hợp.'
                                : 'Có thể chọn độc lập: 2 cạnh, 6 cạnh hoặc 2 & 6 cạnh.',
                          ),
                          const SizedBox(height: 12),

                          // Mức độ tự động hóa
                          _DropdownField(
                            id: 'automation_dropdown',
                            label: 'Mức tự động hóa',
                            hint: 'Tất cả',
                            value: provider.selectedAutomationLevel,
                            items: provider.automationLevels,
                            onChanged: provider.setAutomationLevel,
                            icon: Icons.settings_outlined,
                            isRequired: false,
                          ),
                          const SizedBox(height: 12),

                          // Khối lượng mỗi túi
                          _NumberField(
                            id: 'weight_input',
                            controller: _weightController,
                            label: 'Khối lượng mỗi túi (kg)',
                            hint: 'Vd: 5',
                            icon: Icons.scale_outlined,
                            suffix: 'kg',
                            onChanged: (v) => provider.setWeightKg(v),
                          ),
                          const SizedBox(height: 12),

                          // Năng suất yêu cầu
                          _NumberField(
                            id: 'capacity_input',
                            controller: _capacityController,
                            label: 'Năng suất yêu cầu',
                            hint: 'Vd: 500',
                            icon: Icons.speed_outlined,
                            suffix: provider.selectedCapacityUnit ?? 'túi/giờ',
                            onChanged: (v) => provider.setCapacity(v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Nút tìm máy ───────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('find_machine_btn'),
                        onPressed: provider.isSearching ? null : _onFind,
                        icon: provider.isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          provider.isSearching ? 'Đang tìm...' : 'TÌM MÁY',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    // ── Kết quả tìm kiếm ─────────────────────────────────────
                    if (provider.hasSearched) ...[
                      const SizedBox(height: 24),
                      _SearchResults(provider: provider),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget hiển thị kết quả tìm kiếm
class _SearchResults extends StatelessWidget {
  final MachineSelectorProvider provider;

  const _SearchResults({required this.provider});

  @override
  Widget build(BuildContext context) {
    final suitable = provider.suitableResults;
    final notSuitable = provider.notSuitableResults;

    if (suitable.isEmpty && notSuitable.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Không tìm thấy máy phù hợp.\nVui lòng thay đổi tiêu chí tìm kiếm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header kết quả
        Row(
          children: [
            Text(
              'KẾT QUẢ TÌM KIẾM',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${suitable.length} phù hợp',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Suitable results
        ...suitable.map((result) => _ResultCard(result: result)),

        // Not suitable section (collapsible)
        if (notSuitable.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NotSuitableSection(results: notSuitable),
        ],
      ],
    );
  }
}

/// Card hiển thị một kết quả match
class _ResultCard extends StatelessWidget {
  final MachineMatchResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final machine = result.machine as PackingMachine;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: result.matchLevel == MatchLevel.bestMatch ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: result.matchLevel == MatchLevel.bestMatch
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => context.push(packingDetailLocation(machine.model)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          machine.model,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (machine.productGroup != null)
                          Text(
                            machine.productGroup!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  MatchBadge(
                    level: result.matchLevel,
                    compact: false,
                    showStars: false,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Key specs
              Wrap(
                spacing: 8,
                children: [
                  _SpecTag(machine.weightRangeText, Icons.scale_outlined),
                  _SpecTag(machine.capacityRangeText, Icons.speed_outlined),
                ],
              ),
              const SizedBox(height: 10),

              // Match reasons
              MatchReasonsList(
                matchReasons: result.matchReasons,
                mismatchReasons: result.mismatchReasons,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SpecTag(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Section collapsible cho NOT SUITABLE results
class _NotSuitableSection extends StatefulWidget {
  final List<MachineMatchResult> results;

  const _NotSuitableSection({required this.results});

  @override
  State<_NotSuitableSection> createState() => _NotSuitableSectionState();
}

class _NotSuitableSectionState extends State<_NotSuitableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '${widget.results.length} model không phù hợp',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.results.take(5).map((r) => _ResultCard(result: r)),
      ],
    );
  }
}

// ─── Reusable Form Widgets ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String id;
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final bool isRequired;
  final String allLabel;
  final String? helperText;

  const _DropdownField({
    required this.id,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.isRequired = true,
    this.allLabel = 'Tất cả',
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      key: Key(id),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label + (isRequired ? '' : ' (tùy chọn)'),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        helperText: helperText,
        helperMaxLines: 2,
      ),
      hint: Text(hint),
      items: [
        if (!isRequired)
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              allLabel,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ...items.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
      validator: isRequired
          ? (v) => v == null ? 'Vui lòng chọn $label' : null
          : null,
    );
  }
}

class _NumberField extends StatelessWidget {
  final String id;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String suffix;
  final ValueChanged<double?> onChanged;

  const _NumberField({
    required this.id,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: Key(id),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [LocalizedDecimalTextInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      onChanged: (text) {
        final value = parseLocalizedDouble(text);
        onChanged(value);
      },
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (parseLocalizedDouble(value) == null) {
            return 'Vui lòng nhập số hợp lệ';
          }
          if (parseLocalizedDouble(value)! <= 0) {
            return 'Giá trị phải lớn hơn 0';
          }
        }
        return null;
      },
    );
  }
}
