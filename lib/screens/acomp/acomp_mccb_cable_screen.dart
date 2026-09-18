import 'package:flutter/material.dart';

import '../../data/acomp_mccb_data.dart';

class AcompMccbCableScreen extends StatefulWidget {
  const AcompMccbCableScreen({super.key});

  @override
  State<AcompMccbCableScreen> createState() => _AcompMccbCableScreenState();
}

class _AcompMccbCableScreenState extends State<AcompMccbCableScreen> {
  Map<String, String>? selectedModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn thiết bị điện')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputSection(),
            const SizedBox(height: 24),
            if (selectedModel != null)
              _buildResultSection()
            else
              const Center(
                child: Text(
                  'Vui lòng chọn model máy nén khí để xem kết quả tính toán.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
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
              'NHẬP THÔNG SỐ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Chọn Model máy nén khí:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, String>>(
                  isExpanded: true,
                  hint: const Text('▼ Click chọn'),
                  value: selectedModel,
                  items: acompMccbData.map((data) {
                    return DropdownMenuItem<Map<String, String>>(
                      value: data,
                      child: Text(
                        '${data['model']} (${data['power']} kW - ${data['type']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedModel = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
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
            _buildResultRow('Model đã chọn:', selectedModel!['model']!),
            _buildResultRow('Loại máy:', selectedModel!['type']!),
            _buildResultRow(
              'Dòng định mức (A):',
              selectedModel!['ratedCurrent']!,
            ),
            if (selectedModel!['startingCurrent']!.isNotEmpty &&
                selectedModel!['startingCurrent'] != '-')
              _buildResultRow(
                'Dòng khởi động (A):',
                selectedModel!['startingCurrent']!,
              ),
            if (selectedModel!['startingNote']!.isNotEmpty)
              _buildResultRow(
                'Ghi chú dòng khởi động:',
                selectedModel!['startingNote']!,
              ),
            const Divider(),

            if (selectedModel!['mccbComp']!.isNotEmpty)
              _buildHighlightedResultRow(
                'Chọn MCCB:',
                '${selectedModel!['mccbComp']!} A',
              ),

            if (selectedModel!['cableComp']!.isNotEmpty)
              _buildHighlightedResultRow(
                'Chọn tiết diện dây điện máy nén (Cáp đồng):',
                selectedModel!['cableComp']!,
              ),

            if (selectedModel!['mcbDryer']!.isNotEmpty &&
                selectedModel!['mcbDryer'] != '-')
              _buildHighlightedResultRow(
                'Chọn MCB máy sấy:',
                '${selectedModel!['mcbDryer']!} A',
              ),

            if (selectedModel!['cableDryer']!.isNotEmpty &&
                selectedModel!['cableDryer'] != '-')
              _buildHighlightedResultRow(
                'Chọn tiết diện dây điện máy sấy (Cáp đồng):',
                selectedModel!['cableDryer']!,
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
              flex: 3,
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
              flex: 2,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
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
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
