import 'package:flutter/material.dart';
import '../data/power_consumption_data.dart';

class PowerConsumptionProvider extends ChangeNotifier {
  List<Map<String, String>>? _specs;
  List<Map<String, String>>? get specs => _specs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void selectModel(String modelName) {
    if (modelName.trim().isEmpty) {
      _errorMessage = 'Vui lòng chọn tên model';
      _specs = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (powerConsumptionData.containsKey(modelName)) {
        _specs = powerConsumptionData[modelName];
      } else {
        _specs = null;
        _errorMessage = 'Không tìm thấy thông số cho model "$modelName"';
      }
    } catch (e) {
      _specs = null;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
