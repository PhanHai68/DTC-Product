// Màn hình chọn và so sánh 2-3 model máy cân đóng gói.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/packing_machine.dart';
import '../../providers/compare_provider.dart';
import '../../providers/packing_provider.dart';
import '../../routes/route_locations.dart';
import '../../widgets/packing/machine_card.dart';
import '../../widgets/packing/packing_back_button.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showResult = false;
  String _query = '';
  String? _selectedGroup; // Lọc theo nhóm sản phẩm

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PackingProvider>();
      if (provider.machines.isEmpty) provider.loadAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAll(CompareProvider provider) {
    provider.clearAll();
    setState(() => _showResult = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer2<PackingProvider, CompareProvider>(
      builder: (context, packingProvider, compareProvider, _) {
        final showingResult = _showResult && compareProvider.canCompare;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leadingWidth: 64,
            leading: PackingBackButton(
              foregroundColor: colorScheme.primary,
              tooltip: 'Về Cân đóng gói',
            ),
            title: Text(
              showingResult ? 'Kết quả so sánh' : 'Chọn model để so sánh',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              if (compareProvider.count > 0)
                TextButton.icon(
                  onPressed: () => _clearAll(compareProvider),
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  label: const Text('Xóa tất cả'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: showingResult
              ? _CompareResult(
                  provider: compareProvider,
                  onEdit: () => setState(() => _showResult = false),
                )
              : _ModelPicker(
                  packingProvider: packingProvider,
                  compareProvider: compareProvider,
                  query: _query,
                  searchController: _searchController,
                  onQueryChanged: (value) => setState(() => _query = value),
                  selectedGroup: _selectedGroup,
                  onGroupChanged: (g) => setState(() => _selectedGroup = g),
                ),
          bottomNavigationBar: showingResult
              ? null
              : _ConfirmBar(
                  provider: compareProvider,
                  onConfirm: () => setState(() => _showResult = true),
                ),
        );
      },
    );
  }
}

class _ModelPicker extends StatelessWidget {
  final PackingProvider packingProvider;
  final CompareProvider compareProvider;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupChanged;

  const _ModelPicker({
    required this.packingProvider,
    required this.compareProvider,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.selectedGroup,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (packingProvider.isLoading && packingProvider.machines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (packingProvider.hasError && packingProvider.machines.isEmpty) {
      return _LoadError(
        message: packingProvider.errorMessage ?? 'Không thể tải dữ liệu',
        onRetry: packingProvider.loadAll,
      );
    }

    final normalizedQuery = query.trim().toLowerCase();
    // Lấy danh sách nhóm duy nhất để hiện dropdown
    final allGroups =
        packingProvider.machines
            .map((m) => m.productGroup)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

    var machines = packingProvider.machines.where((machine) {
      // Lọc theo nhóm đã chọn
      if (selectedGroup != null && machine.productGroup != selectedGroup) {
        return false;
      }
      // Lọc theo query text
      if (normalizedQuery.isNotEmpty) {
        return [
          machine.model,
          machine.productGroup,
          machine.machineLine,
          machine.bagMaterial,
        ].whereType<String>().any(
          (value) => value.toLowerCase().contains(normalizedQuery),
        );
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1180,
              minHeight: viewportConstraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelectionHeader(provider: compareProvider),
                  const SizedBox(height: 14),
                  // Dropdown lọc theo nhóm máy
                  if (allGroups.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCE5EA)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          key: const Key('compare_group_filter'),
                          value: selectedGroup,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          hint: const Row(
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 18,
                                color: Color(0xFF607786),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tất cả nhóm máy',
                                style: TextStyle(color: Color(0xFF607786)),
                              ),
                            ],
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tất cả nhóm máy'),
                            ),
                            ...allGroups.map(
                              (g) => DropdownMenuItem<String?>(
                                value: g,
                                child: Text(g, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: onGroupChanged,
                          selectedItemBuilder: selectedGroup == null
                              ? null
                              : (ctx) => [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.filter_list_rounded,
                                        size: 16,
                                        color: Color(0xFF3158A5),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          selectedGroup!,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF3158A5),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...allGroups.map(
                                    (g) => Text(
                                      g,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  // Thanh tìm kiếm
                  TextField(
                    key: const Key('compare_search_input'),
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo model, nhóm máy hoặc loại bao...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa từ khóa',
                              onPressed: () {
                                searchController.clear();
                                onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCE5EA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDCE5EA)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${machines.length} model',
                        style: const TextStyle(
                          color: Color(0xFF607786),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (compareProvider.isFull)
                        const Text(
                          'Đã chọn tối đa 3 model',
                          style: TextStyle(
                            color: Color(0xFF087F6A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: machines.isEmpty
                        ? const _NoSearchResult()
                        : GridView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 570,
                                  mainAxisExtent:
                                      viewportConstraints.maxWidth < 600
                                      ? 195
                                      : 170,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: machines.length,
                            itemBuilder: (context, index) {
                              final machine = machines[index];
                              final selected = compareProvider.isSelected(
                                machine.model,
                              );
                              final selectedIndex = compareProvider
                                  .selectedMachines
                                  .indexWhere(
                                    (item) => item.model == machine.model,
                                  );
                              return _SelectableMachineCard(
                                machine: machine,
                                selected: selected,
                                selectedOrder: selectedIndex < 0
                                    ? null
                                    : selectedIndex + 1,
                                selectionLimitReached:
                                    compareProvider.isFull && !selected,
                                onToggle: () =>
                                    _toggle(context, compareProvider, machine),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggle(
    BuildContext context,
    CompareProvider provider,
    PackingMachine machine,
  ) {
    if (provider.isSelected(machine.model)) {
      provider.removeMachine(machine.model);
      return;
    }
    if (provider.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ có thể chọn tối đa 3 model.')),
      );
      return;
    }
    provider.addMachineObject(machine);
  }
}

class _SelectionHeader extends StatelessWidget {
  final CompareProvider provider;

  const _SelectionHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn từ 2 đến 3 model',
                      style: TextStyle(
                        color: Color(0xFF173249),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Đánh dấu model, sau đó nhấn “Xác nhận so sánh”.',
                      style: TextStyle(color: Color(0xFF607786)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FBF8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${provider.count}/3',
                  style: const TextStyle(
                    color: Color(0xFF087F6A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (provider.selectedMachines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.selectedMachines.asMap().entries.map((entry) {
                return InputChip(
                  avatar: CircleAvatar(child: Text('${entry.key + 1}')),
                  label: Text(entry.value.model),
                  onDeleted: () => provider.removeMachine(entry.value.model),
                  deleteButtonTooltipMessage: 'Bỏ ${entry.value.model}',
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectableMachineCard extends StatelessWidget {
  final PackingMachine machine;
  final bool selected;
  final int? selectedOrder;
  final bool selectionLimitReached;
  final VoidCallback onToggle;

  const _SelectableMachineCard({
    required this.machine,
    required this.selected,
    required this.selectedOrder,
    required this.selectionLimitReached,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: selectionLimitReached ? 0.58 : 1,
      child: Material(
        color: selected ? const Color(0xFFF0FBF8) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? const Color(0xFF087F6A) : const Color(0xFFDCE5EA),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('select_${machine.model}'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MachineImage(
                    imagePath: machine.imageMainPath,
                    width: 104,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              machine.model,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF173249),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (selectedOrder != null)
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF087F6A),
                              foregroundColor: Colors.white,
                              child: Text(
                                '$selectedOrder',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        machine.productGroup ??
                            machine.machineLine ??
                            'Máy cân đóng gói',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF607786)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (machine.bagMaterial != null)
                            _MiniSpec(machine.bagMaterial!),
                          _MiniSpec(machine.weightRangeText),
                          _MiniSpec(machine.capacityRangeText),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: selected
                                ? OutlinedButton.icon(
                                    key: ValueKey(
                                      'choose_model_${machine.model}',
                                    ),
                                    onPressed: onToggle,
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Bỏ chọn'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF087F6A),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(
                                        color: Color(0xFF087F6A),
                                      ),
                                    ),
                                  )
                                : FilledButton.tonalIcon(
                                    key: ValueKey(
                                      'choose_model_${machine.model}',
                                    ),
                                    onPressed: onToggle,
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Chọn model'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Xem chi tiết',
                            onPressed: () => context.push(
                              packingDetailLocation(machine.model),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSpec extends StatelessWidget {
  final String label;

  const _MiniSpec(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Color(0xFF456071)),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final CompareProvider provider;
  final VoidCallback onConfirm;

  const _ConfirmBar({required this.provider, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final status = Text(
                    provider.canCompare
                        ? 'Đã sẵn sàng: ${provider.count} model'
                        : 'Chọn thêm ${CompareProvider.minModels - provider.count} model',
                    style: TextStyle(
                      color: provider.canCompare
                          ? const Color(0xFF087F6A)
                          : const Color(0xFF607786),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final button = FilledButton.icon(
                    key: const Key('confirm_compare_button'),
                    onPressed: provider.canCompare ? onConfirm : null,
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: Text('Xác nhận so sánh (${provider.count})'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(compact ? double.infinity : 250, 48),
                      backgroundColor: const Color(0xFF087F6A),
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [status, const SizedBox(height: 9), button],
                    );
                  }
                  return Row(children: [status, const Spacer(), button]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareResult extends StatelessWidget {
  final CompareProvider provider;
  final VoidCallback onEdit;

  const _CompareResult({required this.provider, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final machines = provider.selectedMachines;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF12324A), Color(0xFF176B87)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                        'Đang so sánh ${machines.length} model',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('edit_compare_selection_button'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Chọn lại'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 14) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: machines.map((machine) {
                        return SizedBox(
                          width: cardWidth,
                          child: _ResultMachineCard(machine: machine),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: Color(0xFF176B87)),
                    SizedBox(width: 8),
                    Text(
                      'BẢNG SO SÁNH',
                      style: TextStyle(
                        color: Color(0xFF173249),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Spacer(),
                    _DifferenceLegend(),
                  ],
                ),
                const SizedBox(height: 10),
                _CompareTable(machines: machines),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMachineCard extends StatelessWidget {
  final PackingMachine machine;

  const _ResultMachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFDCE5EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(packingDetailLocation(machine.model)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: MachineImage(
                  imagePath: machine.imageMainPath,
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      machine.productGroup ?? 'Máy cân đóng gói',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF607786)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifferenceLegend extends StatelessWidget {
  const _DifferenceLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF176B87).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Thông số khác nhau',
          style: TextStyle(fontSize: 12, color: Color(0xFF607786)),
        ),
      ],
    );
  }
}

class _CompareTable extends StatelessWidget {
  final List<PackingMachine> machines;

  const _CompareTable({required this.machines});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = [
      _CompareRow(
        label: 'Hình ảnh',
        icon: Icons.image_outlined,
        values: machines.map((m) => m.imageMainPath ?? '').toList(),
        isImage: true,
      ),
      _CompareRow(
        label: 'Nhóm máy',
        icon: Icons.category_outlined,
        values: machines.map((m) => m.productGroup ?? 'N/A').toList(),
      ),
      _CompareRow(
        label: 'Mức tự động',
        icon: Icons.settings_outlined,
        values: machines.map((m) => m.automationLevel ?? 'N/A').toList(),
      ),
      _CompareRow(
        label: 'Loại bao',
        icon: Icons.inventory_2_outlined,
        values: machines.map((m) => m.bagMaterial ?? 'N/A').toList(),
      ),
      _CompareRow(
        label: 'Kiểu túi',
        icon: Icons.layers_outlined,
        values: machines.map((m) => m.bagEdges ?? 'N/A').toList(),
      ),
      _CompareRow(
        label: 'Trọng lượng',
        icon: Icons.scale_outlined,
        values: machines.map((m) => m.weightRangeText).toList(),
      ),
      _CompareRow(
        label: 'Năng suất',
        icon: Icons.speed_outlined,
        values: machines.map((m) => m.capacityRangeText).toList(),
      ),
      _CompareRow(
        label: 'Số đầu cân',
        icon: Icons.hub_outlined,
        values: machines.map((m) => m.headsStations ?? 'N/A').toList(),
      ),
      _CompareRow(
        label: 'Nguồn điện',
        icon: Icons.electrical_services_outlined,
        values: machines.map((m) => m.powerText).toList(),
      ),
      _CompareRow(
        label: 'Công suất',
        icon: Icons.bolt_outlined,
        values: machines
            .map((m) => m.powerKw != null ? '${m.powerKw} kW' : 'N/A')
            .toList(),
      ),
      _CompareRow(
        label: 'Khí nén',
        icon: Icons.compress_outlined,
        values: machines.map((m) => m.airPressureText).toList(),
      ),
      _CompareRow(
        label: 'Kích thước',
        icon: Icons.straighten_outlined,
        values: machines.map((m) => m.dimensionText).toList(),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 22,
                headingRowHeight: 58,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 102,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF1F5F7),
                ),
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xFFE5ECEF)),
                ),
                columns: [
                  const DataColumn(
                    label: SizedBox(
                      width: 120,
                      child: Text(
                        'Thông số',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  ...machines.map(
                    (machine) => DataColumn(
                      label: SizedBox(
                        width: 155,
                        child: Text(
                          machine.model,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF176B87),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                rows: rows.map((row) {
                  final differs = row.values.toSet().length > 1;
                  return DataRow(
                    color: differs
                        ? WidgetStateProperty.all(
                            const Color(0xFF176B87).withValues(alpha: 0.08),
                          )
                        : null,
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              row.icon,
                              size: 17,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 7),
                            SizedBox(
                              width: 96,
                              child: Text(
                                row.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...row.values.map(
                        (value) => DataCell(
                          SizedBox(
                            width: 155,
                            child: row.isImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: MachineImage(
                                      imagePath: value.isEmpty ? null : value,
                                      width: 90,
                                      height: 70,
                                    ),
                                  )
                                : Text(
                                    value,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompareRow {
  final String label;
  final IconData icon;
  final List<String> values;
  final bool isImage;

  const _CompareRow({
    required this.label,
    required this.icon,
    required this.values,
    this.isImage = false,
  });
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: Color(0xFF8AA0AC)),
          SizedBox(height: 10),
          Text('Không tìm thấy model phù hợp với từ khóa.'),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
