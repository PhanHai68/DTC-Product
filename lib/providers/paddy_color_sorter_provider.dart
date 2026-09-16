import 'package:flutter/material.dart';
import '../data/paddy_specs_data.dart';

class PaddyColorSorterProvider extends ChangeNotifier {
  Map<String, String>? _specs;
  Map<String, String>? get specs => _specs;

  String _selectedModel = 'SF7D Pro';
  String get selectedModel => _selectedModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PaddyColorSorterProvider() {
    selectModel('SF7D Pro');
  }

  void selectModel(String modelName) {
    _selectedModel = modelName;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final found = paddyColorSorterSpecs.firstWhere(
        (e) => (e['Model'] ?? '').toLowerCase() == modelName.toLowerCase(),
        orElse: () => <String, String>{},
      );

      if (found.isNotEmpty) {
        _specs = Map.fromEntries(
          found.entries.where((e) => e.value.trim().isNotEmpty && e.value != 'N/A'),
        );
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

  void search(String modelName) {
    if (modelName.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập tên model';
      _specs = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Map<String, String>? result;
      for (var row in paddyColorSorterSpecs) {
        if (row['Model']?.toLowerCase() == modelName.toLowerCase().trim()) {
          result = row;
          break;
        }
      }

      if (result == null) {
        for (var row in paddyColorSorterSpecs) {
          if (row['Model']?.toLowerCase().contains(modelName.toLowerCase().trim()) == true) {
            result = row;
            break;
          }
        }
      }

      if (result == null) {
        for (var row in paddyColorSorterSpecs) {
          bool matchFound = false;
          for (var value in row.values) {
            if (value.toLowerCase().contains(modelName.toLowerCase().trim())) {
              matchFound = true;
              break;
            }
          }
          if (matchFound) {
            result = row;
            break;
          }
        }
      }

      if (result != null) {
        _selectedModel = result['Model'] ?? '';
        _specs = Map.fromEntries(
          result.entries.where((e) => e.value.trim().isNotEmpty && e.value != 'N/A'),
        );
      } else {
        _specs = null;
        _errorMessage = 'Không tìm thấy model nào phù hợp với "$modelName"';
      }
    } catch (e) {
      _specs = null;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? suggestModelByCapacity(double requiredCapacity) {
    // SF7D Pro is 3.5 - 7 t/h. We only have 1 model.
    if (requiredCapacity <= 7) {
      return {
        'model': 'SF7D Pro',
        'reason': 'Năng suất yêu cầu $requiredCapacity tấn/h nằm trong khoảng 3.5 - 7 tấn/h của model SF7D Pro.'
      };
    }
    return null;
  }

  Map<String, String>? getSpecByModel(String modelName) {
    try {
      final found = paddyColorSorterSpecs.firstWhere(
        (e) => (e['Model'] ?? '').toLowerCase() == modelName.toLowerCase(),
        orElse: () => <String, String>{},
      );
      if (found.isNotEmpty) {
        return Map.fromEntries(
          found.entries.where((e) => e.value.trim().isNotEmpty && e.value != 'N/A'),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
