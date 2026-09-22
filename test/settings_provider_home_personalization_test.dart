import 'package:dtc_product/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsProvider — cá nhân hóa trang chủ', () {
    test('mặc định: tắt, rỗng, cỡ chữ/màu mặc định, không nghiêng', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.homePersonalizationEnabled, isFalse);
      expect(settings.homeDisplayName, isEmpty);
      expect(settings.homeShortText, isEmpty);
      expect(
        settings.homeNameFontSize,
        SettingsProvider.defaultHomeNameFontSize,
      );
      expect(settings.homeNameColor, isNull);
      expect(settings.homeNameItalic, isFalse);
      expect(
        settings.homeShortTextFontSize,
        SettingsProvider.defaultHomeShortTextFontSize,
      );
      expect(settings.homeShortTextColor, isNull);
      expect(settings.homeShortTextItalic, isFalse);
    });

    test('lưu rồi tạo lại provider (giả lập restart) vẫn giữ giá trị', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Kevin',
        shortText: 'DTC Engineer',
        nameFontSize: 16,
        nameColor: const Color(0xFFDC2626),
        nameItalic: true,
        shortTextFontSize: 24,
        shortTextColor: const Color(0xFF7C3AED),
        shortTextItalic: false,
      );

      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homePersonalizationEnabled, isTrue);
      expect(reloaded.homeDisplayName, 'Kevin');
      expect(reloaded.homeShortText, 'DTC Engineer');
      expect(reloaded.homeNameFontSize, 16);
      expect(reloaded.homeNameColor, const Color(0xFFDC2626));
      expect(reloaded.homeNameItalic, isTrue);
      expect(reloaded.homeShortTextFontSize, 24);
      expect(reloaded.homeShortTextColor, const Color(0xFF7C3AED));
      expect(reloaded.homeShortTextItalic, isFalse);
    });

    test('màu null (mặc định theme) được lưu và đọc lại đúng là null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Kevin',
        shortText: '',
        nameFontSize: 14,
        nameColor: const Color(0xFFDC2626),
        nameItalic: false,
        shortTextFontSize: 20,
        shortTextColor: null,
        shortTextItalic: false,
      );
      // Đặt lại về null (bỏ chọn màu tùy chỉnh) và lưu lần 2.
      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Kevin',
        shortText: '',
        nameFontSize: 14,
        nameColor: null,
        nameItalic: false,
        shortTextFontSize: 20,
        shortTextColor: null,
        shortTextItalic: false,
      );

      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homeNameColor, isNull);
      expect(reloaded.homeShortTextColor, isNull);
    });

    test('khôi phục mặc định xóa toàn bộ nội dung, tắt cá nhân hóa và bỏ nghiêng', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Kevin',
        shortText: 'DTC Engineer',
        nameFontSize: 18,
        nameColor: const Color(0xFF0A2740),
        nameItalic: true,
        shortTextFontSize: 26,
        shortTextColor: const Color(0xFF148147),
        shortTextItalic: true,
      );
      await settings.resetHomePersonalization();

      expect(settings.homePersonalizationEnabled, isFalse);
      expect(settings.homeDisplayName, isEmpty);
      expect(settings.homeShortText, isEmpty);
      expect(
        settings.homeNameFontSize,
        SettingsProvider.defaultHomeNameFontSize,
      );
      expect(settings.homeNameColor, isNull);
      expect(settings.homeNameItalic, isFalse);
      expect(
        settings.homeShortTextFontSize,
        SettingsProvider.defaultHomeShortTextFontSize,
      );
      expect(settings.homeShortTextColor, isNull);
      expect(settings.homeShortTextItalic, isFalse);

      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homePersonalizationEnabled, isFalse);
      expect(reloaded.homeDisplayName, isEmpty);
      expect(reloaded.homeNameColor, isNull);
      expect(reloaded.homeNameItalic, isFalse);
    });

    test('notifyListeners được gọi khi lưu', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      var notified = false;
      settings.addListener(() => notified = true);
      await settings.saveHomePersonalization(
        enabled: true,
        displayName: 'Alex',
        shortText: '',
        nameFontSize: SettingsProvider.defaultHomeNameFontSize,
        nameColor: null,
        nameItalic: false,
        shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
        shortTextColor: null,
        shortTextItalic: false,
      );
      expect(notified, isTrue);
    });
  });
}
