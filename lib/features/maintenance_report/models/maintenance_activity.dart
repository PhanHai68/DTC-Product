/// 1 dòng nhật ký hoạt động đơn giản (Activity Log), VD "09:20 Start
/// Maintenance". Chỉ ghi lại các mốc quan trọng, không phải audit log đầy đủ.
class MaintenanceActivity {
  final String id;
  final String reportId;
  final DateTime timestamp;
  final String message;

  const MaintenanceActivity({
    required this.id,
    required this.reportId,
    required this.timestamp,
    required this.message,
  });

  factory MaintenanceActivity.fromJson(Map<String, dynamic> json) =>
      MaintenanceActivity(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        message: json['message'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'timestamp': timestamp.toIso8601String(),
    'message': message,
  };
}
