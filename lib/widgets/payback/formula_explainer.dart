import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Số trong phần giải thích công thức: dấu chấm ngăn nghìn, tối đa 3 chữ số
/// thập phân (VD 1.811 · 77,12 · 0,125).
String formulaNumber(num value) =>
    NumberFormat('#,##0.###', 'vi_VN').format(value);

/// Thẻ "Cách tính" thu gọn được trên các màn phân tích hoàn vốn.
///
/// [formulas] là công thức tổng quát, luôn hiện; [workings] là công thức đã
/// thay số của lần tính gần nhất, để trống khi chưa tính.
class FormulaExplainer extends StatelessWidget {
  const FormulaExplainer({
    super.key,
    required this.formulas,
    this.workings = const [],
    this.notes = const [],
  });

  final List<String> formulas;
  final List<String> workings;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.functions_rounded, color: colorScheme.primary),
        title: const Text(
          'Cách tính',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Xem công thức và số liệu đã dùng'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(title: 'Công thức', lines: formulas),
          if (workings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(title: 'Thay số lần tính gần nhất', lines: workings),
          ],
          for (final note in notes) ...[
            const SizedBox(height: 8),
            Text(
              '* $note',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, line) in lines.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: Text(line, style: const TextStyle(height: 1.4)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
