import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/air_tank_spec.dart';
import '../../providers/acomp_tank_provider.dart';
import '../../core/input/localized_number.dart';

class AcompTankScreen extends StatefulWidget {
  const AcompTankScreen({super.key});

  @override
  State<AcompTankScreen> createState() => _AcompTankScreenState();
}

class _AcompTankScreenState extends State<AcompTankScreen> {
  final TextEditingController _qcController = TextEditingController();
  final TextEditingController _tcController = TextEditingController(text: '20');
  final TextEditingController _deltaPController = TextEditingController(
    text: '0.5',
  );
  final TextEditingController _t0Controller = TextEditingController(text: '45');
  final TextEditingController _t1Controller = TextEditingController(text: '35');

  @override
  void initState() {
    super.initState();
    final provider = context.read<AcompTankProvider>();
    _qcController.text = provider.qc == 0 ? '' : _inputText(provider.qc);
    _tcController.text = _inputText(provider.tc);
    _deltaPController.text = _inputText(provider.deltaP);
    _t0Controller.text = _inputText(provider.t0);
    _t1Controller.text = _inputText(provider.t1);
  }

  String _inputText(double value) => value.isFinite ? value.toString() : '';

  @override
  void dispose() {
    _qcController.dispose();
    _tcController.dispose();
    _deltaPController.dispose();
    _t0Controller.dispose();
    _t1Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tính thể tích bình chứa khí')),
      body: Consumer<AcompTankProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputSection(context, provider),
                const SizedBox(height: 24),
                if (provider.qc > 0 ||
                    provider.recommendationError != null) ...[
                  _buildResultSection(provider),
                ] else ...[
                  const Center(
                    child: Text(
                      'Vui lòng nhập Lưu lượng máy nén khí để xem kết quả tính toán.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, AcompTankProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'THÔNG SỐ ĐẦU VÀO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(),
            _buildInputField(
              'Lưu lượng máy nén khí:',
              _qcController,
              'm³/phút',
              provider.setQc,
            ),
            _buildInputField(
              'Thời gian chu kỳ nạp/xả:',
              _tcController,
              'Giây (s)',
              provider.setTc,
            ),
            _buildInputField(
              'Độ chênh áp:',
              _deltaPController,
              'bar',
              provider.setDeltaP,
            ),
            _buildInputField(
              'Nhiệt độ trong bình chứa:',
              _t0Controller,
              '°C',
              provider.setT0,
            ),
            _buildInputField(
              'Nhiệt độ tại đầu hút:',
              _t1Controller,
              '°C',
              provider.setT1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String suffix,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [LocalizedDecimalTextInputFormatter()],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              suffixText: suffix,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Thông số bình đề xuất theo bảng bình tích khí tiêu chuẩn.
  Widget _buildTankDetails(AirTankSpec tank) {
    final number = NumberFormat('#,##0.##', 'vi');
    final rows = [
      ('Mã hàng', tank.model),
      (
        'Áp suất thiết kế',
        '${number.format(tank.designPressureKgfCm2)} kgf/cm²',
      ),
      ('Áp suất thử tải', '${number.format(tank.testPressureKgfCm2)} kgf/cm²'),
      ('Đường kính', '${number.format(tank.diameterMm)} mm'),
      ('Trọng lượng', '${number.format(tank.weightKg)} kg'),
    ];
    return Container(
      key: const Key('acomp_tank_recommended_details'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 15)),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSection(AcompTankProvider provider) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KẾT QUẢ TÍNH TOÁN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Divider(color: Colors.blue),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Dung tích lý thuyết:',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      provider.inputError != null || !provider.vTh.isFinite
                          ? '—'
                          : '${provider.vTh.toStringAsFixed(1)} Lít',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'ĐỀ XUẤT CHỌN BÌNH TIÊU CHUẨN:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      provider.vRec == null
                          ? '—'
                          : '${provider.vRec!.toInt()} Lít',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            if (provider.recommendedTank case final tank?)
              _buildTankDetails(tank),
            if (provider.recommendationError != null) ...[
              const SizedBox(height: 12),
              Text(
                provider.recommendationError!,
                style: const TextStyle(color: Colors.deepOrange, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
