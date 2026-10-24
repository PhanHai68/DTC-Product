import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../../../widgets/shell_back_button.dart';
import '../models/technical_term.dart';
import '../providers/technical_dictionary_provider.dart';
import '../widgets/term_status_icon.dart';

/// Màn tra cứu: tìm theo tiếng Anh, viết tắt, tên gọi khác hoặc nghĩa tiếng
/// Việt, lọc theo nhóm máy, loại và tiến độ học.
class TechnicalDictionaryScreen extends StatefulWidget {
  const TechnicalDictionaryScreen({super.key});

  @override
  State<TechnicalDictionaryScreen> createState() =>
      _TechnicalDictionaryScreenState();
}

class _TechnicalDictionaryScreenState extends State<TechnicalDictionaryScreen> {
  late final TextEditingController _search;
  static final _count = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<TechnicalDictionaryProvider>().query,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TechnicalDictionaryProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Từ điển chuyên ngành'),
        actions: [
          if (provider.ready)
            IconButton(
              key: const Key('dictionary_progress'),
              tooltip: 'Tiến độ học',
              onPressed: () => _showProgress(context, provider),
              icon: const Icon(Icons.insights_rounded),
            ),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(TechnicalDictionaryProvider provider) {
    if (provider.loading || (!provider.ready && provider.error == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        title: provider.error!,
        action: FilledButton(
          onPressed: provider.retry,
          child: const Text('Thử lại'),
        ),
      );
    }
    final results = provider.results;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const Key('dictionary_search'),
            controller: _search,
            onChanged: provider.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tiếng Anh, viết tắt hoặc nghĩa tiếng Việt',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: provider.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _search.clear();
                        provider.setQuery('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        _FilterBar(provider: provider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              provider.query.isEmpty && !provider.hasFilter
                  ? '${_count.format(results.length)} thuật ngữ'
                  : 'Tìm thấy ${_count.format(results.length)} thuật ngữ',
              key: const Key('dictionary_result_count'),
              style: TextStyle(
                color: DtcPalette.of(context).muted,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _Message(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy thuật ngữ phù hợp.',
                  subtitle: provider.hasFilter
                      ? 'Thử bỏ bớt bộ lọc hoặc đổi từ khóa.'
                      : 'Thử gõ từ khóa khác, có dấu hay không dấu đều được.',
                  action: provider.hasFilter
                      ? TextButton(
                          onPressed: provider.clearFilters,
                          child: const Text('Bỏ bộ lọc'),
                        )
                      : null,
                )
              : ListView.separated(
                  key: const Key('dictionary_list'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TermTile(
                    term: results[i],
                    status: provider.progressOf(results[i]).status,
                    onTap: () => context.push(
                      '/technical-dictionary/term/${results[i].id}',
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showProgress(
    BuildContext context,
    TechnicalDictionaryProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ProgressSheet(summary: provider.progressSummary()),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final TechnicalDictionaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          _FilterButton(
            key: const Key('dictionary_filter_group'),
            label: 'Nhóm máy',
            value: provider.group,
            options: provider.groups,
            onSelected: provider.setGroup,
          ),
          const SizedBox(width: 8),
          _FilterButton(
            key: const Key('dictionary_filter_type'),
            label: 'Loại',
            value: provider.type,
            options: provider.types,
            onSelected: provider.setType,
          ),
          const SizedBox(width: 8),
          _FilterButton(
            key: const Key('dictionary_filter_progress'),
            label: 'Tiến độ',
            value: provider.progressFilter?.label,
            options: [for (final f in ProgressFilter.values) f.label],
            onSelected: (label) => provider.setProgressFilter(
              ProgressFilter.values.where((f) => f.label == label).firstOrNull,
            ),
          ),
          if (provider.hasFilter) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              key: const Key('dictionary_clear_filters'),
              onPressed: provider.clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Bỏ lọc'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút lọc: hiện giá trị đang chọn, bấm thì mở danh sách để chọn.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value != null;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(value ?? label, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ],
      ),
      onSelected: (_) async {
        // Giá trị rỗng = "Tất cả" (bỏ lọc mục này).
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final option in ['', ...options])
                  ListTile(
                    title: Text(option.isEmpty ? 'Tất cả' : option),
                    trailing: (option.isEmpty ? value == null : option == value)
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onSelected(picked.isEmpty ? null : picked);
      },
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.term,
    required this.status,
    required this.onTap,
  });

  final TechnicalTerm term;
  final TermStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('dictionary_term_${term.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: term.term,
                            style: TextStyle(
                              color: palette.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (term.abbreviation.isNotEmpty &&
                              term.abbreviation != term.term)
                            TextSpan(
                              text: '  ${term.abbreviation}',
                              style: TextStyle(
                                color: palette.cyan,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      term.meaning,
                      style: TextStyle(color: palette.ink, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (term.ipa.isNotEmpty) term.ipa,
                        term.group,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                TermStatusIcon(status: status!),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressSheet extends StatelessWidget {
  const _ProgressSheet({required this.summary});

  final List<GroupProgress> summary;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final total = summary.first;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text('Tiến độ học', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Đã thuộc ${total.learned}/${total.total} · đang học '
            '${total.learning}. Đánh dấu ở màn chi tiết từng thuật ngữ.',
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 16),
          for (final row in summary.skip(1)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.group!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${row.learned}/${row.total}'
                  '${row.learning > 0 ? ' · học ${row.learning}' : ''}',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: row.ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: palette.cyan),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
