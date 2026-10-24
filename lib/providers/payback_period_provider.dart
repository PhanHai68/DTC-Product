import 'package:flutter/material.dart';

import '../core/input/localized_number.dart';

class PaybackPeriodProvider extends ChangeNotifier {
  double _machinePrice = 0;
  double _fullSetupPrice = 0;

  double? _machinePaybackDays;
  double? _fullSetupPaybackDays;

  double? get machinePaybackDays => _machinePaybackDays;
  double? get fullSetupPaybackDays => _fullSetupPaybackDays;
  double get machinePrice => _machinePrice;

  /// Số liệu của lần tính gần nhất, để giải thích công thức trên màn hình.
  PaybackPeriodInputs? _lastInputs;
  PaybackPeriodInputs? get lastInputs => _lastInputs;

  void setMachinePrice(String val) {
    _machinePrice = parseLocalizedDouble(val) ?? 0;
  }

  void setFullSetupPrice(String val) {
    _fullSetupPrice = parseLocalizedDouble(val) ?? 0;
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
    _lastInputs = (
      machinePrice: _machinePrice,
      fullSetupPrice: _fullSetupPrice,
      totalProfit: totalProfit,
    );
    notifyListeners();
  }

  void resetSession() {
    _machinePrice = 0;
    _fullSetupPrice = 0;
    _machinePaybackDays = null;
    _fullSetupPaybackDays = null;
    _lastInputs = null;
    notifyListeners();
  }
}

/// Đơn vị: VNĐ (lợi nhuận tính theo ngày).
typedef PaybackPeriodInputs = ({
  double machinePrice,
  double fullSetupPrice,
  double totalProfit,
});
