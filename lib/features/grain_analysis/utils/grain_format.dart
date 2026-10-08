import 'package:intl/intl.dart';

/// Định dạng số hiển thị theo kiểu Việt Nam (1.024 hạt; 30,0%).
abstract final class GrainFormat {
  static final _count = NumberFormat.decimalPattern('vi');
  static final _one = NumberFormat('#,##0.0', 'vi');
  static final _two = NumberFormat('#,##0.00', 'vi');

  static String count(int n) => _count.format(n);

  /// Làm tròn 1 chữ số thập phân (chỉ khi hiển thị — mục 8).
  static String percent(double v) => '${_one.format(v)}%';

  static String decimal(double v, {int digits = 1}) =>
      digits == 2 ? _two.format(v) : _one.format(v);
}
