import 'package:dtc_product/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'thẻ Sales Goal mặc định tắt, lưu và khôi phục không xóa dữ liệu khác',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.homeSalesGoalEnabled, isFalse);
      await settings.saveHomePersonalization(
        enabled: false,
        displayName: '',
        shortText: '',
        nameFontSize: SettingsProvider.defaultHomeNameFontSize,
        nameColor: null,
        nameItalic: false,
        shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
        shortTextColor: null,
        shortTextItalic: false,
        salesGoalEnabled: true,
      );
      expect(SettingsProvider(prefs).homeSalesGoalEnabled, isTrue);

      await settings.resetHomePersonalization();
      expect(settings.homeSalesGoalEnabled, isFalse);
    },
  );
}
