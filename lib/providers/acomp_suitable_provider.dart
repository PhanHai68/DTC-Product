import 'package:flutter/material.dart';

import '../models/material_model.dart';

class AcompSuitableProvider extends ChangeNotifier {
  MaterialModel? _selectedMaterial;
  int _ejectorCount = 0;

  MaterialModel? get selectedMaterial => _selectedMaterial;
  int get ejectorCount => _ejectorCount;
  static const maxSupportedPower = 90.0;

  // Q_req = (Số béc * Cm) / 1000
  double get qReq {
    if (_selectedMaterial == null || _ejectorCount == 0) return 0;
    return (_ejectorCount * _selectedMaterial!.cm) / 1000;
  }

  // Q_comp = Q_req * 1.3
  double get qComp => qReq * 1.3;
  double get requiredPower => qComp * 6.2;

  String? get recommendationError {
    if (_selectedMaterial == null) return null;
    if (!_selectedMaterial!.cm.isFinite ||
        _selectedMaterial!.cm <= 0 ||
        _ejectorCount < 0) {
      return 'Thông số tiêu hao khí và số béc chưa hợp lệ.';
    }
    if (!requiredPower.isFinite) {
      return 'Kết quả tính công suất không hợp lệ. Vui lòng kiểm tra đầu vào.';
    }
    if (!_fitsPower(requiredPower, maxSupportedPower)) {
      return 'Nhu cầu công suất tính toán vượt 90 kW, ngoài dải lựa chọn hiện có. Cần tư vấn cấu hình máy nén riêng.';
    }
    return null;
  }

  // Chỉ bù sai số tính toán số thực tại các ngưỡng, không làm tròn đầu vào.
  bool _fitsPower(double power, double limit) =>
      power <= limit || power - limit <= limit * 1e-12;

  // Không ép nhu cầu vượt dải về máy lớn nhất.
  double? get minPower {
    if (recommendationError != null) return null;
    final p = requiredPower;
    if (p <= 0) return 0;
    if (_fitsPower(p, 11)) return 11;
    if (_fitsPower(p, 15)) return 15;
    if (_fitsPower(p, 22)) return 22;
    if (_fitsPower(p, 37)) return 37;
    if (_fitsPower(p, 45)) return 45;
    if (_fitsPower(p, 55)) return 55;
    if (_fitsPower(p, 75)) return 75;
    return 90;
  }

  void setMaterial(MaterialModel? material) {
    _selectedMaterial = material;
    notifyListeners();
  }

  void setEjectorCount(String value) {
    _ejectorCount = int.tryParse(value) ?? 0;
    notifyListeners();
  }
}
