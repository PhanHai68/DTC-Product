import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nơi cất refresh token của phiên đăng nhập.
///
/// Android/iOS: kho bảo mật của hệ điều hành (Keystore/Keychain), không nằm
/// trong file cài đặt thường và bị loại khỏi sao lưu tự động (xem
/// `android/app/src/main/res/xml/backup_rules.xml`). Web/desktop: giữ trong
/// SharedPreferences như trước vì không có kho tương đương.
abstract class SessionTokenStore {
  /// Khóa SharedPreferences cũ — vẫn dùng trên web/desktop và để chuyển
  /// token của bản cũ sang kho bảo mật.
  static const prefsKey = 'auth_refresh_token';

  factory SessionTokenStore.platformDefault() =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? SecureSessionTokenStore()
      : const PrefsSessionTokenStore();

  Future<String?> read(SharedPreferences prefs);
  Future<void> write(SharedPreferences prefs, String token);
  Future<void> delete(SharedPreferences prefs);
}

class PrefsSessionTokenStore implements SessionTokenStore {
  const PrefsSessionTokenStore();

  @override
  Future<String?> read(SharedPreferences prefs) async =>
      prefs.getString(SessionTokenStore.prefsKey);

  @override
  Future<void> write(SharedPreferences prefs, String token) =>
      prefs.setString(SessionTokenStore.prefsKey, token);

  @override
  Future<void> delete(SharedPreferences prefs) =>
      prefs.remove(SessionTokenStore.prefsKey);
}

class SecureSessionTokenStore implements SessionTokenStore {
  SecureSessionTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(SharedPreferences prefs) async {
    String? token;
    try {
      token = await _storage.read(key: _key);
    } catch (error) {
      // Kho hỏng (VD dữ liệu khôi phục từ máy khác không giải mã được):
      // xóa đi, người dùng chỉ phải đăng nhập lại.
      debugPrint('SessionTokenStore: không đọc được token ($error)');
      await _deleteSecure();
    }
    if (token != null) return token;
    // Bản cũ lưu token trong SharedPreferences: chuyển sang kho bảo mật để
    // người dùng không phải đăng nhập lại sau khi cập nhật.
    final legacy = prefs.getString(SessionTokenStore.prefsKey);
    if (legacy == null) return null;
    try {
      await _storage.write(key: _key, value: legacy);
      await prefs.remove(SessionTokenStore.prefsKey);
    } catch (error) {
      debugPrint('SessionTokenStore: chưa chuyển được token cũ ($error)');
    }
    return legacy;
  }

  @override
  Future<void> write(SharedPreferences prefs, String token) async {
    await _storage.write(key: _key, value: token);
    await prefs.remove(SessionTokenStore.prefsKey);
  }

  @override
  Future<void> delete(SharedPreferences prefs) async {
    await prefs.remove(SessionTokenStore.prefsKey);
    await _storage.delete(key: _key);
  }

  Future<void> _deleteSecure() async {
    try {
      await _storage.delete(key: _key);
    } catch (error) {
      debugPrint('SessionTokenStore: không xóa được token ($error)');
    }
  }
}
