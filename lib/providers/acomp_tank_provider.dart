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
  static const maxSupportedVolume = 3000.0;

  void setQc(String value) {
    _qc = value.trim().isEmpty ? 0 : parseLocalizedDouble(value) ?? double.nan;
    notifyListeners();
  }

  void setTc(String value) {
    _tc = parseLocalizedDouble(value) ?? double.nan;
    notifyListeners();
  }

  void setDeltaP(String value) {
    _deltaP = parseLocalizedDouble(value) ?? double.nan;
    notifyListeners();
  }

  void setT0(String value) {
    _t0 = parseLocalizedDouble(value) ?? double.nan;
    notifyListeners();
  }

  void setT1(String value) {
    _t1 = parseLocalizedDouble(value) ?? double.nan;
    notifyListeners();
  }

  String? get inputError {
    if (![_qc, _tc, _deltaP, _t0, _t1].every((value) => value.isFinite)) {
      return 'Vui lòng nhập đầy đủ thông số bằng số hữu hạn.';
    }
    if (_qc < 0 || _tc <= 0 || _deltaP <= 0) {
      return 'Lưu lượng không được âm; thời gian chu kỳ và độ chênh áp phải lớn hơn 0.';
    }
    if (_t0 <= -273.15 || _t1 <= -273.15) {
      return 'Nhiệt độ phải lớn hơn -273,15 °C.';
    }
    return null;
  }

  // V_th = (0.25 * (Q_c * 1000) * (T_0 + 273.15)) /
  //        ((60 / t_c) * ΔP * (T_1 + 273.15)), đơn vị lít.
  double get vTh {
    if (inputError != null) return 0;
    final numerator = 0.25 * (_qc * 1000) * (_t0 + 273.15);
    final denominator = (60 / _tc) * _deltaP * (_t1 + 273.15);
    return numerator / denominator;
  }

  String? get recommendationError {
    if (inputError != null) return inputError;
    if (!vTh.isFinite || (_qc > 0 && vTh <= 0)) {
      return 'Kết quả tính dung tích không hợp lệ. Vui lòng kiểm tra đầu vào.';
    }
    if (vTh > maxSupportedVolume) {
      return 'Dung tích lý thuyết vượt 3.000 lít, ngoài dải lựa chọn hiện có. Cần tư vấn cấu hình bình chứa riêng.';
    }
    return null;
  }

  // Giữ bảng lựa chọn hiện có trong dải hỗ trợ.
  double? get vRec {
    if (recommendationError != null) return null;
    final v = vTh;
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
