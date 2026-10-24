import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/processing_profit_provider.dart';
import '../../providers/payback_period_provider.dart';
import '../../core/input/localized_number.dart';
import '../../widgets/money_form_field.dart';
import '../../widgets/payback/formula_explainer.dart';

class PaybackPeriodScreen extends StatefulWidget {
  const PaybackPeriodScreen({super.key});

  @override
  State<PaybackPeriodScreen> createState() => _PaybackPeriodScreenState();
}

class _PaybackPeriodScreenState extends State<PaybackPeriodScreen> {
  final _formKey = GlobalKey<FormState>();
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
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hiển thị thông số đã lấy từ mục trước
                Card(
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
                MoneyFormField(
                  labelText: 'Giá máy tách màu (VNĐ)',
                  onChanged: paybackProvider.setMachinePrice,
                  validator: (value) => validateRequiredPositiveNumber(
                    value,
                    label: 'giá máy tách màu',
                  ),
                ),
                const SizedBox(height: 16),
                MoneyFormField(
                  labelText: 'Giá trọn cụm thiết bị (VNĐ)',
                  onChanged: paybackProvider.setFullSetupPrice,
                  validator: (value) => validateRequiredPositiveNumber(
                    value,
                    label: 'giá trọn cụm thiết bị',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (!_formKey.currentState!.validate()) return;
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
                const SizedBox(height: 16),
                _buildFormula(paybackProvider),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormula(PaybackPeriodProvider provider) {
    final inputs = provider.lastInputs;
    final machineDays = provider.machinePaybackDays;
    final fullSetupDays = provider.fullSetupPaybackDays;
    final c = formatCurrency.format;
    final List<String> workings;
    if (inputs == null || machineDays == null || fullSetupDays == null) {
      workings = const [];
    } else if (inputs.totalProfit <= 0) {
      workings = [
        'Lợi nhuận gia công/ngày = ${c(inputs.totalProfit)} ≤ 0 nên không '
            'thể hoàn vốn.',
      ];
    } else {
      workings = [
        'Chỉ máy = ${c(inputs.machinePrice)} ÷ ${c(inputs.totalProfit)}/ngày '
            '= ${machineDays.toStringAsFixed(1)} ngày',
        'Trọn cụm = ${c(inputs.fullSetupPrice)} ÷ '
            '${c(inputs.totalProfit)}/ngày '
            '= ${fullSetupDays.toStringAsFixed(1)} ngày',
      ];
    }
    return FormulaExplainer(
      formulas: const [
        'Số ngày hoàn vốn (chỉ máy) = Giá máy tách màu ÷ Lợi nhuận gia '
            'công/ngày',
        'Số ngày hoàn vốn (trọn cụm) = Giá trọn cụm thiết bị ÷ Lợi nhuận gia '
            'công/ngày',
      ],
      workings: workings,
      notes: const [
        'Lợi nhuận gia công/ngày lấy từ bước 3. Lợi nhuận ≤ 0 thì không thể '
            'hoàn vốn.',
        'Kết quả làm tròn 1 chữ số thập phân.',
      ],
    );
  }
}
