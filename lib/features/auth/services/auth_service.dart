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

/// Giữ hạn offline hiện có và xác minh cả khi app mở liên tục.
/// Chỉ phản hồi thuộc phiên hiện tại được phép cập nhật trạng thái.
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
  static const _sessionCheckInterval = Duration(minutes: 1);
  static const _invalidSessionCodes = {
    'USER_DISABLED',
    'USER_NOT_FOUND',
    'TOKEN_EXPIRED',
    'INVALID_REFRESH_TOKEN',
  };

  final http.Client _client;
  final DateTime Function() _now;
  final String _apiKey;
  SharedPreferences? _prefs;
  AppLifecycleListener? _lifecycleListener;
  Timer? _sessionTimer;
  bool _foreground = true;
  bool _disposed = false;
  bool _signedIn = false;
  bool _verifying = false;
  bool _signingIn = false;
  int _sessionVersion = 0;
  Future<void>? _inFlight;
  Future<void> _storageQueue = Future.value();
  String? _email;
  String? _refreshToken;
  DateTime? _lastVerified;
  DateTime? _lastVerifyAttempt;
  String? _notice;

  bool get isSignedIn => _signedIn;
  bool get isVerifying => _verifying;
  String? get email => _email;
  String? get notice => _notice;
  bool get canRetryVerify => !_signedIn && _refreshToken != null;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  int _invalidateWork() {
    _sessionVersion++;
    _inFlight = null;
    _verifying = false;
    _signingIn = false;
    _lastVerifyAttempt = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    return _sessionVersion;
  }

  Future<void> restore(SharedPreferences prefs) async {
    final version = _invalidateWork();
    _signedIn = false;
    _refreshToken = null;
    _lastVerified = null;
    await _storageQueue;
    if (!_isCurrent(version)) return;
    _prefs = prefs;
    _email = prefs.getString(_kEmail);
    final savedToken = prefs.getString(_kRefreshToken);
    _refreshToken = savedToken != null && savedToken.trim().isNotEmpty
        ? savedToken
        : null;
    final verifiedMs = prefs.getInt(_kLastVerified);
    if (verifiedMs != null) {
      try {
        _lastVerified = DateTime.fromMillisecondsSinceEpoch(verifiedMs);
      } on ArgumentError {
        _lastVerified = null;
      }
    }
    _signedIn = _refreshToken != null && _withinOfflineGrace;
    _notice = null;
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycleListener ??= AppLifecycleListener(onStateChange: _onLifecycle);
    _applyOfflinePolicy();
    notifyListeners();
    _startSessionChecks();
    if (_refreshToken != null) unawaited(verify(force: !_signedIn));
  }

  bool get _withinOfflineGrace {
    final verified = _lastVerified;
    if (verified == null) return false;
    final age = _now().difference(verified);
    return !age.isNegative && age <= authOfflineGrace;
  }

  bool _isForeground(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  void _onLifecycle(AppLifecycleState state) {
    _foreground = _isForeground(state);
    if (_foreground) {
      _checkSession();
      _startSessionChecks();
    } else {
      _sessionTimer?.cancel();
      _sessionTimer = null;
    }
  }

  void _startSessionChecks() {
    if (_disposed ||
        !_foreground ||
        _refreshToken == null ||
        _sessionTimer != null) {
      return;
    }
    _sessionTimer = Timer.periodic(
      _sessionCheckInterval,
      (_) => _checkSession(),
    );
  }

  void _checkSession() {
    if (_disposed || _refreshToken == null) return;
    if (_applyOfflinePolicy()) notifyListeners();
    unawaited(verify());
  }

  bool _applyOfflinePolicy({String? failure}) {
    if (_refreshToken == null || _withinOfflineGrace) return false;
    final wasSignedIn = _signedIn;
    final oldNotice = _notice;
    _signedIn = false;
    final verified = _lastVerified;
    final reason = verified == null
        ? 'Chưa có lần xác minh tài khoản hợp lệ.'
        : _now().isBefore(verified)
        ? 'Thời gian thiết bị hoặc thời điểm xác minh đã lưu không hợp lệ.'
        : 'Đã quá ${authOfflineGrace.inDays} ngày chưa xác minh tài khoản.';
    _notice =
        '${failure == null ? "" : "$failure "}$reason '
        'Kết nối mạng rồi bấm "Thử lại", hoặc đăng nhập lại.';
    return wasSignedIn || oldNotice != _notice;
  }

  Future<void> signIn(String email, String password) async {
    _ensureConfigured();
    // Nhập thông tin đăng nhập mới kết thúc phiên cũ, kể cả nếu đăng nhập thất bại.
    final clearing = _endSession();
    final version = _sessionVersion;
    _signingIn = true;
    try {
      await clearing;
      if (!_isCurrent(version)) return;
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
      if (!_isCurrent(version)) return;
      final data = _decode(response.body);
      if (response.statusCode != 200) {
        throw AuthException(_messageFor(_errorCode(data)));
      }
      final token = _requiredString(data, 'refreshToken');
      _requiredString(data, 'idToken');
      final accountEmail = _requiredString(data, 'email');
      await _acceptSession(version, accountEmail, token);
    } on AuthException {
      if (_isCurrent(version)) rethrow;
    } catch (_) {
      if (_isCurrent(version)) {
        throw const AuthException(
          'Không kết nối được máy chủ hoặc không lưu được phiên. Kiểm tra mạng rồi thử lại.',
        );
      }
    } finally {
      if (_isCurrent(version)) {
        _signingIn = false;
        _startSessionChecks();
        notifyListeners();
      }
    }
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

  /// Đổi mật khẩu cho tài khoản đang đăng nhập. Firebase chỉ cho đổi khi vừa
  /// đăng nhập gần đây, nên xác minh lại bằng mật khẩu hiện tại để lấy
  /// idToken mới, rồi lưu phiên mới (đổi mật khẩu làm mất hiệu lực mã phiên
  /// cũ — các thiết bị khác sẽ phải đăng nhập lại).
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _ensureConfigured();
    final email = _email;
    if (!_signedIn || email == null) {
      throw const AuthException('Bạn cần đăng nhập để đổi mật khẩu.');
    }
    // Bỏ qua kết quả lần xác minh đang chạy bằng mã phiên cũ và tạm dừng xác
    // minh mới cho tới khi lưu xong phiên mới.
    final version = _invalidateWork();
    _signingIn = true;
    try {
      final signInResponse = await _client
          .post(
            _identityUri('accounts:signInWithPassword'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': currentPassword,
              'returnSecureToken': true,
            }),
          )
          .timeout(_timeout);
      if (!_isCurrent(version)) return;
      final signInData = _decode(signInResponse.body);
      if (signInResponse.statusCode != 200) {
        throw AuthException(
          _changePasswordMessageFor(_errorCode(signInData)),
        );
      }
      final idToken = _requiredString(signInData, 'idToken');

      final updateResponse = await _client
          .post(
            _identityUri('accounts:update'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'password': newPassword,
              'returnSecureToken': true,
            }),
          )
          .timeout(_timeout);
      if (!_isCurrent(version)) return;
      final updateData = _decode(updateResponse.body);
      if (updateResponse.statusCode != 200) {
        throw AuthException(
          _changePasswordMessageFor(_errorCode(updateData)),
        );
      }
      final token = _requiredString(updateData, 'refreshToken');
      await _acceptSession(version, email, token);
    } on AuthException {
      if (_isCurrent(version)) rethrow;
    } catch (_) {
      if (_isCurrent(version)) {
        throw const AuthException(
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        );
      }
    } finally {
      if (_isCurrent(version)) {
        _signingIn = false;
        _startSessionChecks();
        notifyListeners();
      }
    }
  }

  Future<void> signOut() => _endSession();

  Future<void> _endSession({String? notice}) {
    _invalidateWork();
    _signedIn = false;
    _refreshToken = null;
    _lastVerified = null;
    _notice = notice;
    notifyListeners();
    // Xếp sau mọi lần ghi đang chạy; chỉ xóa khóa của phiên, giữ dữ liệu app.
    final prefs = _prefs;
    if (prefs == null) return Future.value();
    return _queueStorage(() async {
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kLastVerified);
    });
  }

  Future<void> verify({bool force = false}) {
    if (_disposed || _signingIn) return Future.value();
    if (_applyOfflinePolicy()) notifyListeners();
    if (_inFlight != null) return _inFlight!;
    final token = _refreshToken;
    if (token == null || _apiKey.isEmpty) return Future.value();
    final previousAttempt = _lastVerifyAttempt ?? _lastVerified;
    if (!force && previousAttempt != null) {
      final elapsed = _now().difference(previousAttempt);
      if (!elapsed.isNegative && elapsed < authRecheckInterval) {
        return Future.value();
      }
    }
    final version = _sessionVersion;
    _lastVerifyAttempt = _now();
    // Khởi chạy sau khi gán _inFlight, tránh listener tạo thêm yêu cầu.
    return _inFlight = Future<void>.microtask(() => _refresh(version, token))
        .whenComplete(() {
          if (_isCurrent(version)) _inFlight = null;
        });
  }

  Future<void> _refresh(int version, String token) async {
    if (!_isCurrent(version)) return;
    _verifying = true;
    notifyListeners();
    String? failure;
    try {
      final response = await _client
          .post(
            Uri.parse(
              'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
            ),
            body: {'grant_type': 'refresh_token', 'refresh_token': token},
          )
          .timeout(_timeout);
      if (!_isCurrent(version)) return;
      final data = _decode(response.body);
      if (response.statusCode == 200) {
        final refreshedToken = _requiredString(data, 'refresh_token');
        _requiredString(data, 'id_token');
        await _acceptSession(version, _email, refreshedToken);
      } else {
        final code = _errorCode(data);
        if (response.statusCode >= 400 &&
            response.statusCode < 500 &&
            _invalidSessionCodes.contains(code)) {
          await _endSession(notice: _messageFor(code));
          return;
        }
        failure = 'Chưa xác minh được tài khoản với máy chủ.';
      }
    } on AuthException catch (error) {
      failure = error.message;
    } catch (_) {
      failure = 'Không kết nối được máy chủ hoặc không lưu được phiên.';
    } finally {
      if (_isCurrent(version)) {
        _verifying = false;
        _applyOfflinePolicy(failure: failure);
        _startSessionChecks();
        notifyListeners();
      }
    }
  }

  // Các lần ghi/xóa chạy tuần tự. Không đọc trạng thái phiên mới ở giữa lần ghi cũ.
  Future<void> _queueStorage(Future<void> Function() operation) {
    final write = _storageQueue.then((_) => operation());
    _storageQueue = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<void> _acceptSession(int version, String? email, String token) async {
    final verifiedAt = _now();
    final prefs = _prefs;
    await _queueStorage(() async {
      if (!_isCurrent(version) || prefs == null) return;
      if (email != null) await prefs.setString(_kEmail, email);
      await prefs.setString(_kRefreshToken, token);
      await prefs.setInt(_kLastVerified, verifiedAt.millisecondsSinceEpoch);
    });
    if (!_isCurrent(version)) return;
    _email = email;
    _refreshToken = token;
    _lastVerified = verifiedAt;
    _signedIn = true;
    _notice = null;
  }

  @visibleForTesting
  void debugSetSignedIn(String email) {
    _invalidateWork();
    _email = email;
    _refreshToken = 'debug';
    _lastVerified = _now();
    _signedIn = true;
    _notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateWork();
    _lifecycleListener?.dispose();
    _client.close();
    super.dispose();
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

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Phản hồi 200 với JSON lỗi không phải là xác minh thành công.
    }
    throw const AuthException(
      'Máy chủ trả dữ liệu không hợp lệ. Vui lòng thử lại.',
    );
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw const AuthException(
      'Máy chủ trả dữ liệu phiên không đầy đủ. Vui lòng thử lại.',
    );
  }

  static String _errorCode(Map<String, dynamic> data) {
    final error = data['error'];
    final message = error is Map ? error['message'] : error;
    return message is String ? message.split(':').first.trim() : '';
  }

  static String _changePasswordMessageFor(String code) {
    switch (code) {
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Mật khẩu hiện tại không đúng.';
      case 'WEAK_PASSWORD':
        return 'Mật khẩu mới quá yếu: cần ít nhất 6 ký tự.';
      case 'CREDENTIAL_TOO_OLD_LOGIN_AGAIN':
      case 'INVALID_ID_TOKEN':
        return 'Phiên xác minh đã hết hạn. Vui lòng thử lại.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Nhập sai quá nhiều lần. Vui lòng thử lại sau ít phút.';
      case 'USER_DISABLED':
      case 'USER_NOT_FOUND':
      case 'EMAIL_NOT_FOUND':
        return _messageFor(code == 'EMAIL_NOT_FOUND' ? 'USER_NOT_FOUND' : code);
      default:
        return 'Không đổi được mật khẩu${code.isEmpty ? '' : ' ($code)'}. '
            'Vui lòng thử lại.';
    }
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
