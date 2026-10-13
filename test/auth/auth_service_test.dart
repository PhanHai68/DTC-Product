import 'dart:convert';

import 'package:dtc_product/features/auth/screens/login_screen.dart';
import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status);

http.Response _error(String code) => _json(400, {
  'error': {'code': 400, 'message': code},
});

AuthService _createAuth({
  required http.Client client,
  DateTime Function()? now,
}) {
  final auth = AuthService.test(client: client, now: now);
  addTearDown(auth.dispose);
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    now = DateTime(2026, 10, 9, 9);
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefsWithSession(DateTime lastVerified) async {
    SharedPreferences.setMockInitialValues({
      'auth_email': 'a@dtc.vn',
      'auth_refresh_token': 'rt-1',
      'auth_last_verified_ms': lastVerified.millisecondsSinceEpoch,
    });
    return SharedPreferences.getInstance();
  }

  test('đăng nhập đúng lưu phiên', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _createAuth(
      now: clock,
      client: MockClient((request) async {
        expect(request.url.path, contains('signInWithPassword'));
        return _json(200, {
          'email': 'a@dtc.vn',
          'idToken': 'id',
          'refreshToken': 'rt-1',
        });
      }),
    );
    await auth.restore(prefs);
    await auth.signIn(' a@dtc.vn ', 'secret');

    expect(auth.isSignedIn, isTrue);
    expect(auth.email, 'a@dtc.vn');
    expect(prefs.getString('auth_refresh_token'), 'rt-1');
    expect(prefs.getInt('auth_last_verified_ms'), now.millisecondsSinceEpoch);
  });

  test('sai mật khẩu báo lỗi tiếng Việt', () async {
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => _error('INVALID_LOGIN_CREDENTIALS')),
    );
    await auth.restore(await SharedPreferences.getInstance());

    await expectLater(
      auth.signIn('a@dtc.vn', 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Email hoặc mật khẩu không đúng.',
        ),
      ),
    );
    expect(auth.isSignedIn, isFalse);
  });

  test('tài khoản bị khoá thì bị đăng xuất khi xác minh', () async {
    final prefs = await prefsWithSession(now.subtract(const Duration(days: 1)));
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => _error('USER_DISABLED')),
    );
    await auth.restore(prefs);
    expect(auth.isSignedIn, isTrue); // trong hạn offline → vào app ngay
    await auth.verify(force: true);

    expect(auth.isSignedIn, isFalse);
    expect(auth.notice, contains('bị khoá'));
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(prefs.getString('auth_email'), 'a@dtc.vn');
  });

  test('mất mạng trong 7 ngày vẫn dùng được', () async {
    final prefs = await prefsWithSession(now.subtract(const Duration(days: 6)));
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await auth.restore(prefs);
    await auth.verify(force: true);

    expect(auth.isSignedIn, isTrue);
    expect(prefs.getString('auth_refresh_token'), 'rt-1');
  });

  test('quá 7 ngày không xác minh được thì phải đăng nhập lại', () async {
    final prefs = await prefsWithSession(now.subtract(const Duration(days: 8)));
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await auth.restore(prefs);
    await auth.verify(force: true);

    expect(auth.isSignedIn, isFalse);
    expect(auth.canRetryVerify, isTrue);
    expect(auth.notice, contains('7 ngày'));
  });

  test('quá 7 ngày nhưng có mạng thì tự xác minh lại', () async {
    final prefs = await prefsWithSession(
      now.subtract(const Duration(days: 30)),
    );
    final auth = _createAuth(
      now: clock,
      client: MockClient((request) async {
        expect(request.url.host, 'securetoken.googleapis.com');
        return _json(200, {'refresh_token': 'rt-2', 'id_token': 'id'});
      }),
    );
    await auth.restore(prefs);
    expect(auth.isSignedIn, isFalse);
    await auth.verify(force: true);

    expect(auth.isSignedIn, isTrue);
    expect(prefs.getString('auth_refresh_token'), 'rt-2');
  });

  test('đăng xuất xoá phiên, giữ email', () async {
    final prefs = await prefsWithSession(now);
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => _json(200, {})),
    );
    await auth.restore(prefs);
    await auth.signOut();

    expect(auth.isSignedIn, isFalse);
    expect(auth.canRetryVerify, isFalse);
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(prefs.getString('auth_email'), 'a@dtc.vn');
  });

  testWidgets('màn hình đăng nhập hiện lỗi khi sai mật khẩu', (tester) async {
    final auth = _createAuth(
      now: clock,
      client: MockClient((_) async => _error('INVALID_PASSWORD')),
    );
    await auth.restore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login_email')), 'a@dtc.vn');
    await tester.enterText(find.byKey(const Key('login_password')), 'x');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });
}
