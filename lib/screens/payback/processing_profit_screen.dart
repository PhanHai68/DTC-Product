import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/electricity_bill_provider.dart';
import '../../providers/processing_profit_provider.dart';
import '../../data/power_consumption_data.dart';

class ProcessingProfitScreen extends StatefulWidget {
  const ProcessingProfitScreen({super.key});

  @override
  _ProcessingProfitScreenState createState() => _ProcessingProfitScreenState();
}

class _ProcessingProfitScreenState extends State<ProcessingProfitScreen> {
  final formatCurrency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin từ mục 2 (Tính giá điện 1 ngày)
    final electricityProvider = Provider.of<ElectricityBillProvider>(
      context,
      listen: false,
    );

    final selectedModel = electricityProvider.selectedModel;
    final totalHours = electricityProvider.totalHours ?? 0;
    final totalBill = electricityProvider.totalBill ?? 0;

    // Lấy Năng suất từ dữ liệu
    double capacity = 0;
    if (selectedModel != null &&
        powerConsumptionData.containsKey(selectedModel)) {
      var specs = powerConsumptionData[selectedModel]!;
      var capacityStr =
          specs.firstWhere(
            (e) => e['Tiêu chí'] == 'Năng suất (Tấn/h)',
            orElse: () => {'Thông số': '0'},
          )['Thông số'] ??
          '0';
      capacity = double.tryParse(capacityStr) ?? 0;
    }

    return Consumer<ProcessingProfitProvider>(
      builder: (context, profitProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Lợi nhuận gia công')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hiển thị thông số đã lấy từ mục trước
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tiền điện phải trả 1 ngày đã tính:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Model: ${selectedModel ?? "Chưa chọn"}'),
                        const SizedBox(height: 4),
                        Text('Năng suất: $capacity Tấn/h'),
                        const SizedBox(height: 4),
                        Text('Tổng số giờ vận hành/ngày: $totalHours giờ'),
                        const SizedBox(height: 4),
                        Text('Tiền điện: ${formatCurrency.format(totalBill)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Nhập giá gia công 1 Tấn (VNĐ)',
                    border: OutlineInputBorder(),
                    suffixText: ',000',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: profitProvider.setProcessingPrice,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Nhập lương nhân viên 1 ngày (VNĐ)',
                    border: OutlineInputBorder(),
                    suffixText: ',000',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: profitProvider.setDailySalary,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    profitProvider.calculate(
                      capacity: capacity,
                      totalHours: totalHours,
                      totalBill: totalBill,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                if (profitProvider.totalProfit != null)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Kết Quả',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng lợi nhuận gia công:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                formatCurrency.format(
                                  profitProvider.totalProfit,
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: profitProvider.totalProfit! >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
