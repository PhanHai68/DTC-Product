import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/acomp_suitable_provider.dart';
import '../../models/material_model.dart';
import '../../data/material_data.dart';

class AcompSuitableScreen extends StatelessWidget {
  const AcompSuitableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lựa chọn công suất máy nén')),
      body: Consumer<AcompSuitableProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputSection(context, provider),
                const SizedBox(height: 24),
                if (provider.selectedMaterial != null &&
                    provider.ejectorCount > 0) ...[
                  _buildResultSection1(provider),
                  const SizedBox(height: 24),
                  _buildResultSection2(provider),
                ] else ...[
                  const Center(
                    child: Text(
                      'Vui lòng nhập loại nguyên liệu và số lượng béc phun để xem kết quả tính toán.',
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

  Widget _buildInputSection(
    BuildContext context,
    AcompSuitableProvider provider,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'Chọn loại nguyên liệu cần phân loại:',
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
                child: DropdownButton<MaterialModel>(
                  isExpanded: true,
                  hint: const Text('▼ Click chọn'),
                  value: provider.selectedMaterial,
                  items: materialDataList.map((model) {
                    return DropdownMenuItem<MaterialModel>(
                      value: model,
                      child: Text(model.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    provider.setMaterial(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhập số lượng béc phun (Ejectors):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Nhập số béc',
                suffixText: 'Béc',
              ),
              onChanged: (value) {
                provider.setEjectorCount(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection1(AcompSuitableProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TÍNH TOÁN LƯU LƯỢNG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            _buildResultRow(
              'Hệ số tiêu hao khí nén (Cm):',
              '${provider.selectedMaterial!.cm} Lít/phút/béc',
            ),
            _buildResultRow(
              'Lưu lượng MTM tiêu thụ (Q_req):',
              '${provider.qReq.toStringAsFixed(3)} m³/phút',
            ),
            _buildResultRow(
              'Lưu lượng máy nén cần thiết (Q_comp):',
              '${provider.qComp.toStringAsFixed(3)} m³/phút',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection2(AcompSuitableProvider provider) {
    return Card(
      elevation: 4,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ĐỀ XUẤT CÔNG SUẤT MÁY NÉN KHÍ SỬ DỤNG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const Divider(color: Colors.orange),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Công suất máy nén khí tối thiểu:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${provider.minPower.toInt()} kW',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
