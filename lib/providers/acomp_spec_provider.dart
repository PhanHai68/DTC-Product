import 'package:flutter/material.dart';
import '../models/acomp_spec_model.dart';
import '../data/product_data.dart';

class AcompSpecProvider extends ChangeNotifier {
  List<AcompSpecModel> pvList = [];
  List<AcompSpecModel> fList = [];

  /// Máy 4 trong 1 (ACA), cả tốc độ cố định lẫn biến tần.
  List<AcompSpecModel> fourInOneList = [];

  AcompSpecProvider() {
    _loadData();
  }

  void _loadData() {
    pvList = acompSpecData.where((element) => element.series == 'PM VSD').toList();
    fList = acompSpecData.where((element) => element.series == 'Fixed Speed').toList();
    fourInOneList = acompSpecData.where((element) => element.isFourInOne).toList();

    // Sắp xếp theo công suất (HP)
    pvList.sort((a, b) => a.powerHP.compareTo(b.powerHP));
    fList.sort((a, b) => a.powerHP.compareTo(b.powerHP));
    // Cùng công suất thì máy cố định trước, biến tần sau.
    fourInOneList.sort((a, b) {
      final byPower = a.powerHP.compareTo(b.powerHP);
      if (byPower != 0) return byPower;
      return (a.isVsd ? 1 : 0).compareTo(b.isVsd ? 1 : 0);
    });

    notifyListeners();
  }
}
