import 'package:flutter/material.dart';

import '../data/tea_specs_data.dart';

class TeaColorSorterProvider extends ChangeNotifier {
  final List<Map<String, String>> data;

  Map<String, String>? _specs;
  Map<String, String>? get specs => _specs;

  String _selectedModel = 'DF53 Pro';
  String get selectedModel => _selectedModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  TeaColorSorterProvider({
    this.data = teaColorSorterSpecs,
    String initialModel = 'DF53 Pro',
  }) {
    selectModel(initialModel);
  }

  void selectModel(String modelName) {
    _selectedModel = modelName;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final found = data.firstWhere(
        (e) => (e['model'] ?? '').toLowerCase() == modelName.toLowerCase(),
        orElse: () => <String, String>{},
      );

      if (found.isNotEmpty) {
        _specs = Map.fromEntries(
          found.entries.where(
            (e) => e.value.trim().isNotEmpty && e.value != 'N/A',
          ),
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
      // 1. Exact match Model name
      for (var row in data) {
        if (row['model']?.toLowerCase() == modelName.toLowerCase().trim()) {
          result = row;
          break;
        }
      }

      // 2. Partial match Model name
      if (result == null) {
        for (var row in data) {
          if (row['model']?.toLowerCase().contains(
                modelName.toLowerCase().trim(),
              ) ==
              true) {
            result = row;
            break;
          }
        }
      }

      // 3. Partial match across any spec
      if (result == null) {
        for (var row in data) {
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
        _selectedModel = result['model'] ?? _selectedModel;
        _specs = Map.fromEntries(
          result.entries.where(
            (e) => e.value.trim().isNotEmpty && e.value != 'N/A',
          ),
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

  Map<String, String>? getSpecByModel(String modelName) {
    try {
      return data.firstWhere(
        (e) => (e['model'] ?? '').toLowerCase() == modelName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
