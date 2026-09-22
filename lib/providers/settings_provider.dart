import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Các mức cỡ chữ người dùng có thể chọn ở màn Cài đặt.
enum AppTextScale {
  small(0.9, 'Nhỏ'),
  normal(1.0, 'Vừa'),
  large(1.15, 'Lớn'),
  extraLarge(1.3, 'Rất lớn');

  const AppTextScale(this.scale, this.label);
  final double scale;
  final String label;

  static AppTextScale fromScale(double scale) => AppTextScale.values
      .firstWhere((e) => e.scale == scale, orElse: () => AppTextScale.normal);
}

/// Lưu và áp dụng các tuỳ chọn cài đặt chung: giao diện sáng/tối, cỡ chữ.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _load();
  }

  static const _themeModeKey = 'settings_theme_mode';
  static const _textScaleKey = 'settings_text_scale';

  // Cá nhân hóa trang chủ — chỉ là tùy chỉnh hiển thị cục bộ trên thiết bị,
  // không liên quan tài khoản/nhân sự. Mặc định tắt (enabled = false).
  static const _homePersonalizationEnabledKey = 'home_personalization_enabled';
  static const _homeDisplayNameKey = 'home_display_name';
  static const _homeShortTextKey = 'home_short_text';
  static const _homeNameFontSizeKey = 'home_name_font_size';
  static const _homeNameColorKey = 'home_name_color';
  static const _homeNameItalicKey = 'home_name_italic';
  static const _homeShortTextFontSizeKey = 'home_short_text_font_size';
  static const _homeShortTextColorKey = 'home_short_text_color';
  static const _homeShortTextItalicKey = 'home_short_text_italic';

  // "Mục tiêu hôm nay" (Daily Goals) trên Home — chỉ cờ bật/tắt + tiêu đề
  // hiển thị nằm ở đây; dữ liệu mục tiêu thật lưu SQLite (DailyGoalRepository),
  // tắt chức năng không xóa dữ liệu, chỉ ẩn khỏi Home.
  static const _homeDailyGoalsEnabledKey = 'home_daily_goals_enabled';
  static const _homeDailyGoalsTitleKey = 'home_daily_goals_title';
  static const _homeDailyGoalsFontSizeKey = 'home_daily_goals_font_size';
  static const _homeDailyGoalsColorKey = 'home_daily_goals_color';
  static const _homeDailyGoalsItalicKey = 'home_daily_goals_italic';

  // Nhắc nhở cuối ngày cho "Mục tiêu hôm nay" (Phase 3) — 1 giờ nhắc cố định
  // lặp lại hàng ngày, lên lịch qua DailyGoalNotificationService khi lưu.
  static const _homeDailyGoalsReminderEnabledKey =
      'home_daily_goals_reminder_enabled';
  static const _homeDailyGoalsReminderHourKey =
      'home_daily_goals_reminder_hour';
  static const _homeDailyGoalsReminderMinuteKey =
      'home_daily_goals_reminder_minute';

  static const double defaultHomeNameFontSize = 18.0;
  static const double defaultHomeShortTextFontSize = 26.0;
  static const String defaultHomeDailyGoalsTitle = 'Mục tiêu hôm nay';
  static const double defaultHomeDailyGoalsFontSize = 14.5;
  static const int defaultHomeDailyGoalsReminderHour = 20;
  static const int defaultHomeDailyGoalsReminderMinute = 0;

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  AppTextScale _textScale = AppTextScale.normal;

  bool _homePersonalizationEnabled = false;
  String _homeDisplayName = '';
  String _homeShortText = '';
  double _homeNameFontSize = defaultHomeNameFontSize;
  Color? _homeNameColor;
  bool _homeNameItalic = false;
  double _homeShortTextFontSize = defaultHomeShortTextFontSize;
  Color? _homeShortTextColor;
  bool _homeShortTextItalic = false;
  bool _homeDailyGoalsEnabled = false;
  String _homeDailyGoalsTitle = defaultHomeDailyGoalsTitle;
  double _homeDailyGoalsFontSize = defaultHomeDailyGoalsFontSize;
  Color? _homeDailyGoalsColor;
  bool _homeDailyGoalsItalic = false;
  bool _homeDailyGoalsReminderEnabled = false;
  int _homeDailyGoalsReminderHour = defaultHomeDailyGoalsReminderHour;
  int _homeDailyGoalsReminderMinute = defaultHomeDailyGoalsReminderMinute;

  ThemeMode get themeMode => _themeMode;
  AppTextScale get textScale => _textScale;

  bool get homePersonalizationEnabled => _homePersonalizationEnabled;
  String get homeDisplayName => _homeDisplayName;
  String get homeShortText => _homeShortText;
  double get homeNameFontSize => _homeNameFontSize;
  Color? get homeNameColor => _homeNameColor;
  bool get homeNameItalic => _homeNameItalic;
  double get homeShortTextFontSize => _homeShortTextFontSize;
  Color? get homeShortTextColor => _homeShortTextColor;
  bool get homeShortTextItalic => _homeShortTextItalic;
  bool get homeDailyGoalsEnabled => _homeDailyGoalsEnabled;
  String get homeDailyGoalsTitle => _homeDailyGoalsTitle;
  double get homeDailyGoalsFontSize => _homeDailyGoalsFontSize;
  Color? get homeDailyGoalsColor => _homeDailyGoalsColor;
  bool get homeDailyGoalsItalic => _homeDailyGoalsItalic;
  bool get homeDailyGoalsReminderEnabled => _homeDailyGoalsReminderEnabled;
  int get homeDailyGoalsReminderHour => _homeDailyGoalsReminderHour;
  int get homeDailyGoalsReminderMinute => _homeDailyGoalsReminderMinute;

  void _load() {
    final savedMode = _prefs.getString(_themeModeKey);
    _themeMode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final savedScale = _prefs.getDouble(_textScaleKey);
    if (savedScale != null) {
      _textScale = AppTextScale.fromScale(savedScale);
    }
    _homePersonalizationEnabled =
        _prefs.getBool(_homePersonalizationEnabledKey) ?? false;
    _homeDisplayName = _prefs.getString(_homeDisplayNameKey) ?? '';
    _homeShortText = _prefs.getString(_homeShortTextKey) ?? '';
    _homeNameFontSize =
        _prefs.getDouble(_homeNameFontSizeKey) ?? defaultHomeNameFontSize;
    _homeShortTextFontSize =
        _prefs.getDouble(_homeShortTextFontSizeKey) ??
        defaultHomeShortTextFontSize;
    final nameColorValue = _prefs.getInt(_homeNameColorKey);
    _homeNameColor = nameColorValue == null ? null : Color(nameColorValue);
    final shortTextColorValue = _prefs.getInt(_homeShortTextColorKey);
    _homeShortTextColor = shortTextColorValue == null
        ? null
        : Color(shortTextColorValue);
    _homeNameItalic = _prefs.getBool(_homeNameItalicKey) ?? false;
    _homeShortTextItalic = _prefs.getBool(_homeShortTextItalicKey) ?? false;
    _homeDailyGoalsEnabled =
        _prefs.getBool(_homeDailyGoalsEnabledKey) ?? false;
    _homeDailyGoalsTitle =
        _prefs.getString(_homeDailyGoalsTitleKey) ?? defaultHomeDailyGoalsTitle;
    _homeDailyGoalsFontSize =
        _prefs.getDouble(_homeDailyGoalsFontSizeKey) ??
        defaultHomeDailyGoalsFontSize;
    final dailyGoalsColorValue = _prefs.getInt(_homeDailyGoalsColorKey);
    _homeDailyGoalsColor = dailyGoalsColorValue == null
        ? null
        : Color(dailyGoalsColorValue);
    _homeDailyGoalsItalic = _prefs.getBool(_homeDailyGoalsItalicKey) ?? false;
    _homeDailyGoalsReminderEnabled =
        _prefs.getBool(_homeDailyGoalsReminderEnabledKey) ?? false;
    _homeDailyGoalsReminderHour =
        _prefs.getInt(_homeDailyGoalsReminderHourKey) ??
        defaultHomeDailyGoalsReminderHour;
    _homeDailyGoalsReminderMinute =
        _prefs.getInt(_homeDailyGoalsReminderMinuteKey) ??
        defaultHomeDailyGoalsReminderMinute;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setTextScale(AppTextScale scale) async {
    if (_textScale == scale) return;
    _textScale = scale;
    notifyListeners();
    await _prefs.setDouble(_textScaleKey, scale.scale);
  }

  /// Lưu toàn bộ tuỳ chỉnh cá nhân hóa trang chủ cùng lúc (nút "Lưu thay
  /// đổi" ở màn Cá nhân hóa trang chủ) để Home chỉ cập nhật 1 lần.
  /// [nameColor]/[shortTextColor] = null nghĩa là theo màu mặc định của theme.
  Future<void> saveHomePersonalization({
    required bool enabled,
    required String displayName,
    required String shortText,
    required double nameFontSize,
    required Color? nameColor,
    required bool nameItalic,
    required double shortTextFontSize,
    required Color? shortTextColor,
    required bool shortTextItalic,
    bool? dailyGoalsEnabled,
    String? dailyGoalsTitle,
    double? dailyGoalsFontSize,
    Color? dailyGoalsColor,
    // dailyGoalsColor cho phép giá trị null hợp lệ (nghĩa là "theo màu mặc
    // định theme"), nên cần cờ riêng để phân biệt "không truyền tham số này"
    // (giữ nguyên màu cũ) với "chủ động đặt về null" (theo theme).
    bool dailyGoalsColorIsSet = false,
    bool? dailyGoalsItalic,
    bool? dailyGoalsReminderEnabled,
    int? dailyGoalsReminderHour,
    int? dailyGoalsReminderMinute,
  }) async {
    _homePersonalizationEnabled = enabled;
    _homeDisplayName = displayName;
    _homeShortText = shortText;
    _homeNameFontSize = nameFontSize;
    _homeNameColor = nameColor;
    _homeNameItalic = nameItalic;
    _homeShortTextFontSize = shortTextFontSize;
    _homeShortTextColor = shortTextColor;
    _homeShortTextItalic = shortTextItalic;
    if (dailyGoalsEnabled != null) _homeDailyGoalsEnabled = dailyGoalsEnabled;
    final resolvedGoalsTitle = (dailyGoalsTitle ?? '').trim().isEmpty
        ? defaultHomeDailyGoalsTitle
        : dailyGoalsTitle!.trim();
    if (dailyGoalsTitle != null) _homeDailyGoalsTitle = resolvedGoalsTitle;
    if (dailyGoalsFontSize != null) {
      _homeDailyGoalsFontSize = dailyGoalsFontSize;
    }
    if (dailyGoalsColorIsSet) _homeDailyGoalsColor = dailyGoalsColor;
    if (dailyGoalsItalic != null) _homeDailyGoalsItalic = dailyGoalsItalic;
    if (dailyGoalsReminderEnabled != null) {
      _homeDailyGoalsReminderEnabled = dailyGoalsReminderEnabled;
    }
    if (dailyGoalsReminderHour != null) {
      _homeDailyGoalsReminderHour = dailyGoalsReminderHour;
    }
    if (dailyGoalsReminderMinute != null) {
      _homeDailyGoalsReminderMinute = dailyGoalsReminderMinute;
    }
    notifyListeners();
    await Future.wait([
      _prefs.setBool(_homePersonalizationEnabledKey, enabled),
      _prefs.setString(_homeDisplayNameKey, displayName),
      _prefs.setString(_homeShortTextKey, shortText),
      _prefs.setDouble(_homeNameFontSizeKey, nameFontSize),
      _prefs.setDouble(_homeShortTextFontSizeKey, shortTextFontSize),
      _prefs.setBool(_homeNameItalicKey, nameItalic),
      _prefs.setBool(_homeShortTextItalicKey, shortTextItalic),
      if (nameColor != null)
        _prefs.setInt(_homeNameColorKey, nameColor.toARGB32())
      else
        _prefs.remove(_homeNameColorKey),
      if (shortTextColor != null)
        _prefs.setInt(_homeShortTextColorKey, shortTextColor.toARGB32())
      else
        _prefs.remove(_homeShortTextColorKey),
      if (dailyGoalsEnabled != null)
        _prefs.setBool(_homeDailyGoalsEnabledKey, dailyGoalsEnabled),
      if (dailyGoalsTitle != null)
        _prefs.setString(_homeDailyGoalsTitleKey, resolvedGoalsTitle),
      if (dailyGoalsFontSize != null)
        _prefs.setDouble(_homeDailyGoalsFontSizeKey, dailyGoalsFontSize),
      if (dailyGoalsItalic != null)
        _prefs.setBool(_homeDailyGoalsItalicKey, dailyGoalsItalic),
      if (dailyGoalsColorIsSet)
        if (dailyGoalsColor != null)
          _prefs.setInt(_homeDailyGoalsColorKey, dailyGoalsColor.toARGB32())
        else
          _prefs.remove(_homeDailyGoalsColorKey),
      if (dailyGoalsReminderEnabled != null)
        _prefs.setBool(
          _homeDailyGoalsReminderEnabledKey,
          dailyGoalsReminderEnabled,
        ),
      if (dailyGoalsReminderHour != null)
        _prefs.setInt(_homeDailyGoalsReminderHourKey, dailyGoalsReminderHour),
      if (dailyGoalsReminderMinute != null)
        _prefs.setInt(
          _homeDailyGoalsReminderMinuteKey,
          dailyGoalsReminderMinute,
        ),
    ]);
  }

  /// Khôi phục cá nhân hóa trang chủ về mặc định (tắt, xóa toàn bộ nội dung).
  /// "Mục tiêu hôm nay" cũng tắt hiển thị trên Home, nhưng KHÔNG xóa dữ liệu
  /// mục tiêu đã tạo (dữ liệu nằm ở SQLite, tách biệt khỏi setting hiển thị).
  Future<void> resetHomePersonalization() => saveHomePersonalization(
    enabled: false,
    displayName: '',
    shortText: '',
    nameFontSize: defaultHomeNameFontSize,
    nameColor: null,
    nameItalic: false,
    shortTextFontSize: defaultHomeShortTextFontSize,
    shortTextColor: null,
    shortTextItalic: false,
    dailyGoalsEnabled: false,
    dailyGoalsTitle: defaultHomeDailyGoalsTitle,
    dailyGoalsFontSize: defaultHomeDailyGoalsFontSize,
    dailyGoalsColor: null,
    dailyGoalsColorIsSet: true,
    dailyGoalsItalic: false,
    dailyGoalsReminderEnabled: false,
    dailyGoalsReminderHour: defaultHomeDailyGoalsReminderHour,
    dailyGoalsReminderMinute: defaultHomeDailyGoalsReminderMinute,
  );
}
