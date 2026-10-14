import 'dart:convert';

import 'package:dtc_product/features/auth/screens/change_password_dialog.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 14, 9);
  });

  Future<(AuthService, SharedPreferences)> signedIn(
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_email': 'a@dtc.vn',
      'auth_refresh_token': 'rt-old',
      'auth_last_verified_ms': now.millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService.test(client: MockClient(handler), now: () => now);
    addTearDown(auth.dispose);
    await auth.restore(prefs);
    return (auth, prefs);
  }

  test('đổi mật khẩu: xác minh mật khẩu cũ rồi lưu phiên mới', () async {
    final calls = <String>[];
    final (auth, prefs) = await signedIn((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('accounts:signInWithPassword')) {
        calls.add('signIn');
        expect(body['email'], 'a@dtc.vn');
        expect(body['password'], 'old-pass');
        return _json(200, {
          'email': 'a@dtc.vn',
          'idToken': 'id-fresh',
          'refreshToken': 'rt-signin',
        });
      }
      if (request.url.path.endsWith('accounts:update')) {
        calls.add('update');
        expect(body['idToken'], 'id-fresh');
        expect(body['password'], 'new-pass');
        return _json(200, {
          'email': 'a@dtc.vn',
          'idToken': 'id-new',
          'refreshToken': 'rt-new',
        });
      }
      fail('Không mong đợi gọi ${request.url}');
    });

    await auth.changePassword('old-pass', 'new-pass');

    expect(calls, ['signIn', 'update']);
    expect(auth.isSignedIn, isTrue);
    expect(prefs.getString('auth_refresh_token'), 'rt-new');
  });

  test('sai mật khẩu hiện tại: báo lỗi, giữ nguyên phiên', () async {
    final (auth, prefs) = await signedIn((request) async {
      if (request.url.path.endsWith('accounts:signInWithPassword')) {
        return _error('INVALID_LOGIN_CREDENTIALS');
      }
      fail('Không được gọi đổi mật khẩu khi sai mật khẩu cũ');
    });

    await expectLater(
      auth.changePassword('wrong', 'new-pass'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Mật khẩu hiện tại không đúng.',
        ),
      ),
    );
    expect(auth.isSignedIn, isTrue);
    expect(prefs.getString('auth_refresh_token'), 'rt-old');
  });

  test('mật khẩu mới quá yếu: báo lỗi tiếng Việt', () async {
    final (auth, _) = await signedIn((request) async {
      if (request.url.path.endsWith('accounts:signInWithPassword')) {
        return _json(200, {
          'email': 'a@dtc.vn',
          'idToken': 'id-fresh',
          'refreshToken': 'rt-signin',
        });
      }
      return _error(
        'WEAK_PASSWORD : Password should be at least 6 characters',
      );
    });

    await expectLater(
      auth.changePassword('old-pass', '123'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('ít nhất 6 ký tự'),
        ),
      ),
    );
    expect(auth.isSignedIn, isTrue);
  });

  testWidgets('hộp thoại kiểm tra nhập lại và mật khẩu ngắn trước khi gửi', (
    tester,
  ) async {
    var requests = 0;
    final auth = AuthService.test(
      client: MockClient((_) async {
        requests++;
        return _error('INVALID_LOGIN_CREDENTIALS');
      }),
      now: () => now,
    );
    addTearDown(auth.dispose);
    auth.debugSetSignedIn('a@dtc.vn');

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChangePasswordDialog(auth: auth))),
    );
    await tester.enterText(
      find.byKey(const Key('current_password_field')),
      'old-pass',
    );
    await tester.enterText(find.byKey(const Key('new_password_field')), '123');
    await tester.enterText(
      find.byKey(const Key('confirm_password_field')),
      '456',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pump();

    expect(find.text('Mật khẩu mới cần ít nhất 6 ký tự'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    expect(requests, 0);
  });
}
