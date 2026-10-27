import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/product_data.dart';
import '../../models/line_filter_spec.dart';

/// Tab "Lọc đường ống" trong Thông số kỹ thuật: mỗi model một thẻ gồm lưu
/// lượng, đường kính vào/ra và các cấp lọc (tách nước → tách thô → tách tinh).
class AcompLineFilterTab extends StatelessWidget {
  const AcompLineFilterTab({super.key});

  static final _number = NumberFormat('#,##0.##', 'vi');

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('line_filter_list'),
      padding: const EdgeInsets.all(16.0),
      children: [for (final m in lineFilters) _card(context, m)],
    );
  }

  Widget _card(BuildContext context, LineFilterSpec m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Model ${m.model}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                Text(
                  '${_number.format(m.capacityM3min)} m³/phút',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Đường kính đầu vào/đầu ra: ${m.port}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const Divider(height: 24),
            for (final l in m.levels) _level(l),
          ],
        ),
      ),
    );
  }

  Widget _level(LineFilterLevel l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.level,
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.function, style: const TextStyle(fontSize: 16)),
          ),
          Text(
            '${_number.format(l.micron)} µm',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
