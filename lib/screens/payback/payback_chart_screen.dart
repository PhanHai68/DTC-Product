import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/processing_profit_provider.dart';
import '../../providers/self_business_provider.dart';
import '../../providers/payback_period_provider.dart';

class PaybackChartScreen extends StatelessWidget {
  const PaybackChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VNĐ',
      decimalDigits: 0,
    );

    final processingProvider = Provider.of<ProcessingProfitProvider>(context);
    final selfBusinessProvider = Provider.of<SelfBusinessProvider>(context);
    final paybackPeriodProvider = Provider.of<PaybackPeriodProvider>(context);

    double processingProfit = processingProvider.totalProfit ?? 0;
    double selfBusinessProfit = selfBusinessProvider.netProfit ?? 0;
    double totalInvestment = paybackPeriodProvider.machinePrice;

    // Tránh lỗi chia cho 0
    if (processingProfit <= 0) processingProfit = 0.001;
    if (selfBusinessProfit <= 0) selfBusinessProfit = 0.001;

    final processingPaybackDays = (totalInvestment / processingProfit)
        .ceilToDouble();
    double maxDays = processingPaybackDays;
    double selfBusinessDays = (totalInvestment / selfBusinessProfit)
        .ceilToDouble();
    if (selfBusinessDays > maxDays) maxDays = selfBusinessDays;

    // Thêm khoảng đệm cho trục X
    maxDays = maxDays * 1.2;
    if (maxDays < 30) maxDays = 30; // Tối thiểu 30 ngày

    return Scaffold(
      appBar: AppBar(title: const Text('Biểu đồ Hoàn Vốn')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông số dùng để so sánh:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildLegendItem(
                      Colors.blue,
                      'Lợi nhuận Gia công: ${formatCurrency.format(processingProvider.totalProfit ?? 0)}/ngày',
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      Colors.orange,
                      'Lợi nhuận Tự kinh doanh: ${formatCurrency.format(selfBusinessProvider.netProfit ?? 0)}/ngày',
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      Colors.red,
                      'Tổng đầu tư (Giá máy): ${formatCurrency.format(totalInvestment)}',
                      isDashed: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Biểu đồ Tích lũy Lợi nhuận (Theo Ngày)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Semantics(
              label:
                  'Biểu đồ tích lũy lợi nhuận theo ngày, đầu tư '
                  '${formatCurrency.format(totalInvestment)}. '
                  'Hoàn vốn theo gia công sau khoảng '
                  '${processingPaybackDays.toStringAsFixed(0)} ngày, '
                  'theo tự kinh doanh sau khoảng '
                  '${selfBusinessDays.toStringAsFixed(0)} ngày.',
              child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.45).clamp(
                260.0,
                400.0,
              ),
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  minX: 0,
                  maxX: maxDays,
                  minY: 0,
                  maxY: totalInvestment * 1.5,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: totalInvestment / 5 > 0
                        ? totalInvestment / 5
                        : 1000000,
                    verticalInterval: maxDays / 5 > 0 ? maxDays / 5 : 10,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == maxDays) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${value.toInt()}'),
                          );
                        },
                      ),
                      axisNameWidget: const Text('Số ngày'),
                      axisNameSize: 20,
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          if (value >= 1000000000) {
                            return Text(
                              '${(value / 1000000000).toStringAsFixed(1)}Tỷ',
                              style: const TextStyle(fontSize: 10),
                            );
                          } else if (value >= 1000000) {
                            return Text(
                              '${(value / 1000000).toStringAsFixed(0)}Tr',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                      axisNameWidget: const Text('VNĐ'),
                      axisNameSize: 20,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.black12),
                  ),
                  lineBarsData: [
                    // Đường Gia công
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 0),
                        FlSpot(
                          totalInvestment / processingProfit,
                          totalInvestment,
                        ),
                        FlSpot(maxDays, processingProfit * maxDays),
                      ],
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) =>
                            spot.y == totalInvestment,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: Colors.blue,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                      ),
                    ),
                    // Đường Tự kinh doanh
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 0),
                        FlSpot(
                          totalInvestment / selfBusinessProfit,
                          totalInvestment,
                        ),
                        FlSpot(maxDays, selfBusinessProfit * maxDays),
                      ],
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) =>
                            spot.y == totalInvestment,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: Colors.orange,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: totalInvestment,
                        color: Colors.red,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          labelResolver: (line) => 'Mốc Tổng Đầu Tư',
                        ),
                      ),
                    ],
                    verticalLines: [
                      VerticalLine(
                        x: totalInvestment / processingProfit,
                        color: Colors.blue.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.bottomRight,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            backgroundColor: Colors.white70,
                          ),
                          labelResolver: (line) =>
                              '${line.x.toInt()} ngày\nHoà vốn GC',
                        ),
                      ),
                      VerticalLine(
                        x: totalInvestment / selfBusinessProfit,
                        color: Colors.orange.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.bottomRight,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            backgroundColor: Colors.white70,
                          ),
                          labelResolver: (line) =>
                              '${line.x.toInt()} ngày\nHoà vốn TKD',
                        ),
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) =>
                          Colors.blueGrey.withValues(alpha: 0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final textStyle = TextStyle(
                            color: touchedSpot.bar.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          );
                          String title = touchedSpot.bar.color == Colors.blue
                              ? 'Gia công'
                              : 'Tự KD';
                          return LineTooltipItem(
                            '$title\nNgày ${touchedSpot.x.toInt()}: ${formatCurrency.format(touchedSpot.y)}',
                            textStyle,
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, {bool isDashed = false}) {
    return Row(
      children: [
        if (isDashed)
          SizedBox(
            width: 20,
            child: Text(
              '- - -',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          )
        else
          Container(width: 20, height: 4, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
