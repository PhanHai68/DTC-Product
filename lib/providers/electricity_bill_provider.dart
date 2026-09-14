import 'package:flutter/material.dart';
import '../data/power_consumption_data.dart';

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

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setModel(String? model) {
    _selectedModel = model;
    notifyListeners();
  }

  void setNormalHours(String val) {
    _normalHours = double.tryParse(val) ?? 0;
  }

  void setOffPeakHours(String val) {
    _offPeakHours = double.tryParse(val) ?? 0;
  }

  void setPeakHours(String val) {
    _peakHours = double.tryParse(val) ?? 0;
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
      var specs = powerConsumptionData[_selectedModel];
      if (specs == null) {
        _errorMessage = 'Không tìm thấy dữ liệu cho model này';
        _totalHours = null;
        _totalBill = null;
        notifyListeners();
        return;
      }

      var avgPowerStr = specs.firstWhere((e) => e['Tiêu chí'] == 'Công suất trung bình (kW)')['Thông số'] ?? '0';
      double averagePower = double.tryParse(avgPowerStr) ?? 0;

      _totalHours = _normalHours + _offPeakHours + _peakHours;
      double rawBill = averagePower * (_normalHours * normalRate + _offPeakHours * offPeakRate + _peakHours * peakRate);
      _totalBill = rawBill.roundToDouble(); // làm tròn kết quả
    } catch (e) {
      _errorMessage = 'Lỗi tính toán: ${e.toString()}';
      _totalHours = null;
      _totalBill = null;
    }
    notifyListeners();
  }
}
