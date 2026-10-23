import 'package:flutter/material.dart';

import '../core/input/localized_number.dart';

class ProcessingProfitProvider extends ChangeNotifier {
  double _processingPrice = 0;
  double _dailySalary = 0;

  double? _totalProfit;
  double? get totalProfit => _totalProfit;

  /// Số liệu của lần tính gần nhất, để giải thích công thức trên màn hình.
  ProcessingProfitInputs? _lastInputs;
  ProcessingProfitInputs? get lastInputs => _lastInputs;

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
    _lastInputs = (
      processingPrice: _processingPrice,
      dailySalary: _dailySalary,
      capacity: capacity,
      totalHours: totalHours,
      totalBill: totalBill,
      revenue: revenue,
    );
    notifyListeners();
  }

  void resetSession() {
    _processingPrice = 0;
    _dailySalary = 0;
    _totalProfit = null;
    _lastInputs = null;
    notifyListeners();
  }
}

/// Đơn vị: giá gia công VNĐ/tấn, lương VNĐ/ngày, năng suất tấn/h.
typedef ProcessingProfitInputs = ({
  double processingPrice,
  double dailySalary,
  double capacity,
  double totalHours,
  double totalBill,
  double revenue,
});
