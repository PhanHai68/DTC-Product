import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/processing_profit_provider.dart';
import '../../providers/payback_period_provider.dart';

class PaybackPeriodScreen extends StatefulWidget {
  const PaybackPeriodScreen({super.key});

  @override
  State<PaybackPeriodScreen> createState() => _PaybackPeriodScreenState();
}

class _PaybackPeriodScreenState extends State<PaybackPeriodScreen> {
  final formatCurrency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin lợi nhuận từ mục trước
    final profitProvider = Provider.of<ProcessingProfitProvider>(
      context,
      listen: false,
    );
    final totalProfit = profitProvider.totalProfit ?? 0;

    return Consumer<PaybackPeriodProvider>(
      builder: (context, paybackProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Khấu hao / Hoàn vốn')),
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
                          'Lợi nhuận gia công 1 ngày đã tính:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          formatCurrency.format(totalProfit),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Nhập giá máy tách màu (VNĐ)',
                    border: OutlineInputBorder(),
                    suffixText: ',000',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: paybackProvider.setMachinePrice,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Nhập giá trọn cụm thiết bị (VNĐ)',
                    border: OutlineInputBorder(),
                    suffixText: ',000',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: paybackProvider.setFullSetupPrice,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    paybackProvider.calculate(totalProfit);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                if (paybackProvider.machinePaybackDays != null &&
                    paybackProvider.fullSetupPaybackDays != null)
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
                              const Expanded(
                                child: Text(
                                  'Hoàn vốn (Chỉ máy):',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Text(
                                paybackProvider.machinePaybackDays ==
                                            double.infinity ||
                                        paybackProvider.machinePaybackDays! < 0
                                    ? 'Không thể hoàn vốn'
                                    : '${paybackProvider.machinePaybackDays!.toStringAsFixed(1)} ngày',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Hoàn vốn (Trọn cụm):',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Text(
                                paybackProvider.fullSetupPaybackDays ==
                                            double.infinity ||
                                        paybackProvider.fullSetupPaybackDays! <
                                            0
                                    ? 'Không thể hoàn vốn'
                                    : '${paybackProvider.fullSetupPaybackDays!.toStringAsFixed(1)} ngày',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
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
