import 'package:flutter/material.dart';

import '../../data/acomp_pipe_data.dart';
import '../../core/input/localized_number.dart';

class AcompTankFillTimeScreen extends StatefulWidget {
  const AcompTankFillTimeScreen({super.key});

  @override
  State<AcompTankFillTimeScreen> createState() =>
      _AcompTankFillTimeScreenState();
}

class _AcompTankFillTimeScreenState extends State<AcompTankFillTimeScreen> {
  String inputMode = 'Model'; // 'Model' or 'Manual'
  Map<String, dynamic>? selectedModel;

  final TextEditingController _flowController = TextEditingController();
  final TextEditingController _p1Controller = TextEditingController(text: '0');
  final TextEditingController _p2Controller = TextEditingController(text: '8');
  final TextEditingController _tankVolumeController = TextEditingController(
    text: '1000',
  );

  double? timeMinutes;
  double? timeSeconds;
  String? _validationMessage;

  @override
  void dispose() {
    _flowController.dispose();
    _p1Controller.dispose();
    _p2Controller.dispose();
    _tankVolumeController.dispose();
    super.dispose();
  }

  void _calculate() {
    double flowM3Phut = 0;
    if (inputMode == 'Model' && selectedModel != null) {
      flowM3Phut = double.tryParse(selectedModel!['flow8bar']) ?? 0;
    } else {
      flowM3Phut = parseLocalizedDouble(_flowController.text) ?? 0;
    }

    double flowLitPhut = flowM3Phut * 1000;
    double p1 = parseLocalizedDouble(_p1Controller.text) ?? 0;
    double p2 = parseLocalizedDouble(_p2Controller.text) ?? 0;
    double tankVolume = parseLocalizedDouble(_tankVolumeController.text) ?? 0;

    if (flowLitPhut <= 0 || p2 <= p1 || tankVolume <= 0) {
      setState(() {
        timeMinutes = null;
        timeSeconds = null;
        _validationMessage = flowLitPhut <= 0
            ? 'Hãy chọn model hoặc nhập lưu lượng lớn hơn 0.'
            : p2 <= p1
            ? 'Áp suất cần đạt phải lớn hơn áp suất ban đầu.'
            : 'Thể tích bình phải lớn hơn 0.';
      });
      return;
    }

    // Constants
    double p0 = 1.013;
    double t0 = 303.15;
    double t1 = 318.15;

    // Formula: V_hut = ((P2 - P1) * V_tank * T0) / (P0 * T1)
    double vHut = ((p2 - p1) * tankVolume * t0) / (p0 * t1);

    double tPhut = vHut / flowLitPhut;
    double tGiay = tPhut * 60;

    setState(() {
      timeMinutes = tPhut;
      timeSeconds = tGiay;
      _validationMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tính thời gian nạp đầy bình tích')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputSection(),
            const SizedBox(height: 24),
            _buildResultSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
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
            const SizedBox(height: 8),

            const Text(
              'Phương thức nhập lưu lượng:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioGroup<String>(
              groupValue: inputMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  inputMode = value;
                  _calculate();
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Theo Model',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: 'Model',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Nhập tay',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: 'Manual',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            if (inputMode == 'Model') ...[
              const Text(
                'Chọn Model máy nén khí:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    hint: const Text('▼ Click chọn'),
                    value: selectedModel,
                    items: acompModelsFlowData
                        .where(
                          (data) =>
                              (data['flow8bar'] ?? '').toString().isNotEmpty,
                        )
                        .map((data) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: data,
                            child: Text(
                              '${data['model']} (Lưu lượng: ${data['flow8bar']} m³/phút/8 bar)',
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedModel = value;
                        _calculate();
                      });
                    },
                  ),
                ),
              ),
              if (selectedModel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Lưu lượng máy nén khí: ${double.tryParse(selectedModel!['flow8bar'])! * 1000} Lít/phút',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ] else ...[
              _buildTextField(
                'Lưu lượng máy nén khí (m³/phút):',
                _flowController,
              ),
            ],

            const SizedBox(height: 16),
            _buildTextField(
              'Thể tích bình chứa khí nén (Lít):',
              _tankVolumeController,
            ),
            const SizedBox(height: 16),
            _buildTextField('Áp suất ban đầu (bar):', _p1Controller),
            const SizedBox(height: 16),
            _buildTextField('Áp suất cần đạt (bar):', _p2Controller),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'TÍNH TOÁN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [LocalizedDecimalTextInputFormatter()],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) => _calculate(),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    if (timeMinutes == null) {
      return const SizedBox.shrink();
    }

    return Card(
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
            const Divider(),
            _buildResultRow(
              'Thời gian nén đầy bình chứa (phút):',
              timeMinutes!.toStringAsFixed(2),
            ),
            const Divider(),
            _buildHighlightedResultRow(
              'Đổi ra giây:',
              '${timeSeconds!.toStringAsFixed(1)} s',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
