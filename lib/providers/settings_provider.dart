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

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  AppTextScale _textScale = AppTextScale.normal;

  ThemeMode get themeMode => _themeMode;
  AppTextScale get textScale => _textScale;

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
}
