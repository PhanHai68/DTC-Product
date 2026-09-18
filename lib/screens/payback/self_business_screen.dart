import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/electricity_bill_provider.dart';
import '../../providers/self_business_provider.dart';
import '../../core/input/localized_number.dart';
import '../../data/power_consumption_data.dart';

class SelfBusinessScreen extends StatefulWidget {
  const SelfBusinessScreen({super.key});

  @override
  State<SelfBusinessScreen> createState() => _SelfBusinessScreenState();
}

class _SelfBusinessScreenState extends State<SelfBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final formatCurrency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final electricityProvider = Provider.of<ElectricityBillProvider>(
      context,
      listen: false,
    );
    // Lưu ý: lương nhân viên nằm trong ProcessingProfitProvider.
    // Tuy nhiên do có thể người dùng chưa nhập lương (hoặc vào thẳng đây sau khi đã tính điện + lợi nhuận),
    // ta lấy giá trị mặc định từ công thức, nhưng vì ta không lưu trữ công khai thuộc tính _dailySalary trong provider,
    // (tạm bỏ qua Lương nếu không lấy được, hoặc giả định công thức trong Excel là (B46+B47)-B45 không trừ lương).
    // Ở đây ta tính điện từ electricityProvider.
    final totalHours = electricityProvider.totalHours ?? 0;
    final totalBill = electricityProvider.totalBill ?? 0;
    final selectedModel = electricityProvider.selectedModel;

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

    return Consumer<SelfBusinessProvider>(
      builder: (context, businessProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Doanh thu tự kinh doanh')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hiển thị thông số cơ bản
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông số vận hành:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Model: ${selectedModel ?? "Chưa chọn"}'),
                        const SizedBox(height: 4),
                        Text('Năng suất tổng: $capacity Tấn/h'),
                        const SizedBox(height: 4),
                        Text(
                          'Năng suất thành phẩm: ${(capacity * 0.96875).toStringAsFixed(2)} Tấn/h',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Năng suất phế phẩm: ${(capacity * 0.03125).toStringAsFixed(2)} Tấn/h',
                        ),
                        const SizedBox(height: 4),
                        Text('Tổng số giờ vận hành/ngày: $totalHours giờ'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Giá Gạo nguyên liệu mua vào (VNĐ/kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: businessProvider.setRawMaterialPrice,
                  validator: (value) => validateRequiredPositiveNumber(
                    value,
                    label: 'giá nguyên liệu mua vào',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Giá Gạo thành phẩm bán ra (VNĐ/kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: businessProvider.setFinishedProductPrice,
                  validator: (value) => validateRequiredPositiveNumber(
                    value,
                    label: 'giá thành phẩm bán ra',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Giá Gạo phế phẩm bán ra (VNĐ/kg)',
                    border: OutlineInputBorder(),
                    helperText: 'Nhập 0 nếu không bán phế phẩm',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LocalizedDecimalTextInputFormatter()],
                  onChanged: businessProvider.setByProductPrice,
                  validator: (value) => validateRequiredNonNegativeNumber(
                    value,
                    label: 'giá phế phẩm bán ra',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (!_formKey.currentState!.validate()) return;
                    businessProvider.calculate(
                      capacity: capacity,
                      totalHours: totalHours,
                      electricityBill: totalBill,
                      dailySalary: 0, // Tạm gán 0 nếu Excel thực tế tính (B46+B47)-B45 không dùng lương
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                if (businessProvider.netProfit != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Kết Quả',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(),
                          const SizedBox(height: 12),
                          _buildResultRow(
                            'Tổng Chi phí Mua Nguyên Liệu:',
                            businessProvider.costRawMaterial!,
                          ),
                          const SizedBox(height: 8),
                          _buildResultRow(
                            'Tổng Doanh thu Bán Thành Phẩm:',
                            businessProvider.revenueFinished!,
                          ),
                          const SizedBox(height: 8),
                          _buildResultRow(
                            'Tổng Doanh thu Bán Phế Phẩm:',
                            businessProvider.revenueByProduct!,
                          ),
                          const Divider(height: 24, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Lợi nhuận ròng Tự Kinh Doanh 1 ngày:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                formatCurrency.format(
                                  businessProvider.netProfit,
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: businessProvider.netProfit! >= 0
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
          ),
        );
      },
    );
  }

  Widget _buildResultRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          formatCurrency.format(value),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
