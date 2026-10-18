import 'package:flutter/material.dart';

import '../../data/product_data.dart';
import '../../features/factory_location/utils/maps_link.dart'
    show normalizeForSearch;
import '../../models/color_sorter_errors.dart';

/// Tra cứu lỗi máy tách màu — dùng chung cho mọi dòng máy; [machineLine]
/// chỉ để hiện tên dòng máy đang xem (VD "Máy tách màu Gạo").
class ColorSorterErrorsScreen extends StatefulWidget {
  const ColorSorterErrorsScreen({super.key, this.machineLine});

  final String? machineLine;

  @override
  State<ColorSorterErrorsScreen> createState() =>
      _ColorSorterErrorsScreenState();
}

class _ColorSorterErrorsScreenState extends State<ColorSorterErrorsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Iterable<String> texts) {
    if (_query.isEmpty) return true;
    return texts.any((text) => normalizeForSearch(text).contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    final data = colorSorterErrors;
    final common = [
      for (final (index, item) in data.common.indexed)
        if (_matches([item.error, ...item.checks])) (index + 1, item),
    ];
    final detailed = [
      for (final (index, item) in data.detailed.indexed)
        if (_matches([
          item.error,
          for (final c in item.causes) ...[c.cause, c.fix],
        ]))
          (index + 1, item),
    ];
    final poor = [
      for (final (index, item) in data.poorSorting.indexed)
        if (_matches([item.cause, item.explanation, item.note, ...item.fixes]))
          (index + 1, item),
    ];
    final blocks = [
      for (final item in data.blocks)
        if (_matches([item.block, item.power, item.connections, item.note]))
          item,
    ];
    final outputs = [
      for (final item in data.etmOutputs)
        if (_matches([item.output, item.function, item.target, item.note]))
          item,
    ];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tra cứu lỗi'),
              if (widget.machineLine != null)
                Text(
                  widget.machineLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Lỗi thường gặp (${common.length})'),
              Tab(text: 'Nguyên nhân (${detailed.length})'),
              Tab(text: 'Tách không đạt (${poor.length})'),
              Tab(text: 'Nguồn & kết nối (${blocks.length + outputs.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const Key('color_sorter_errors_search'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm lỗi, bộ phận… (VD: súng, P3, 48VDC)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (value) =>
                    setState(() => _query = normalizeForSearch(value)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _list([
                    for (final (no, item) in common)
                      _ErrorCard(
                        number: no,
                        title: item.error,
                        initiallyExpanded: _query.isNotEmpty,
                        children: [
                          const _SectionLabel(
                            'Kiểm tra / Khắc phục',
                            color: Color(0xFF00796B),
                          ),
                          _Bullets(item.checks),
                        ],
                      ),
                  ]),
                  _list([
                    for (final (no, item) in detailed)
                      _ErrorCard(
                        number: no,
                        title: item.error,
                        subtitle: '${item.causes.length} nguyên nhân',
                        initiallyExpanded: _query.isNotEmpty,
                        children: [
                          for (final (i, c) in item.causes.indexed)
                            _CauseFix(
                              cause: c.cause,
                              fix: c.fix,
                              showDivider: i > 0,
                            ),
                        ],
                      ),
                  ]),
                  _list([
                    for (final (no, item) in poor)
                      _ErrorCard(
                        number: no,
                        title: item.cause,
                        initiallyExpanded: _query.isNotEmpty,
                        children: [
                          const _SectionLabel(
                            'Giải thích',
                            color: Color(0xFFE65100),
                          ),
                          Text(item.explanation),
                          const SizedBox(height: 12),
                          const _SectionLabel(
                            'Cách khắc phục',
                            color: Color(0xFF00796B),
                          ),
                          _Bullets(item.fixes),
                          if (item.note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _NoteChip(item.note),
                          ],
                        ],
                      ),
                  ]),
                  _list([
                    if (blocks.isNotEmpty)
                      const _GroupHeader('Nguồn cấp và kết nối các khối'),
                    for (final item in blocks) _BlockCard(item),
                    if (outputs.isNotEmpty) const _GroupHeader('Ngõ ra ETM'),
                    for (final item in outputs) _EtmOutputTile(item),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Widget> children) {
    if (children.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Không tìm thấy lỗi phù hợp.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: children,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.number,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Đổi key theo trạng thái tìm kiếm để mở/thu lại đúng khi gõ.
        key: ValueKey('$number-$title-$initiallyExpanded'),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        leading: CircleAvatar(
          radius: 15,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    ),
  );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(item)),
            ],
          ),
        ),
    ],
  );
}

class _CauseFix extends StatelessWidget {
  const _CauseFix({
    required this.cause,
    required this.fix,
    required this.showDivider,
  });

  final String cause;
  final String fix;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showDivider) const Divider(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFE65100)),
          const SizedBox(width: 8),
          Expanded(child: Text(cause)),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.build_circle_outlined,
            size: 18,
            color: Color(0xFF00796B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fix,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ],
  );
}

class _NoteChip extends StatelessWidget {
  const _NoteChip(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.memory, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Liên quan: $note',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class _BlockCard extends StatelessWidget {
  const _BlockCard(this.block);

  final SorterBlock block;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              block.block,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            row(Icons.bolt, 'Nguồn cấp', block.power),
            row(Icons.cable, 'Kết nối', block.connections),
            if (block.note.isNotEmpty)
              row(Icons.info_outline, 'Ghi chú', block.note),
          ],
        ),
      ),
    );
  }
}

class _EtmOutputTile extends StatelessWidget {
  const _EtmOutputTile(this.output);

  final EtmOutput output;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = [
      if (output.target.isNotEmpty) output.target,
      if (output.note.isNotEmpty) output.note,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            output.output,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        title: Text(output.function),
        subtitle: details.isEmpty ? null : Text(details),
      ),
    );
  }
}
