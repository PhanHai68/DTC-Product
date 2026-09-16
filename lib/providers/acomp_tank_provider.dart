import 'package:flutter/material.dart';

import '../core/input/localized_number.dart';

class AcompTankProvider extends ChangeNotifier {
  double _qc = 0.0; // Lưu lượng máy nén khí (m³/min)
  double _tc = 20.0; // Thời gian chu kỳ nạp/xả (s)
  double _deltaP = 0.5; // Độ chênh áp (bar)
  double _t0 = 45.0; // Nhiệt độ trong bình chứa (°C)
  double _t1 = 35.0; // Nhiệt độ tại đầu hút (°C)

  double get qc => _qc;
  double get tc => _tc;
  double get deltaP => _deltaP;
  double get t0 => _t0;
  double get t1 => _t1;

  void setQc(String value) {
    _qc = parseLocalizedDouble(value) ?? 0.0;
    notifyListeners();
  }

  void setTc(String value) {
    _tc = parseLocalizedDouble(value) ?? 20.0;
    notifyListeners();
  }

  void setDeltaP(String value) {
    _deltaP = parseLocalizedDouble(value) ?? 0.5;
    notifyListeners();
  }

  void setT0(String value) {
    _t0 = parseLocalizedDouble(value) ?? 45.0;
    notifyListeners();
  }

  void setT1(String value) {
    _t1 = parseLocalizedDouble(value) ?? 35.0;
    notifyListeners();
  }

  // Dung tích lý thuyết (V_th) theo Lít
  // V_th = (0.25 * (Q_c * 1000) * (T_0 + 273.15)) / ((60 / t_c) * ΔP * (T_1 + 273.15))
  double get vTh {
    if (_tc <= 0 || _deltaP <= 0) return 0.0; // Tránh chia cho 0
    double numerator = 0.25 * (_qc * 1000) * (_t0 + 273.15);
    double denominator = (60 / _tc) * _deltaP * (_t1 + 273.15);
    return numerator / denominator;
  }

  // Bình tiêu chuẩn (V_rec) theo Lít
  double get vRec {
    double v = vTh;
    if (v <= 0) return 0;
    if (v <= 250) return 200;
    if (v <= 400) return 300;
    if (v <= 600) return 500;
    if (v <= 850) return 700;
    if (v <= 1250) return 1000;
    if (v <= 1750) return 1500;
    if (v <= 2500) return 2000;
    return 3000;
  }
}
