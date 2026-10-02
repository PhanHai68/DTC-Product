import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_entry.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesEntryListScreen extends StatefulWidget {
  const SalesEntryListScreen({super.key});

  @override
  State<SalesEntryListScreen> createState() => _SalesEntryListScreenState();
}

class _SalesEntryListScreenState extends State<SalesEntryListScreen> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<SalesEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await context.read<SalesGoalProvider>().entriesForMonth(
        _month,
      );
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (error, stackTrace) {
      debugPrint('SalesEntryListScreen._load: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = 'Không thể tải danh sách doanh số.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doanh số thực tế')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sales-goal/entries/form');
          if (mounted) await _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ghi doanh số'),
      ),
      body: Column(
        children: [
          _MonthSelector(
            month: _month,
            canGoNext: !_isCurrentMonth,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _entries.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có doanh số trong tháng ${_month.month}/${_month.year}.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _EntryCard(
                      entry: _entries[index],
                      onEdit: () async {
                        await context.push(
                          '/sales-goal/entries/form',
                          extra: _entries[index],
                        );
                        if (mounted) await _load();
                      },
                      onDelete: () => _delete(_entries[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(SalesEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa doanh số?'),
        content: Text('Xóa khoản ${formatSalesMoney(entry.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<SalesGoalProvider>();
    final ok = await runSalesGoalAction(
      context,
      () => provider.deleteEntry(entry.id!),
      errorMessage: 'Không thể xóa doanh số. Vui lòng thử lại.',
    );
    if (ok && mounted) await _load();
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        SizedBox(
          width: 150,
          child: Text(
            'Tháng ${month.month}/${month.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final SalesEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: palette.cyan.withValues(alpha: 0.12),
          child: Icon(Icons.payments_outlined, color: palette.cyan),
        ),
        title: Text(
          formatSalesMoney(entry.amount),
          style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            formatSalesDate(entry.saleDate),
            if (entry.customerOrProject.isNotEmpty) entry.customerOrProject,
            if (entry.productOrMachine.isNotEmpty) entry.productOrMachine,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}
