import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                if (provider.qc > 0) ...[
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildResultSection(AcompTankProvider provider) {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                      '${provider.vTh.toStringAsFixed(1)} Lít',
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
                      '${provider.vRec.toInt()} Lít',
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
          ],
        ),
      ),
    );
  }
}
