import 'package:flutter/material.dart';
import '../models/acomp_spec_model.dart';
import '../data/acomp_spec_data.dart';

class AcompSpecProvider extends ChangeNotifier {
  List<AcompSpecModel> pvList = [];
  List<AcompSpecModel> fList = [];

  AcompSpecProvider() {
    _loadData();
  }

  void _loadData() {
    pvList = acompSpecData.where((element) => element.series == 'PM VSD').toList();
    fList = acompSpecData.where((element) => element.series == 'Fixed Speed').toList();
    
    // Sắp xếp theo công suất (HP)
    pvList.sort((a, b) => a.powerHP.compareTo(b.powerHP));
    fList.sort((a, b) => a.powerHP.compareTo(b.powerHP));
    
    notifyListeners();
  }
}
