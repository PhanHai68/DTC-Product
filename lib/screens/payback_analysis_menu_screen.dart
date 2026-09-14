import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/electricity_bill_provider.dart';
import '../providers/processing_profit_provider.dart';
import '../providers/self_business_provider.dart';
import '../providers/payback_period_provider.dart';

class PaybackAnalysisMenuScreen extends StatelessWidget {
  const PaybackAnalysisMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ElectricityBillProvider>(
      builder: (context, electricityProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Phân Tích Hoàn Vốn')),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildMenuItem(
                context,
                title: '1. Công suất tiêu thụ',
                icon: Icons.bolt,
                onTap: () {
                  context.push('/power_consumption');
                },
              ),
              _buildMenuItem(
                context,
                title: '2. Tiền điện phải trả 1 ngày',
                icon: Icons.payments,
                onTap: () {
                  context.push('/electricity_bill');
                },
              ),
              _buildMenuItem(
                context,
                title: '3. Lợi nhuận gia công',
                icon: Icons.trending_up,
                onTap: () {
                  if (electricityProvider.totalBill == null) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Không thể đăng nhập',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Bạn cần phải tính Tiền điện phải trả 1 ngày trước',
                          style: TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Đã hiểu',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    context.push('/processing_profit');
                  }
                },
              ),
              _buildMenuItem(
                context,
                title: '4. Tính khấu hao/ hoàn vốn theo ngày',
                icon: Icons.calculate,
                onTap: () {
                  final profitProvider = Provider.of<ProcessingProfitProvider>(
                    context,
                    listen: false,
                  );
                  if (electricityProvider.totalBill == null ||
                      profitProvider.totalProfit == null) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Không thể truy cập',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Bạn cần phải tính Tiền điện phải trả 1 ngày và Lợi nhuận gia công trước',
                          style: TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Đã hiểu',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    context.push('/payback_period');
                  }
                },
              ),
              _buildMenuItem(
                context,
                title: '5. Doanh thu tự kinh doanh',
                icon: Icons.storefront,
                onTap: () {
                  if (electricityProvider.totalBill == null) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Không thể truy cập',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Bạn cần phải tính Tiền điện phải trả 1 ngày trước',
                          style: TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Đã hiểu',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    context.push('/self_business');
                  }
                },
              ),
              _buildMenuItem(
                context,
                title: '6. Biểu đồ Hoàn Vốn',
                icon: Icons.show_chart,
                onTap: () {
                  final processingProvider =
                      Provider.of<ProcessingProfitProvider>(
                        context,
                        listen: false,
                      );
                  final selfBusinessProvider =
                      Provider.of<SelfBusinessProvider>(context, listen: false);
                  final paybackPeriodProvider =
                      Provider.of<PaybackPeriodProvider>(
                        context,
                        listen: false,
                      );

                  if (processingProvider.totalProfit == null ||
                      selfBusinessProvider.netProfit == null ||
                      paybackPeriodProvider.machinePrice == 0) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Thiếu thông số',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Bạn cần phải tính "Lợi nhuận gia công", "Khấu hao" và "Doanh thu tự kinh doanh" trước để có số liệu vẽ biểu đồ.',
                          style: TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Đã hiểu',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    context.push('/payback_chart');
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '* Lưu ý: Vui lòng thực hiện tính toán theo thứ tự từ mục 2 đến mục 6 để có đầy đủ dữ liệu phân tích.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              onTap ??
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng đang được phát triển'),
                  ),
                );
              },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 20.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.blue[800], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
