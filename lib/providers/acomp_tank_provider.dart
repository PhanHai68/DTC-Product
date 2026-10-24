import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/input/localized_number.dart';
import '../data/product_data.dart';
import '../models/air_tank_spec.dart';

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

  /// Bình lớn nhất trong bảng tiêu chuẩn; lớn hơn thì cần tư vấn riêng.
  static double get maxSupportedVolume => airTankSpecs.last.volumeLiters;

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
      final max = NumberFormat('#,##0', 'vi').format(maxSupportedVolume);
      return 'Dung tích lý thuyết vượt $max lít, ngoài dải lựa chọn hiện có. Cần tư vấn cấu hình bình chứa riêng.';
    }
    return null;
  }

  /// Bình tiêu chuẩn nhỏ nhất có dung tích không nhỏ hơn dung tích lý
  /// thuyết; `null` khi đầu vào sai, vượt dải hoặc lưu lượng bằng 0.
  AirTankSpec? get recommendedTank {
    if (recommendationError != null || vTh <= 0) return null;
    return airTankSpecs.where((t) => t.volumeLiters >= vTh).firstOrNull;
  }

  /// Dung tích bình đề xuất (lít); 0 khi lưu lượng bằng 0.
  double? get vRec {
    if (recommendationError != null) return null;
    if (vTh <= 0) return 0;
    return recommendedTank?.volumeLiters;
  }
}
