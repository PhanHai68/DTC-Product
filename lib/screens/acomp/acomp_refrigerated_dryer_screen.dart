import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/product_data.dart';
import '../../models/refrigerated_dryer_spec.dart';

/// Thông số máy sấy khí tác nhân lạnh ACD.
class AcompRefrigeratedDryerScreen extends StatefulWidget {
  const AcompRefrigeratedDryerScreen({super.key});

  @override
  State<AcompRefrigeratedDryerScreen> createState() =>
      _AcompRefrigeratedDryerScreenState();
}

class _AcompRefrigeratedDryerScreenState
    extends State<AcompRefrigeratedDryerScreen> {
  static final _number = NumberFormat('#,##0.##', 'vi');
  RefrigeratedDryerSpec? _selected;

  String _n(double v) => _number.format(v);

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Máy sấy khí tác nhân lạnh (ACD)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chọn Model (lưu lượng xử lý)',
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
                child: DropdownButton<RefrigeratedDryerSpec>(
                  key: const Key('refrigerated_dryer_model'),
                  isExpanded: true,
                  hint: const Text('Chọn model...'),
                  value: selected,
                  items: [
                    for (final m in refrigeratedDryers)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${m.model} - ${_n(m.capacityM3min)} m³/phút',
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
                        'Thông số Model: ${selected.model}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),
                      _row(
                        'Lưu lượng xử lý',
                        '${_n(selected.capacityM3min)} m³/phút',
                      ),
                      _row('Áp suất làm việc', selected.workingPressure),
                      _row('Nhiệt độ điểm sương', selected.dewPoint),
                      _row('Nhiệt độ làm việc', selected.operatingTemperature),
                      if (selected.maxInletTempC case final t?)
                        _row('Nhiệt độ khí vào tối đa', '${_n(t)} °C'),
                      if (selected.refrigerant case final gas?)
                        _row('Môi chất lạnh', gas),
                      if (selected.matchingCompressorKw.isNotEmpty)
                        _row(
                          'Máy nén khí tương ứng',
                          '${selected.matchingCompressorKw.map(_n).join('/')} kW',
                        ),
                      _row('Điện áp', selected.voltage),
                      _row(
                        'Công suất máy nén lạnh',
                        '${_n(selected.compressorKw)} kW',
                      ),
                      _row('Công suất quạt', '${_n(selected.fanW)} W'),
                      _row('Đường kính ống ra khí', selected.airOutlet),
                      _row(
                        'Kích thước (D x R x C)',
                        '${_n(selected.lengthMm)} x ${_n(selected.widthMm)} x '
                            '${_n(selected.heightMm)} mm',
                      ),
                      _row('Trọng lượng tịnh', '${_n(selected.weightKg)} kg'),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Vui lòng chọn model để xem thông số.',
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
