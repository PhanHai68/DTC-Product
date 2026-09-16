import 'package:flutter/material.dart';

import '../core/input/localized_number.dart';

class ProcessingProfitProvider extends ChangeNotifier {
  double _processingPrice = 0;
  double _dailySalary = 0;

  double? _totalProfit;
  double? get totalProfit => _totalProfit;

  void setProcessingPrice(String val) {
    _processingPrice = (parseLocalizedDouble(val) ?? 0) * 1000;
  }

  void setDailySalary(String val) {
    _dailySalary = (parseLocalizedDouble(val) ?? 0) * 1000;
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

  void resetSession() {
    _processingPrice = 0;
    _dailySalary = 0;
    _totalProfit = null;
    notifyListeners();
  }
}
