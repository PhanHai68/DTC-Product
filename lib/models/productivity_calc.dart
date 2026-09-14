class ProductivityCalcData {
  final String customerName;
  final String materialName;
  final String notes;
  final double weightKg;
  final int hours;
  final int minutes;
  final int seconds;
  final DateTime measuredAt;

  const ProductivityCalcData({
    this.customerName = '',
    this.materialName = '',
    this.notes = '',
    required this.weightKg,
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
    required this.measuredAt,
  });

  /// Tổng thời gian đo tính bằng giây
  int get totalSeconds => (hours * 3600) + (minutes * 60) + seconds;

  /// Tổng thời gian dạng text hiển thị (ví dụ: 1h 30m 00s hoặc 01:30)
  String get formattedDuration {
    final hStr = hours > 0 ? '${hours}h ' : '';
    final mStr = '${minutes}m ';
    final sStr = '${seconds}s';
    return '$hStr$mStr$sStr'.trim();
  }

  /// Năng suất theo Kg/Giờ
  /// Công thức: (Khối lượng kg / Tổng số giây) * 3600
  double get kgPerHour {
    if (totalSeconds <= 0 || weightKg <= 0) return 0.0;
    return (weightKg / totalSeconds) * 3600.0;
  }

  /// Năng suất theo Tấn/Giờ
  double get tonPerHour => kgPerHour / 1000.0;

  /// Công suất ước tính 24 Giờ làm việc (Tấn/Ngày)
  double get tonPerDay => tonPerHour * 24.0;
}
