// Màn hình Danh mục sản phẩm.
// Duyệt theo nhóm → dòng máy → model.
// Dữ liệu được tạo động từ database, không hard-code.
// Tích hợp tìm kiếm realtime theo tên model.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/packing_machine.dart';
import '../../repositories/packing_machine_repository.dart';
import '../../routes/route_locations.dart';
import '../../theme/dtc_palette.dart';
import '../../widgets/packing/machine_card.dart';
import '../../widgets/packing/packing_back_button.dart';

class MachineCatalogScreen extends StatefulWidget {
  final PackingMachineRepository? repository;

  const MachineCatalogScreen({super.key, this.repository});

  @override
  State<MachineCatalogScreen> createState() => _MachineCatalogScreenState();
}

class _MachineCatalogScreenState extends State<MachineCatalogScreen> {
  late final PackingMachineRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Dữ liệu: productGroup → (machineLine → List<machines>)
  Map<String, Map<String, List<PackingMachine>>> _catalog = {};
  List<PackingMachine> _allMachines = [];
  List<PackingMachine> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PackingMachineRepository();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final groups = await _repository.getDistinctProductGroups();
      final catalog = <String, Map<String, List<PackingMachine>>>{};
      final all = <PackingMachine>[];

      for (final group in groups) {
        final machines = await _repository.getMachinesByGroup(group);
        final byLine = <String, List<PackingMachine>>{};

        for (final machine in machines) {
          final line = machine.machineLine ?? 'Khác';
          byLine.putIfAbsent(line, () => []).add(machine);
          all.add(machine);
        }

        catalog[group] = byLine;
      }

      if (mounted) {
        setState(() {
          _catalog = catalog;
          _allMachines = all;
          _searchResults = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Không thể tải danh mục cân đóng gói: $e');
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh mục sản phẩm trên thiết bị này.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = query.trim().toLowerCase();
      setState(() {
        _searchQuery = query.trim();
        if (q.isEmpty) {
          _isSearching = false;
          _searchResults = _allMachines;
        } else {
          _isSearching = true;
          _searchResults = _allMachines.where((m) {
            return [
              m.model,
              m.productGroup,
              m.machineLine,
              m.bagMaterial,
              m.materials,
            ].whereType<String>().any((v) => v.toLowerCase().contains(q));
          }).toList();
        }
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _searchResults = _allMachines;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: CustomScrollView(
        slivers: [
          // App bar đồng bộ theo theme chung của app
          SliverAppBar(
            expandedHeight: 116,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: palette.surface,
            foregroundColor: palette.navy,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            leadingWidth: 64,
            leading: const PackingBackButton(tooltip: 'Về Cân đóng gói'),
            title: Text(
              'Danh mục sản phẩm',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _CatalogHeader(totalCount: _allMachines.length),
            ),
          ),

          // Thanh tìm kiếm cố định
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarDelegate(
              searchController: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
              query: _searchQuery,
            ),
          ),

          // Nội dung
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _CatalogLoadError(message: _error!, onRetry: _loadCatalog),
            )
          else if (_isSearching)
            _buildSearchResults()
          else
            _buildGroupedCatalog(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Không tìm thấy model "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '${_searchResults.length} kết quả',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
        final machine = _searchResults[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MachineCard(
            machine: machine,
            onTap: () => context.push(packingDetailLocation(machine.model)),
          ),
        );
      }, childCount: _searchResults.length + 1),
    );
  }

  Widget _buildGroupedCatalog() {
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              children: _catalog.entries.map((groupEntry) {
                return _GroupSection(
                  groupName: groupEntry.key,
                  lineMap: groupEntry.value,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header trong SliverAppBar — đồng bộ với phong cách "Trung tâm chức năng"
/// dùng ở các màn hình menu khác (thanh nhấn teal + phụ đề navy).
/// Tiêu đề chính "Danh mục sản phẩm" đã nằm ở AppBar phía trên, ở đây chỉ
/// hiển thị số lượng model và hướng dẫn để tránh lặp lại.
class _CatalogHeader extends StatelessWidget {
  final int totalCount;
  const _CatalogHeader({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      color: palette.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: palette.cyan,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: totalCount > 0
                    ? Text(
                        '$totalCount model · Chọn dòng máy để xem chi tiết',
                        style: TextStyle(
                          color: palette.navy,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent header cho thanh tìm kiếm
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String query;

  const _SearchBarDelegate({
    required this.searchController,
    required this.onChanged,
    required this.onClear,
    required this.query,
  });

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) =>
      oldDelegate.query != query;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = DtcPalette.of(context);
    return Container(
      color: palette.canvas,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: palette.surface,
        elevation: overlapsContent ? 2 : 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        child: TextField(
          key: const Key('catalog_search_field'),
          controller: searchController,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Tìm theo model, nhóm máy, loại vật liệu...',
            hintStyle: TextStyle(fontSize: 14, color: palette.muted),
            prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    tooltip: 'Xóa từ khóa',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClear,
                    color: palette.muted,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _CatalogLoadError extends StatelessWidget {
  const _CatalogLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
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

/// Section cho một nhóm sản phẩm (ví dụ: Túi PE hút chân không)
class _GroupSection extends StatefulWidget {
  final String groupName;
  final Map<String, List<PackingMachine>> lineMap;

  const _GroupSection({required this.groupName, required this.lineMap});

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCount = widget.lineMap.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Group header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _groupHeaderColor(context, widget.groupName),
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _groupForegroundColor(widget.groupName)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _groupIcon(widget.groupName),
                      color: _groupForegroundColor(widget.groupName),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _groupForegroundColor(widget.groupName),
                          ),
                        ),
                        Text(
                          '$totalCount model · ${widget.lineMap.length} dòng máy',
                          style: TextStyle(
                            fontSize: 12,
                            color: _groupForegroundColor(widget.groupName)
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: _groupForegroundColor(widget.groupName),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Line sections
          if (_expanded)
            ...widget.lineMap.entries.map((lineEntry) {
              return _LineSection(
                lineName: lineEntry.key,
                machines: lineEntry.value,
              );
            }),
        ],
      ),
    );
  }

  Color _groupHeaderColor(BuildContext context, String group) {
    if (group.contains('PE')) return Colors.blue.shade50;
    if (group.contains('PP') || group.contains('Bao')) {
      return Colors.green.shade50;
    }
    return Colors.orange.shade50;
  }

  Color _groupForegroundColor(String group) {
    if (group.contains('PE')) return Colors.blue.shade800;
    if (group.contains('PP') || group.contains('Bao')) {
      return Colors.green.shade800;
    }
    return Colors.orange.shade800;
  }

  IconData _groupIcon(String group) {
    if (group.contains('PE')) return Icons.shopping_bag_outlined;
    if (group.contains('PP') || group.contains('Bao')) {
      return Icons.inventory_outlined;
    }
    return Icons.monitor_weight_outlined;
  }
}

/// Section cho một dòng máy
class _LineSection extends StatefulWidget {
  final String lineName;
  final List<PackingMachine> machines;

  const _LineSection({required this.lineName, required this.machines});

  @override
  State<_LineSection> createState() => _LineSectionState();
}

class _LineSectionState extends State<_LineSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: EdgeInsets.all(
                    shouldInsetPackingIcon(widget.machines.first.imageMainPath)
                        ? 9
                        : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: MachineImage(
                      imagePath: widget.machines.first.imageMainPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.lineName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.machines.length} model',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Machine list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              ...widget.machines.map((machine) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: MachineCard(
                    machine: machine,
                    onTap: () =>
                        context.push(packingDetailLocation(machine.model)),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
