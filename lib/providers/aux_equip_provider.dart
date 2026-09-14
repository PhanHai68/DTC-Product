import 'package:flutter/material.dart';

import '../data/aux_equip_data.dart';

class AuxEquipProvider extends ChangeNotifier {
  List<Map<String, String>>? _specs;
  List<Map<String, String>>? get specs => _specs;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void selectModel(String modelName) {
    if (modelName.trim().isEmpty) {
      _errorMessage = 'Vui lòng chọn tên model';
      _specs = null;
      _selectedModel = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String cleanModel = modelName.trim();
      if (!auxEquipSpecsByModel.containsKey(cleanModel)) {
        final matchedKey = auxEquipSpecsByModel.keys.firstWhere(
          (k) =>
              cleanModel.toLowerCase().contains(k.toLowerCase()) ||
              k.toLowerCase().contains(cleanModel.toLowerCase()),
          orElse: () => '',
        );
        if (matchedKey.isNotEmpty) {
          cleanModel = matchedKey;
        }
      }

      if (auxEquipSpecsByModel.containsKey(cleanModel)) {
        _specs = auxEquipSpecsByModel[cleanModel];
        _selectedModel = cleanModel;
      } else {
        _specs = null;
        _selectedModel = null;
        _errorMessage =
            'Không tìm thấy thiết bị phụ trợ cho model "$modelName"';
      }
    } catch (e) {
      _specs = null;
      _selectedModel = null;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
