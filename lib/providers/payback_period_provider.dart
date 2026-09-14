import 'package:flutter/material.dart';

class PaybackPeriodProvider extends ChangeNotifier {
  double _machinePrice = 0;
  double _fullSetupPrice = 0;

  double? _machinePaybackDays;
  double? _fullSetupPaybackDays;

  double? get machinePaybackDays => _machinePaybackDays;
  double? get fullSetupPaybackDays => _fullSetupPaybackDays;
  double get machinePrice => _machinePrice;

  void setMachinePrice(String val) {
    _machinePrice = (double.tryParse(val) ?? 0) * 1000;
  }

  void setFullSetupPrice(String val) {
    _fullSetupPrice = (double.tryParse(val) ?? 0) * 1000;
  }

  void calculate(double totalProfit) {
    if (totalProfit <= 0) {
      // Nếu lợi nhuận <= 0 thì không thể hoàn vốn
      _machinePaybackDays = double.infinity;
      _fullSetupPaybackDays = double.infinity;
    } else {
      _machinePaybackDays = (_machinePrice / totalProfit);
      _fullSetupPaybackDays = (_fullSetupPrice / totalProfit);
    }
    notifyListeners();
  }
}
