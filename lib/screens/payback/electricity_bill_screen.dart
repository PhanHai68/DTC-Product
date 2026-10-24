import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/electricity_bill_provider.dart';
import '../../data/product_data.dart';
import '../../core/input/localized_number.dart';
import '../../widgets/money_form_field.dart';
import '../../widgets/payback/formula_explainer.dart';

import 'package:intl/intl.dart';

class ElectricityBillScreen extends StatefulWidget {
  const ElectricityBillScreen({super.key, this.line = ColorSorterLine.rice});

  /// Dòng máy đang phân tích: chỉ liệt kê model của dòng này.
  final ColorSorterLine line;

  @override
  State<ElectricityBillScreen> createState() => _ElectricityBillScreenState();
}

class _ElectricityBillScreenState extends State<ElectricityBillScreen> {
  final _formKey = GlobalKey<FormState>();
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
      text: formatThousands(provider.normalRate),
    );
    final offPeakCtrl = TextEditingController(
      text: formatThousands(provider.offPeakRate),
    );
    final peakCtrl = TextEditingController(
      text: formatThousands(provider.peakRate),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cài đặt giá điện'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyFormField(
                controller: normalCtrl,
                labelText: 'Giá bình thường (VNĐ/kWh)',
                unit: 'VNĐ/kWh',
                border: null,
              ),
              MoneyFormField(
                controller: offPeakCtrl,
                labelText: 'Giá thấp điểm (VNĐ/kWh)',
                unit: 'VNĐ/kWh',
                border: null,
              ),
              MoneyFormField(
                controller: peakCtrl,
                labelText: 'Giá cao điểm (VNĐ/kWh)',
                unit: 'VNĐ/kWh',
                border: null,
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
                final normal = parseLocalizedDouble(
                  stripThousandsSeparators(normalCtrl.text),
                );
                final offPeak = parseLocalizedDouble(
                  stripThousandsSeparators(offPeakCtrl.text),
                );
                final peak = parseLocalizedDouble(
                  stripThousandsSeparators(peakCtrl.text),
                );
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
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Chọn tên model máy',
                    border: OutlineInputBorder(),
                  ),
                  items: powerConsumptionModels(widget.line).map((
                    String model,
                  ) {
                    return DropdownMenuItem<String>(
                      value: model,
                      child: Text(model),
                    );
                  }).toList(),
                  onChanged: provider.setModel,
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn model máy' : null,
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
                  validator: validateHoursInRange,
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
                  validator: validateHoursInRange,
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
                  validator: validateHoursInRange,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (!_formKey.currentState!.validate()) return;
                    final totalInputHours =
                        provider.normalHours +
                        provider.offPeakHours +
                        provider.peakHours;
                    if (totalInputHours > 24) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tổng số giờ chạy 3 khung không được vượt quá 24 giờ/ngày.',
                          ),
                        ),
                      );
                      return;
                    }
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
                const SizedBox(height: 16),
                _buildFormula(provider),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormula(ElectricityBillProvider provider) {
    final inputs = provider.lastInputs;
    final totalBill = provider.totalBill;
    const n = formulaNumber;
    return FormulaExplainer(
      formulas: const [
        'Tổng giờ/ngày = Giờ bình thường + Giờ thấp điểm + Giờ cao điểm',
        'Tiền điện/ngày = Công suất (kW) × (Giờ bình thường × Giá bình thường '
            '+ Giờ thấp điểm × Giá thấp điểm + Giờ cao điểm × Giá cao điểm)',
      ],
      workings: inputs == null || totalBill == null
          ? const []
          : [
              'Công suất ${inputs.averagePower ? 'trung bình' : 'lớn nhất'} '
                  'của model: ${n(inputs.powerKw)} kW',
              'Tổng giờ = ${n(inputs.normalHours)} + ${n(inputs.offPeakHours)} '
                  '+ ${n(inputs.peakHours)} = ${n(provider.totalHours!)} giờ',
              'Tiền điện = ${n(inputs.powerKw)} × '
                  '(${n(inputs.normalHours)} × ${n(inputs.normalRate)} '
                  '+ ${n(inputs.offPeakHours)} × ${n(inputs.offPeakRate)} '
                  '+ ${n(inputs.peakHours)} × ${n(inputs.peakRate)}) '
                  '= ${formatCurrency.format(totalBill)}',
            ],
      notes: const [
        'Công suất lấy theo công suất trung bình của model; model chưa có số '
            'liệu trung bình thì lấy công suất lớn nhất.',
        'Đơn giá điện (VNĐ/kWh) chỉnh ở nút Cài đặt. Kết quả làm tròn đến đồng.',
      ],
    );
  }
}
