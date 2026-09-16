import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/electricity_bill_provider.dart';
import '../../data/power_consumption_data.dart';
import '../../core/input/localized_number.dart';

import 'package:intl/intl.dart';

class ElectricityBillScreen extends StatefulWidget {
  const ElectricityBillScreen({super.key});

  @override
  State<ElectricityBillScreen> createState() => _ElectricityBillScreenState();
}

class _ElectricityBillScreenState extends State<ElectricityBillScreen> {
  final formatCurrency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  void _showSettingsDialog(
    BuildContext context,
    ElectricityBillProvider provider,
  ) {
    final normalCtrl = TextEditingController(
      text: provider.normalRate.toString(),
    );
    final offPeakCtrl = TextEditingController(
      text: provider.offPeakRate.toString(),
    );
    final peakCtrl = TextEditingController(text: provider.peakRate.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cài đặt giá điện'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: normalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Giá bình thường (VNĐ)',
                ),
              ),
              TextField(
                controller: offPeakCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Giá thấp điểm (VNĐ)',
                ),
              ),
              TextField(
                controller: peakCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Giá cao điểm (VNĐ)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final normal = parseLocalizedDouble(normalCtrl.text);
                final offPeak = parseLocalizedDouble(offPeakCtrl.text);
                final peak = parseLocalizedDouble(peakCtrl.text);
                if (normal == null ||
                    offPeak == null ||
                    peak == null ||
                    normal <= 0 ||
                    offPeak <= 0 ||
                    peak <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đủ ba đơn giá lớn hơn 0.'),
                    ),
                  );
                  return;
                }
                provider.updateRates(normal, offPeak, peak);
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ElectricityBillProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tiền điện phải trả 1 ngày'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Cài đặt giá điện',
                onPressed: () => _showSettingsDialog(context, provider),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Chọn tên model máy',
                    border: OutlineInputBorder(),
                  ),
                  items: powerConsumptionData.keys.map((String model) {
                    return DropdownMenuItem<String>(
                      value: model,
                      child: Text(model),
                    );
                  }).toList(),
                  onChanged: provider.setModel,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'Số giờ chạy bình thường (${provider.normalRate.toInt()} đồng/kWh)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: provider.setNormalHours,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'Số giờ chạy thấp điểm (${provider.offPeakRate.toInt()} đồng/kWh)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: provider.setOffPeakHours,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'Số giờ chạy cao điểm (${provider.peakRate.toInt()} đồng/kWh)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: provider.setPeakHours,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    provider.calculate();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                if (provider.errorMessage != null)
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                if (provider.totalHours != null && provider.totalBill != null)
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
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng số giờ vận hành/ngày:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                '${provider.totalHours} giờ',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tiền điện phải trả:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                formatCurrency.format(provider.totalBill),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '* Số tiền chỉ mang tính tham khảo, chưa bao gồm VAT',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
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
