import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/product_data.dart';
import '../../models/oil_free_spec.dart';

/// Thông số máy nén khí trục vít không dầu phun nước, áp suất thường:
/// dòng tốc độ cố định AFR-F và biến tần AFR-PV.
class AcompOilFreeDetailScreen extends StatefulWidget {
  const AcompOilFreeDetailScreen({super.key});

  @override
  State<AcompOilFreeDetailScreen> createState() =>
      _AcompOilFreeDetailScreenState();
}

class _AcompOilFreeDetailScreenState extends State<AcompOilFreeDetailScreen> {
  static final _number = NumberFormat('#,##0.###', 'vi');
  bool _vsd = false;
  OilFreeSpec? _selected;

  String _n(double v) => _number.format(v);

  String _bar(double bar) => '${_n(bar)} bar';

  @override
  Widget build(BuildContext context) {
    final models = [
      for (final m in oilFreeSpecs)
        if (m.isVsd == _vsd) m,
    ];
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Trục vít không dầu (AFR)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Phun nước, áp suất thường',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('oil_free_series'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Cố định (AFR-F)')),
                ButtonSegment(value: true, label: Text('Biến tần (AFR-PV)')),
              ],
              selected: {_vsd},
              onSelectionChanged: (v) => setState(() {
                _vsd = v.first;
                _selected = null;
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn Công suất máy (HP)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OilFreeSpec>(
                  isExpanded: true,
                  hint: const Text('Chọn công suất...'),
                  value: selected,
                  items: [
                    for (final m in models)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${_n(m.powerHP)} HP (${_n(m.powerKW)} kW) - ${m.code}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (selected != null)
              Expanded(
                child: Card(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Text(
                        'Thông số Model: ${selected.code}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),
                      _row(
                        'Kiểu máy',
                        selected.isVsd ? 'Biến tần PM' : 'Tốc độ cố định',
                      ),
                      _row('Công suất', '${_n(selected.powerKW)} kW'),
                      for (final e in selected.flow.entries)
                        _row(
                          'Lưu lượng ở ${_bar(e.key)}',
                          selected.flowMin[e.key] == null
                              ? '${_n(e.value)} m³/phút'
                              : '${_n(selected.flowMin[e.key]!)}–${_n(e.value)} m³/phút',
                        ),
                      _row('Kích thước lỗ thoát khí', selected.airOutlet),
                      _row('Ống nước vào/ra', selected.waterPipe),
                      _row('Độ ồn', '${_n(selected.noiseDb)} dB'),
                      _row(
                        'Nước làm mát (nước vào 32 °C)',
                        '${_n(selected.coolingWaterTH)} t/h',
                      ),
                      _row(
                        'Nước bôi trơn',
                        '${_n(selected.lubricatingWaterL)} Lít',
                      ),
                      if (selected.dimensionsWater == null)
                        _row(
                          'Kích thước (D x R x C)',
                          '${selected.dimensions} mm',
                        )
                      else ...[
                        _row(
                          'Kích thước bản giải nhiệt gió (A)',
                          '${selected.dimensions} mm',
                        ),
                        _row(
                          'Kích thước bản giải nhiệt nước (W)',
                          '${selected.dimensionsWater} mm',
                        ),
                      ],
                      if (selected.weightWaterKg == null)
                        _row('Trọng lượng', '${_n(selected.weightKg)} kg')
                      else ...[
                        _row(
                          'Trọng lượng bản A',
                          '${_n(selected.weightKg)} kg',
                        ),
                        _row(
                          'Trọng lượng bản W',
                          '${_n(selected.weightWaterKg!)} kg',
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Vui lòng chọn công suất để xem thông số.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
