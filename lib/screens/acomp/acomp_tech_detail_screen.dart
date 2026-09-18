import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/acomp_spec_provider.dart';
import '../../models/acomp_spec_model.dart';

class AcompTechDetailScreen extends StatefulWidget {
  final String categoryType; // 'PV' or 'F'

  const AcompTechDetailScreen({super.key, required this.categoryType});

  @override
  State<AcompTechDetailScreen> createState() => _AcompTechDetailScreenState();
}

class _AcompTechDetailScreenState extends State<AcompTechDetailScreen> {
  AcompSpecModel? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AcompSpecProvider>(context);
    final isPV = widget.categoryType == 'PV';
    final machineList = isPV ? provider.pvList : provider.fList;
    final title = isPV
        ? 'Trục vít Biến tần (ACP-PV)'
        : 'Trục vít Tốc độ cố định (ACP-F)';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                child: DropdownButton<AcompSpecModel>(
                  isExpanded: true,
                  hint: const Text('Chọn công suất...'),
                  value: _selectedModel,
                  items: machineList.map((model) {
                    return DropdownMenuItem<AcompSpecModel>(
                      value: model,
                      child: Text(
                        '${model.powerHP} HP (${model.powerKW} kW) - ${model.modelCode}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedModel = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedModel != null)
              Expanded(
                child: Card(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Text(
                        'Thông số Model: ${_selectedModel!.modelCode}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),
                      _buildSpecRow(
                        'Lưu lượng ở 7 bar',
                        '${_selectedModel!.flow7Bar} m³/phút',
                      ),
                      _buildSpecRow(
                        'Lưu lượng ở 8 bar',
                        '${_selectedModel!.flow8Bar} m³/phút',
                      ),
                      _buildSpecRow(
                        'Kích thước lỗ thoát khí',
                        _selectedModel!.airOutlet,
                      ),
                      _buildSpecRow(
                        'Dầu bôi trơn',
                        '${_selectedModel!.lubricant} Lít',
                      ),
                      _buildSpecRow(
                        'Trọng lượng',
                        '${_selectedModel!.weight} kg',
                      ),
                      _buildSpecRow(
                        'Kích thước (D x R x C)',
                        '${_selectedModel!.dimensions} mm',
                      ),
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

  Widget _buildSpecRow(String label, String value) {
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
