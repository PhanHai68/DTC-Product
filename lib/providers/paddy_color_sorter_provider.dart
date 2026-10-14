import 'package:flutter/material.dart';
import '../data/product_data.dart';

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
    // Chọn model nhỏ nhất có năng suất tối đa đáp ứng được yêu cầu.
    Map<String, String>? best;
    double? bestMax;
    for (final spec in paddyColorSorterSpecs) {
      final range = spec['Năng suất (tấn/giờ)'] ?? '';
      final max = double.tryParse(range.split('-').last.trim());
      if (max == null || max < requiredCapacity) continue;
      if (bestMax == null || max < bestMax) {
        best = spec;
        bestMax = max;
      }
    }
    if (best == null) return null;
    final model = best['Model'] ?? '';
    final range = best['Năng suất (tấn/giờ)'] ?? '';
    return {
      'model': model,
      'reason':
          'Model $model (năng suất $range tấn/h) là model nhỏ nhất đáp ứng năng suất yêu cầu $requiredCapacity tấn/h.',
    };
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
