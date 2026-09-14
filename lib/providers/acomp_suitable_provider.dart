import 'package:flutter/material.dart';
import '../models/material_model.dart';

class AcompSuitableProvider extends ChangeNotifier {
  MaterialModel? _selectedMaterial;
  int _ejectorCount = 0;

  MaterialModel? get selectedMaterial => _selectedMaterial;
  int get ejectorCount => _ejectorCount;

  // Q_req = (Số béc * Cm) / 1000
  double get qReq {
    if (_selectedMaterial == null || _ejectorCount == 0) return 0;
    return (_ejectorCount * _selectedMaterial!.cm) / 1000;
  }

  // Q_comp = Q_req * 1.3
  double get qComp {
    return qReq * 1.3;
  }

  // Công suất đề xuất
  double get minPower {
    double p = qComp * 6.2;
    if (p <= 0) return 0;
    if (p <= 11) return 11;
    if (p <= 15) return 15;
    if (p <= 22) return 22;
    if (p <= 37) return 37;
    if (p <= 45) return 45;
    if (p <= 55) return 55;
    if (p <= 75) return 75;
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
