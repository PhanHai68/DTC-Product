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

  static const double defaultHomeNameFontSize = 18.0;
  static const double defaultHomeShortTextFontSize = 26.0;

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
    ]);
  }

  /// Khôi phục cá nhân hóa trang chủ về mặc định (tắt, xóa toàn bộ nội dung).
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
  );
}
