import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_config.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Phiên đăng nhập của app. Tài khoản do quản trị viên tạo/khoá trên Firebase
/// Console; app lưu refresh token và xác minh lại mỗi khi có mạng. Không xác
/// minh được quá [authOfflineGrace] thì buộc đăng nhập lại.
class AuthService extends ChangeNotifier {
  AuthService._({http.Client? client, DateTime Function()? now, String? apiKey})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now,
      _apiKey = apiKey ?? firebaseWebApiKey;

  @visibleForTesting
  factory AuthService.test({
    required http.Client client,
    DateTime Function()? now,
    String apiKey = 'test-key',
  }) => AuthService._(client: client, now: now, apiKey: apiKey);

  static final AuthService instance = AuthService._();

  static const _kEmail = 'auth_email';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kLastVerified = 'auth_last_verified_ms';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final DateTime Function() _now;
  final String _apiKey;

  SharedPreferences? _prefs;
  AppLifecycleListener? _lifecycleListener;
  bool _signedIn = false;
  bool _verifying = false;
  Future<void>? _inFlight;
  String? _email;
  String? _refreshToken;
  DateTime? _lastVerified;
  String? _notice;

  bool get isSignedIn => _signedIn;
  bool get isVerifying => _verifying;
  String? get email => _email;

  /// Thông báo hiển thị trên màn hình đăng nhập (bị khoá, hết hạn offline...).
  String? get notice => _notice;

  /// Còn phiên cũ nhưng chưa xác minh được (quá hạn offline, mất mạng).
  bool get canRetryVerify => !_signedIn && _refreshToken != null;

  Future<void> restore(SharedPreferences prefs) async {
    _prefs = prefs;
    _email = prefs.getString(_kEmail);
    _refreshToken = prefs.getString(_kRefreshToken);
    final verifiedMs = prefs.getInt(_kLastVerified);
    _lastVerified = verifiedMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(verifiedMs);
    _signedIn = _refreshToken != null && _withinOfflineGrace;
    _lifecycleListener ??= AppLifecycleListener(onResume: verify);
    if (_refreshToken != null) unawaited(verify(force: !_signedIn));
  }

  bool get _withinOfflineGrace =>
      _lastVerified != null &&
      _now().difference(_lastVerified!) <= authOfflineGrace;

  Future<void> signIn(String email, String password) async {
    _ensureConfigured();
    final Map<String, dynamic> data;
    try {
      final response = await _client
          .post(
            _identityUri('accounts:signInWithPassword'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'returnSecureToken': true,
            }),
          )
          .timeout(_timeout);
      data = _decode(response.body);
      if (response.statusCode != 200) {
        throw AuthException(_messageFor(_errorCode(data)));
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
    _email = (data['email'] as String?) ?? email.trim();
    _refreshToken = data['refreshToken'] as String?;
    _signedIn = true;
    _notice = null;
    await _markVerified();
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    _ensureConfigured();
    try {
      final response = await _client
          .post(
            _identityUri('accounts:sendOobCode'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requestType': 'PASSWORD_RESET',
              'email': email.trim(),
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw AuthException(_messageFor(_errorCode(_decode(response.body))));
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
  }

  Future<void> signOut() async {
    _notice = null;
    await _clearSession();
    notifyListeners();
  }

  /// Xác minh lại tài khoản bằng refresh token. Tài khoản bị khoá/xoá/đổi mật
  /// khẩu → đăng xuất. Mất mạng → giữ đăng nhập nếu còn trong hạn offline.
  Future<void> verify({bool force = false}) {
    if (_inFlight != null) return _inFlight!;
    if (_refreshToken == null || _apiKey.isEmpty) return Future.value();
    if (!force &&
        _signedIn &&
        _lastVerified != null &&
        _now().difference(_lastVerified!) < authRecheckInterval) {
      return Future.value();
    }
    return _inFlight = _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    _verifying = true;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': _refreshToken!,
            },
          )
          .timeout(_timeout);
      final data = _decode(response.body);
      if (response.statusCode == 200) {
        _refreshToken = (data['refresh_token'] as String?) ?? _refreshToken;
        _signedIn = true;
        _notice = null;
        await _markVerified();
      } else if (response.statusCode == 400) {
        _notice = _messageFor(_errorCode(data));
        await _clearSession();
      }
      // Lỗi máy chủ khác (5xx...) coi như tạm thời mất kết nối.
    } catch (_) {
      // Mất mạng: xử lý theo hạn offline bên dưới.
    } finally {
      _verifying = false;
      if (_refreshToken != null && !_withinOfflineGrace) {
        _signedIn = false;
        _notice =
            'Đã quá ${authOfflineGrace.inDays} ngày chưa xác minh tài khoản. '
            'Kết nối mạng rồi bấm "Thử lại", hoặc đăng nhập lại.';
      }
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugSetSignedIn(String email) {
    _email = email;
    _refreshToken = 'debug';
    _lastVerified = _now();
    _signedIn = true;
    notifyListeners();
  }

  void _ensureConfigured() {
    if (_apiKey.isEmpty) {
      throw const AuthException(
        'App chưa được cấu hình đăng nhập (thiếu Firebase Web API key).',
      );
    }
  }

  Uri _identityUri(String method) => Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/$method?key=$_apiKey',
  );

  Future<void> _markVerified() async {
    _lastVerified = _now();
    final prefs = _prefs;
    if (prefs == null) return;
    if (_email != null) await prefs.setString(_kEmail, _email!);
    if (_refreshToken != null) {
      await prefs.setString(_kRefreshToken, _refreshToken!);
    }
    await prefs.setInt(_kLastVerified, _lastVerified!.millisecondsSinceEpoch);
  }

  /// Xoá phiên nhưng giữ email để điền sẵn ở lần đăng nhập sau.
  Future<void> _clearSession() async {
    _signedIn = false;
    _refreshToken = null;
    _lastVerified = null;
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kLastVerified);
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Firebase trả lỗi dạng {"error": {"message": "CODE : mô tả"}}.
  static String _errorCode(Map<String, dynamic> data) {
    final error = data['error'];
    final message = error is Map ? error['message'] : error;
    return message is String ? message.split(':').first.trim() : '';
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email hoặc mật khẩu không đúng.';
      case 'INVALID_EMAIL':
        return 'Email không hợp lệ.';
      case 'MISSING_PASSWORD':
        return 'Vui lòng nhập mật khẩu.';
      case 'USER_DISABLED':
        return 'Tài khoản đã bị khoá. Liên hệ quản trị viên DTC.';
      case 'USER_NOT_FOUND':
        return 'Tài khoản không còn tồn tại. Liên hệ quản trị viên DTC.';
      case 'TOKEN_EXPIRED':
      case 'INVALID_REFRESH_TOKEN':
        return 'Phiên đăng nhập đã hết hạn (có thể mật khẩu vừa được đổi). '
            'Vui lòng đăng nhập lại.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Đăng nhập sai quá nhiều lần. Vui lòng thử lại sau ít phút.';
      default:
        return 'Không đăng nhập được${code.isEmpty ? '' : ' ($code)'}. '
            'Vui lòng thử lại.';
    }
  }
}
