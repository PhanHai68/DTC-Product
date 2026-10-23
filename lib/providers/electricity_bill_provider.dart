import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../core/input/localized_number.dart';

class ElectricityBillProvider extends ChangeNotifier {
  String? _selectedModel;
  double _normalHours = 0;
  double _offPeakHours = 0;
  double _peakHours = 0;

  double normalRate = 1811;
  double offPeakRate = 1190;
  double peakRate = 3266;

  double? _totalHours;
  double? _totalBill;

  String? get selectedModel => _selectedModel;
  double? get totalHours => _totalHours;
  double? get totalBill => _totalBill;
  double get normalHours => _normalHours;
  double get offPeakHours => _offPeakHours;
  double get peakHours => _peakHours;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Số liệu của lần tính gần nhất, để giải thích công thức trên màn hình.
  ElectricityBillInputs? _lastInputs;
  ElectricityBillInputs? get lastInputs => _lastInputs;

  void setModel(String? model) {
    _selectedModel = model;
    notifyListeners();
  }

  void setNormalHours(String val) {
    _normalHours = parseLocalizedDouble(val) ?? 0;
  }

  void setOffPeakHours(String val) {
    _offPeakHours = parseLocalizedDouble(val) ?? 0;
  }

  void setPeakHours(String val) {
    _peakHours = parseLocalizedDouble(val) ?? 0;
  }

  void updateRates(double normal, double offPeak, double peak) {
    normalRate = normal;
    offPeakRate = offPeak;
    peakRate = peak;
    if (_totalHours != null) {
      calculate();
    } else {
      notifyListeners();
    }
  }

  void calculate() {
    if (_selectedModel == null || _selectedModel!.trim().isEmpty) {
      _errorMessage = 'Vui lòng chọn model máy';
      _totalHours = null;
      _totalBill = null;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    try {
      // Công suất trung bình; dây chuyền trà chưa có nên dùng công suất lớn nhất.
      final averagePower = billingPowerKw(_selectedModel!);
      if (averagePower == null) {
        _errorMessage = 'Không tìm thấy dữ liệu cho model này';
        _totalHours = null;
        _totalBill = null;
        notifyListeners();
        return;
      }

      _totalHours = _normalHours + _offPeakHours + _peakHours;
      double rawBill =
          averagePower *
          (_normalHours * normalRate +
              _offPeakHours * offPeakRate +
              _peakHours * peakRate);
      _totalBill = rawBill.roundToDouble(); // làm tròn kết quả
      _lastInputs = (
        powerKw: averagePower,
        averagePower: powerConsumptionData[_selectedModel!]!.any(
          (r) => r['Tiêu chí'] == 'Công suất trung bình (kW)',
        ),
        normalHours: _normalHours,
        offPeakHours: _offPeakHours,
        peakHours: _peakHours,
        normalRate: normalRate,
        offPeakRate: offPeakRate,
        peakRate: peakRate,
      );
    } catch (e) {
      _errorMessage = 'Lỗi tính toán: ${e.toString()}';
      _totalHours = null;
      _totalBill = null;
    }
    notifyListeners();
  }

  void resetSession() {
    _selectedModel = null;
    _normalHours = 0;
    _offPeakHours = 0;
    _peakHours = 0;
    _totalHours = null;
    _totalBill = null;
    _errorMessage = null;
    _lastInputs = null;
    notifyListeners();
  }
}

/// [averagePower] = `false` khi model không có công suất trung bình và phải
/// tính theo công suất lớn nhất.
typedef ElectricityBillInputs = ({
  double powerKw,
  bool averagePower,
  double normalHours,
  double offPeakHours,
  double peakHours,
  double normalRate,
  double offPeakRate,
  double peakRate,
});
