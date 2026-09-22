import 'package:dtc_product/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bộ tham số saveHomePersonalization tối thiểu hợp lệ, dùng chung cho các
/// test chỉ quan tâm tới phần "Mục tiêu hôm nay".
Future<void> _saveMinimal(
  SettingsProvider settings, {
  bool? dailyGoalsEnabled,
  String? dailyGoalsTitle,
  bool? dailyGoalsReminderEnabled,
  int? dailyGoalsReminderHour,
  int? dailyGoalsReminderMinute,
}) {
  return settings.saveHomePersonalization(
    enabled: false,
    displayName: '',
    shortText: '',
    nameFontSize: SettingsProvider.defaultHomeNameFontSize,
    nameColor: null,
    nameItalic: false,
    shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
    shortTextColor: null,
    shortTextItalic: false,
    dailyGoalsEnabled: dailyGoalsEnabled,
    dailyGoalsTitle: dailyGoalsTitle,
    dailyGoalsReminderEnabled: dailyGoalsReminderEnabled,
    dailyGoalsReminderHour: dailyGoalsReminderHour,
    dailyGoalsReminderMinute: dailyGoalsReminderMinute,
  );
}

void main() {
  group('SettingsProvider — Mục tiêu hôm nay', () {
    test('mặc định: tắt, tiêu đề mặc định "Mục tiêu hôm nay"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.homeDailyGoalsEnabled, isFalse);
      expect(settings.homeDailyGoalsTitle, 'Mục tiêu hôm nay');
    });

    test('lưu rồi tạo lại provider (giả lập restart) vẫn giữ giá trị', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await _saveMinimal(
        settings,
        dailyGoalsEnabled: true,
        dailyGoalsTitle: 'Công việc hôm nay',
      );

      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homeDailyGoalsEnabled, isTrue);
      expect(reloaded.homeDailyGoalsTitle, 'Công việc hôm nay');
    });

    test('tiêu đề để trống tự về lại mặc định, không lưu chuỗi rỗng', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await _saveMinimal(settings, dailyGoalsEnabled: true, dailyGoalsTitle: '   ');

      expect(settings.homeDailyGoalsTitle, 'Mục tiêu hôm nay');
    });

    test('không truyền dailyGoalsEnabled/dailyGoalsTitle thì giữ nguyên giá trị cũ', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      await _saveMinimal(
        settings,
        dailyGoalsEnabled: true,
        dailyGoalsTitle: 'Today\'s Focus',
      );

      // Gọi saveHomePersonalization cho phần khác (VD lưu tên hiển thị) mà
      // không đá động gì tới Mục tiêu hôm nay.
      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Kevin',
        shortText: '',
        nameFontSize: SettingsProvider.defaultHomeNameFontSize,
        nameColor: null,
        nameItalic: false,
        shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
        shortTextColor: null,
        shortTextItalic: false,
      );

      expect(settings.homeDailyGoalsEnabled, isTrue);
      expect(settings.homeDailyGoalsTitle, "Today's Focus");
    });

    test('resetHomePersonalization tắt hiển thị và trả tiêu đề về mặc định', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      await _saveMinimal(
        settings,
        dailyGoalsEnabled: true,
        dailyGoalsTitle: 'My Goals',
      );

      await settings.resetHomePersonalization();

      expect(settings.homeDailyGoalsEnabled, isFalse);
      expect(settings.homeDailyGoalsTitle, 'Mục tiêu hôm nay');
    });
  });

  group('SettingsProvider — Nhắc nhở "Mục tiêu hôm nay" (Phase 3)', () {
    test('mặc định: tắt, giờ nhắc mặc định 20:00', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.homeDailyGoalsReminderEnabled, isFalse);
      expect(settings.homeDailyGoalsReminderHour, 20);
      expect(settings.homeDailyGoalsReminderMinute, 0);
    });

    test('lưu rồi tạo lại provider (giả lập restart) vẫn giữ giờ nhắc', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await _saveMinimal(
        settings,
        dailyGoalsReminderEnabled: true,
        dailyGoalsReminderHour: 7,
        dailyGoalsReminderMinute: 45,
      );

      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homeDailyGoalsReminderEnabled, isTrue);
      expect(reloaded.homeDailyGoalsReminderHour, 7);
      expect(reloaded.homeDailyGoalsReminderMinute, 45);
    });

    test('không truyền tham số nhắc nhở thì giữ nguyên giá trị cũ', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      await _saveMinimal(
        settings,
        dailyGoalsReminderEnabled: true,
        dailyGoalsReminderHour: 6,
        dailyGoalsReminderMinute: 30,
      );

      await _saveMinimal(settings, dailyGoalsTitle: 'Việc hôm nay');

      expect(settings.homeDailyGoalsReminderEnabled, isTrue);
      expect(settings.homeDailyGoalsReminderHour, 6);
      expect(settings.homeDailyGoalsReminderMinute, 30);
    });

    test('resetHomePersonalization tắt nhắc nhở và trả giờ về mặc định', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      await _saveMinimal(
        settings,
        dailyGoalsReminderEnabled: true,
        dailyGoalsReminderHour: 6,
        dailyGoalsReminderMinute: 30,
      );

      await settings.resetHomePersonalization();

      expect(settings.homeDailyGoalsReminderEnabled, isFalse);
      expect(settings.homeDailyGoalsReminderHour, 20);
      expect(settings.homeDailyGoalsReminderMinute, 0);
    });
  });
}
