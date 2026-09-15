import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/acomp_pipe_data.dart';

class AcompPipeScreen extends StatefulWidget {
  const AcompPipeScreen({super.key});

  @override
  State<AcompPipeScreen> createState() => _AcompPipeScreenState();
}

class _AcompPipeScreenState extends State<AcompPipeScreen> {
  String inputMode = 'Model'; // 'Model' or 'Manual'
  Map<String, dynamic>? selectedModel;

  final TextEditingController _flowController = TextEditingController();
  final TextEditingController _pressureDropController = TextEditingController(
    text: '0.1',
  );
  final TextEditingController _maxPressureController = TextEditingController(
    text: '7',
  );
  final TextEditingController _lengthController = TextEditingController(
    text: '50',
  );

  double? calculatedDiameter;
  Map<String, dynamic>? matchedPipe;

  @override
  void dispose() {
    _flowController.dispose();
    _pressureDropController.dispose();
    _maxPressureController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _calculate() {
    double flow = 0;
    if (inputMode == 'Model' && selectedModel != null) {
      flow = double.tryParse(selectedModel!['flow7bar'].toString()) ?? 0;
    } else {
      flow = double.tryParse(_flowController.text) ?? 0;
    }

    double deltaP = double.tryParse(_pressureDropController.text) ?? 0;
    double pMax = double.tryParse(_maxPressureController.text) ?? 0;
    double length = double.tryParse(_lengthController.text) ?? 0;

    if (flow <= 0 || deltaP <= 0 || pMax <= 0 || length <= 0) {
      setState(() {
        calculatedDiameter = null;
        matchedPipe = null;
      });
      return;
    }

    // Formula: ((1.6 * ((V/60)^1.85) * L * (10^8)) / (Δp * P_max)) ^ (1/5)
    double vS = flow / 60.0;
    double part1 = 1.6 * pow(vS, 1.85) * length * pow(10, 8);
    double part2 = deltaP * pMax;

    double diameter = pow(part1 / part2, 0.2).toDouble();

    // Match standard pipe
    Map<String, dynamic>? foundPipe;
    for (var pipe in pipeStandardData) {
      if ((pipe['mm'] as num).toDouble() >= diameter) {
        foundPipe = pipe;
        break;
      }
    }

    setState(() {
      calculatedDiameter = diameter;
      matchedPipe = foundPipe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tính toán đường ống khí nén')),
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
                    items: acompModelsFlowData.map((data) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: data,
                        child: Text(
                          '${data['model']} (Lưu lượng: ${data['flow7bar']} m³/phút/7 bar)',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedModel = value;
                        _calculate();
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              _buildTextField(
                'Lưu lượng máy nén khí (m³/phút):',
                _flowController,
              ),
            ],

            const SizedBox(height: 16),
            _buildTextField(
              'Độ sụt áp mong muốn Δp (bar):',
              _pressureDropController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Áp suất ngắt tải P_max (bar):',
              _maxPressureController,
            ),
            const SizedBox(height: 16),
            _buildTextField('Chiều dài đường ống (m):', _lengthController),

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
    if (calculatedDiameter == null) {
      return const SizedBox.shrink();
    }

    String pipeResult = matchedPipe != null
        ? 'DN${matchedPipe!['dn']} / ${matchedPipe!['phi']}'
        : 'Ngoài dải';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KẾT QUẢ ĐƯỜNG KÍNH & CHỌN ỐNG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            _buildResultRow(
              'Đường kính tính toán (mm):',
              calculatedDiameter!.toStringAsFixed(2),
            ),
            const Divider(),
            _buildHighlightedResultRow('Chọn Ống (DN / Phi):', pipeResult),
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
              flex: 1,
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
