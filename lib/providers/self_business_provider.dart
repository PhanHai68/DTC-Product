import 'package:flutter/material.dart';

class SelfBusinessProvider extends ChangeNotifier {
  double _rawMaterialPrice = 0;
  double _finishedProductPrice = 0;
  double _byProductPrice = 0;

  double? _costRawMaterial;
  double? _revenueFinished;
  double? _revenueByProduct;
  double? _netProfit;

  double? get costRawMaterial => _costRawMaterial;
  double? get revenueFinished => _revenueFinished;
  double? get revenueByProduct => _revenueByProduct;
  double? get netProfit => _netProfit;

  void setRawMaterialPrice(String val) {
    _rawMaterialPrice = double.tryParse(val) ?? 0;
  }

  void setFinishedProductPrice(String val) {
    _finishedProductPrice = double.tryParse(val) ?? 0;
  }

  void setByProductPrice(String val) {
    _byProductPrice = double.tryParse(val) ?? 0;
  }

  void calculate({
    required double capacity, // Tấn/h
    required double totalHours, // Giờ
    required double electricityBill, // VNĐ
    required double dailySalary, // VNĐ
  }) {
    // Năng suất Thành Phẩm = capacity * 0.96875
    // Năng suất Phế Phẩm = capacity * 0.03125
    double finishedCapacity = capacity * 0.96875;
    double byProductCapacity = capacity * 0.03125;

    // Tổng Chi phí Mua Nguyên Liệu = Tổng năng suất x 1000 x Số giờ x Giá mua
    _costRawMaterial = capacity * 1000 * totalHours * _rawMaterialPrice;

    // Tổng Doanh thu Bán Thành Phẩm = Năng suất thành phẩm x 1000 x Số giờ x Giá bán
    _revenueFinished = finishedCapacity * 1000 * totalHours * _finishedProductPrice;

    // Tổng Doanh thu Bán Phế Phẩm = Năng suất phế phẩm x 1000 x Số giờ x Giá bán
    _revenueByProduct = byProductCapacity * 1000 * totalHours * _byProductPrice;

    // Lợi nhuận ròng = Doanh thu - Phí nguyên liệu - Điện - Lương
    // (Áp dụng theo ghi chú công thức để chính xác với khái niệm "Lợi nhuận ròng")
    _netProfit = (_revenueFinished! + _revenueByProduct!) - _costRawMaterial! - electricityBill - dailySalary;

    notifyListeners();
  }
}
