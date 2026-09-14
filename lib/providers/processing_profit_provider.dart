import 'package:flutter/material.dart';

class ProcessingProfitProvider extends ChangeNotifier {
  double _processingPrice = 0;
  double _dailySalary = 0;

  double? _totalProfit;
  double? get totalProfit => _totalProfit;

  void setProcessingPrice(String val) {
    _processingPrice = (double.tryParse(val) ?? 0) * 1000;
  }

  void setDailySalary(String val) {
    _dailySalary = (double.tryParse(val) ?? 0) * 1000;
  }

  void calculate({
    required double capacity,
    required double totalHours,
    required double totalBill,
  }) {
    // Tổng lợi nhuận = (Giá gia công 1 tấn x Năng suất x Số giờ) - Tiền điện - Tiền lương
    double revenue = _processingPrice * capacity * totalHours;
    _totalProfit = (revenue - totalBill - _dailySalary).roundToDouble();
    notifyListeners();
  }
}
