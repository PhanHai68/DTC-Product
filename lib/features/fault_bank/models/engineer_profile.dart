/// Hồ sơ kỹ sư dùng máy này — chỉ có 1 dòng trong bảng `profile`.
class EngineerProfile {
  const EngineerProfile({
    required this.engineerName,
    required this.engineerCode,
    this.defaultEmail,
    this.monthlyReminderDay,
  });

  final String engineerName;

  /// VD "KS012" — tiền tố của mọi mã bản ghi do kỹ sư này tạo.
  final String engineerCode;

  /// Giai đoạn 2: email nhận file xuất hằng tháng.
  final String? defaultEmail;

  /// Giai đoạn 2: ngày trong tháng (1–28) nhắc xuất file.
  final int? monthlyReminderDay;

  EngineerProfile copyWith({String? engineerName, String? engineerCode}) =>
      EngineerProfile(
        engineerName: engineerName ?? this.engineerName,
        engineerCode: engineerCode ?? this.engineerCode,
        defaultEmail: defaultEmail,
        monthlyReminderDay: monthlyReminderDay,
      );

  factory EngineerProfile.fromMap(Map<String, Object?> map) => EngineerProfile(
    engineerName: map['engineer_name'] as String,
    engineerCode: map['engineer_code'] as String,
    defaultEmail: map['default_email'] as String?,
    monthlyReminderDay: map['monthly_reminder_day'] as int?,
  );
}
