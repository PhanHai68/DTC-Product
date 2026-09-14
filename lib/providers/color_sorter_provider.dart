import 'package:flutter/material.dart';
import '../data/specs_data.dart';

class ColorSorterProvider extends ChangeNotifier {
  Map<String, String>? _specs;
  Map<String, String>? get specs => _specs;

  String _selectedModel = 'SC16 Pro';
  String get selectedModel => _selectedModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ColorSorterProvider() {
    // Khởi tạo model mặc định là SC16 Pro (model đầu tiên từ trái sang phải)
    selectModel('SC16 Pro');
  }

  void selectModel(String modelName) {
    _selectedModel = modelName;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final found = colorSorterSpecs.firstWhere(
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
      // 1. Exact match Model name
      for (var row in colorSorterSpecs) {
        if (row['Model']?.toLowerCase() == modelName.toLowerCase().trim()) {
          result = row;
          break;
        }
      }

      // 2. Partial match Model name
      if (result == null) {
        for (var row in colorSorterSpecs) {
          if (row['Model']?.toLowerCase().contains(modelName.toLowerCase().trim()) == true) {
            result = row;
            break;
          }
        }
      }

      // 3. Partial match across any spec
      if (result == null) {
        for (var row in colorSorterSpecs) {
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
        _selectedModel = result['Model'] ?? _selectedModel;
        _specs = Map.fromEntries(
          result.entries.where((e) => e.value.trim().isNotEmpty && e.value != 'N/A'),
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
      return colorSorterSpecs.firstWhere(
        (e) => (e['Model'] ?? '').toLowerCase() == modelName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Gợi ý model tối ưu dựa trên sản lượng xưởng (tấn/giờ)
  Map<String, dynamic> suggestModelByCapacity(double capacity) {
    if (capacity <= 0) {
      return {
        'model': 'SC4',
        'reason': 'Vui lòng nhập sản lượng mong muốn lớn hơn 0.',
      };
    }

    if (capacity <= 6.0) {
      return {
        'model': 'SC4',
        'năng_suất': '4 - 6 tấn/giờ',
        'reason': 'Với sản lượng ${capacity.toStringAsFixed(1)} T/h, model SC4 (4-6 T/h, 3 máng) là lựa chọn tối ưu chi phí đầu tư ban đầu cho xưởng vừa và nhỏ.',
      };
    } else if (capacity <= 8.5) {
      return {
        'model': 'SC8',
        'năng_suất': '8 - 10 tấn/giờ',
        'reason': 'Với sản lượng ${capacity.toStringAsFixed(1)} T/h, model SC8 (8-10 T/h, 5 máng) đáp ứng hoàn hảo công suất, vận hành ổn định và tiết kiệm điện khí nén.',
      };
    } else if (capacity <= 11.5) {
      return {
        'model': 'SC10',
        'năng_suất': '10 - 12 tấn/giờ',
        'reason': 'Với sản lượng ${capacity.toStringAsFixed(1)} T/h, model SC10 (10-12 T/h, 6 máng) là lựa chọn lý tưởng cho các nhà máy công suất trung - lớn.',
      };
    } else if (capacity <= 16.5) {
      return {
        'model': 'SC12',
        'năng_suất': '12 - 16 tấn/giờ',
        'reason': 'Với sản lượng ${capacity.toStringAsFixed(1)} T/h, model SC12 (12-16 T/h, 10 máng, 20 camera) là cấu hình chuẩn cho nhà máy xay xát xuất khẩu quy mô lớn.',
      };
    } else {
      return {
        'model': 'SC16 Pro',
        'alternate': 'SC16',
        'năng_suất': '16 - 22 tấn/giờ',
        'reason': 'Với sản lượng lớn ${capacity.toStringAsFixed(1)} T/h, khuyến nghị model SC16 Pro (16-22 T/h, 12 máng) tích hợp AI Deep Learning và Cloud Control để tối đa hóa hiệu suất và chất lượng hạt thành phẩm.',
      };
    }
  }
}
