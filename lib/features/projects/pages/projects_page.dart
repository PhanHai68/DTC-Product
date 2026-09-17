import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';

enum _ProjectSort { updated, name, startDate }

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final _searchController = TextEditingController();
  ProjectStatus? _status;
  String? _engineer;
  String? _customer;
  DateTimeRange? _dateRange;
  _ProjectSort _sort = _ProjectSort.updated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProjectProvider>().loadProjects(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final projects = _filtered(provider.projects);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi dự án'),
        actions: [
          IconButton(
            tooltip: 'Bộ lọc nâng cao',
            onPressed: () => _showFilters(provider.projects),
            icon: Badge(
              isLabelVisible:
                  _engineer != null || _customer != null || _dateRange != null,
              child: const Icon(Icons.filter_alt_outlined),
            ),
          ),
          PopupMenuButton<_ProjectSort>(
            tooltip: 'Sắp xếp',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ProjectSort.updated,
                child: Text('Cập nhật gần nhất'),
              ),
              PopupMenuItem(value: _ProjectSort.name, child: Text('Tên dự án')),
              PopupMenuItem(
                value: _ProjectSort.startDate,
                child: Text('Ngày bắt đầu'),
              ),
            ],
          ),
        ],
      ),
      body: provider.isLoadingProjects
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.projects.isEmpty
          ? _ErrorState(
              message: provider.error!,
              onRetry: provider.loadProjects,
            )
          : RefreshIndicator(
              onRefresh: provider.loadProjects,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Dashboard(projects: provider.projects),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Tên dự án, khách hàng, mã, model, serial...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ChoiceChip(
                                  label: const Text('Tất cả'),
                                  selected: _status == null,
                                  onSelected: (_) =>
                                      setState(() => _status = null),
                                ),
                                const SizedBox(width: 8),
                                ...ProjectStatus.values.map(
                                  (status) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(status.label),
                                      selected: _status == status,
                                      onSelected: (_) =>
                                          setState(() => _status = status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        hasFilter:
                            _status != null ||
                            _searchController.text.isNotEmpty,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.builder(
                        itemCount: projects.length,
                        itemBuilder: (_, index) => ProjectCard(
                          project: projects[index],
                          onTap: () async {
                            await context.push(
                              '/projects/${projects[index].id}',
                            );
                            if (context.mounted) {
                              context.read<ProjectProvider>().loadProjects();
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/projects/create');
          if (!context.mounted) return;
          if (created == true) {
            context.read<ProjectProvider>().loadProjects();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo dự án'),
      ),
    );
  }

  List<Project> _filtered(List<Project> source) {
    final query = _searchController.text.trim().toLowerCase();
    final items = source.where((project) {
      if (_status != null && project.status != _status) return false;
      if (_engineer != null && project.technicalEngineer != _engineer) {
        return false;
      }
      if (_customer != null && project.customerName != _customer) return false;
      if (_dateRange != null &&
          (project.startDate.isBefore(_dateRange!.start) ||
              project.startDate.isAfter(
                _dateRange!.end.add(const Duration(days: 1)),
              ))) {
        return false;
      }
      if (query.isEmpty) return true;
      final machineText = project.machines
          .map((item) => '${item.model} ${item.serialNumber}')
          .join(' ');
      return '${project.projectName} ${project.customerName} ${project.projectCode} $machineText'
          .toLowerCase()
          .contains(query);
    }).toList();
    switch (_sort) {
      case _ProjectSort.name:
        items.sort((a, b) => a.projectName.compareTo(b.projectName));
      case _ProjectSort.startDate:
        items.sort((a, b) => b.startDate.compareTo(a.startDate));
      case _ProjectSort.updated:
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return items;
  }

  Future<void> _showFilters(List<Project> projects) async {
    final engineers =
        projects
            .map((item) => item.technicalEngineer)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final customers =
        projects
            .map((item) => item.customerName)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    var engineer = _engineer;
    var customer = _customer;
    var dateRange = _dateRange;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bộ lọc dự án',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: engineer,
                decoration: const InputDecoration(labelText: 'Kỹ sư phụ trách'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả kỹ sư'),
                  ),
                  ...engineers.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setSheetState(() => engineer = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: customer,
                decoration: const InputDecoration(labelText: 'Khách hàng'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả khách hàng'),
                  ),
                  ...customers.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setSheetState(() => customer = value),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Khoảng ngày bắt đầu'),
                subtitle: Text(
                  dateRange == null
                      ? 'Tất cả thời gian'
                      : '${_shortDate(dateRange!.start)} – ${_shortDate(dateRange!.end)}',
                ),
                trailing: dateRange == null
                    ? null
                    : IconButton(
                        onPressed: () => setSheetState(() => dateRange = null),
                        icon: const Icon(Icons.clear),
                      ),
                onTap: () async {
                  final value = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: dateRange,
                  );
                  if (value != null) setSheetState(() => dateRange = value);
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        engineer = null;
                        customer = null;
                        dateRange = null;
                        Navigator.pop(sheetContext, true);
                      },
                      child: const Text('Xóa lọc'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _engineer = engineer;
        _customer = customer;
        _dateRange = dateRange;
      });
    }
  }

  String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Tổng dự án', projects.length, Icons.folder_copy_outlined),
      (
        'Đang chạy',
        projects.where((item) => item.status == ProjectStatus.active).length,
        Icons.play_circle_outline_rounded,
      ),
      (
        'Chờ nghiệm thu',
        projects
            .where((item) => item.status == ProjectStatus.waitingAcceptance)
            .length,
        Icons.fact_check_outlined,
      ),
      (
        'Hoàn thành',
        projects.where((item) => item.status == ProjectStatus.completed).length,
        Icons.task_alt_rounded,
      ),
    ];
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = values[index];
          return Container(
            width: 145,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${item.$2}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        item.$1,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 60,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'Không tìm thấy dự án phù hợp' : 'Chưa có dự án',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Hãy thử từ khóa hoặc bộ lọc khác.'
                : 'Nhấn “Tạo dự án” để bắt đầu theo dõi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
