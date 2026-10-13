import 'dart:async';
import 'dart:convert';

import 'package:dtc_product/features/auth/screens/login_screen.dart';
import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _response(int status, Object body) =>
    http.Response(jsonEncode(body), status);
http.Response _refreshed([String token = 'rt-new']) =>
    _response(200, {'refresh_token': token, 'id_token': 'id'});
http.Response _signedIn(String email, String token) =>
    _response(200, {'email': email, 'refreshToken': token, 'idToken': 'id'});
http.Response _error(String code, [int status = 400]) => _response(status, {
  'error': {'message': code},
});

class _BlockingPreferences implements SharedPreferences {
  _BlockingPreferences(this.delegate);
  final SharedPreferences delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool _blocked = false;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  int? getInt(String key) => delegate.getInt(key);
  @override
  Future<bool> setString(String key, String value) async {
    if (!_blocked) {
      _blocked = true;
      entered.complete();
      await release.future;
    }
    return delegate.setString(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) => delegate.setInt(key, value);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 10, 9, 9);
    SharedPreferences.setMockInitialValues({});
  });
  AuthService create(http.Client client) {
    final auth = AuthService.test(client: client, now: () => now);
    addTearDown(auth.dispose);
    return auth;
  }

  Future<SharedPreferences> session({
    Duration age = Duration.zero,
    int? verifiedMs,
  }) async {
    SharedPreferences.setMockInitialValues({
      'auth_email': 'a@dtc.vn',
      'auth_refresh_token': 'rt-old',
      'auth_last_verified_ms':
          verifiedMs ?? now.subtract(age).millisecondsSinceEpoch,
      'personal_setting': 'keep',
    });
    return SharedPreferences.getInstance();
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  for (final reply in [_refreshed(), _error('USER_DISABLED')]) {
    test(
      'phản hồi refresh ${reply.statusCode} đến sau đăng xuất bị bỏ qua',
      () async {
        final pending = Completer<http.Response>();
        final prefs = await session();
        final auth = create(MockClient((_) => pending.future));
        await auth.restore(prefs);
        final verification = auth.verify(force: true);
        await flush();
        expect(auth.isVerifying, isTrue);
        await auth.signOut();
        expect(auth.isSignedIn, isFalse);
        pending.complete(reply);
        await verification;
        expect(auth.isSignedIn, isFalse);
        expect(auth.isVerifying, isFalse);
        expect(auth.canRetryVerify, isFalse);
        expect(auth.notice, isNull);
        expect(prefs.getString('auth_refresh_token'), isNull);
        expect(prefs.getInt('auth_last_verified_ms'), isNull);
        expect(prefs.getString('auth_email'), 'a@dtc.vn');
        expect(prefs.getString('personal_setting'), 'keep');
      },
    );
  }

  for (final reply in [_refreshed('rt-A'), _error('TOKEN_EXPIRED')]) {
    test(
      'refresh cũ ${reply.statusCode} không đổi hoặc đăng xuất tài khoản B',
      () async {
        final pending = Completer<http.Response>();
        final prefs = await session();
        final auth = create(
          MockClient((request) {
            if (request.url.path.contains('signInWithPassword')) {
              return Future.value(_signedIn('b@dtc.vn', 'rt-B'));
            }
            return pending.future;
          }),
        );
        await auth.restore(prefs);
        final verification = auth.verify(force: true);
        await flush();
        await auth.signIn('b@dtc.vn', 'password');
        pending.complete(reply);
        await verification;
        expect(auth.isSignedIn, isTrue);
        expect(auth.email, 'b@dtc.vn');
        expect(prefs.getString('auth_refresh_token'), 'rt-B');
        expect(auth.notice, isNull);
      },
    );
  }

  test('đăng xuất khi đăng nhập đang chạy không khôi phục phiên', () async {
    final pending = Completer<http.Response>();
    final prefs = await SharedPreferences.getInstance();
    final auth = create(MockClient((_) => pending.future));
    await auth.restore(prefs);
    final login = auth.signIn('a@dtc.vn', 'password');
    await flush();
    await auth.signOut();
    pending.complete(_signedIn('a@dtc.vn', 'rt-A'));
    await login;
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getString('auth_refresh_token'), isNull);
  });

  test(
    'đăng nhập B thất bại không khôi phục tài khoản A đang ghi nhớ',
    () async {
      final prefs = await session();
      var refreshes = 0;
      final auth = create(
        MockClient((request) async {
          if (request.url.path.contains('signInWithPassword')) {
            return _error('INVALID_PASSWORD');
          }
          refreshes++;
          return _refreshed('rt-A');
        }),
      );
      await auth.restore(prefs);
      await expectLater(
        auth.signIn('b@dtc.vn', 'wrong'),
        throwsA(isA<AuthException>()),
      );
      await auth.verify(force: true);
      expect(auth.isSignedIn, isFalse);
      expect(auth.canRetryVerify, isFalse);
      expect(refreshes, 0);
      expect(prefs.getString('auth_refresh_token'), isNull);
    },
  );

  test('hai lần đăng nhập về ngược thứ tự vẫn giữ yêu cầu mới nhất', () async {
    final oldReply = Completer<http.Response>();
    final auth = create(
      MockClient((request) {
        final email = (jsonDecode(request.body) as Map)['email'];
        return email == 'a@dtc.vn'
            ? oldReply.future
            : Future.value(_signedIn('b@dtc.vn', 'rt-B'));
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    await auth.restore(prefs);
    final oldLogin = auth.signIn('a@dtc.vn', 'password');
    await auth.signIn('b@dtc.vn', 'password');
    oldReply.complete(_signedIn('a@dtc.vn', 'rt-A'));
    await oldLogin;
    expect(auth.email, 'b@dtc.vn');
    expect(prefs.getString('auth_refresh_token'), 'rt-B');
  });

  test('hoàn tất refresh cũ không gỡ khóa của refresh mới đang chạy', () async {
    final oldReply = Completer<http.Response>();
    final newReply = Completer<http.Response>();
    final auth = create(
      MockClient((request) {
        if (request.url.path.contains('signInWithPassword')) {
          return Future.value(_signedIn('b@dtc.vn', 'rt-B'));
        }
        return request.body.contains('rt-old')
            ? oldReply.future
            : newReply.future;
      }),
    );
    await auth.restore(await session());
    final oldVerify = auth.verify(force: true);
    await flush();
    await auth.signIn('b@dtc.vn', 'password');
    final newVerify = auth.verify(force: true);
    await flush();
    oldReply.complete(_refreshed('rt-A'));
    await oldVerify;
    expect(auth.isVerifying, isTrue);
    expect(identical(auth.verify(force: true), newVerify), isTrue);
    newReply.complete(_refreshed('rt-B2'));
    await newVerify;
    expect(auth.email, 'b@dtc.vn');
    expect(auth.isVerifying, isFalse);
  });

  test(
    'đăng xuất trong lúc ghi phiên xóa cả token và mốc thời gian ghi muộn',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final blocking = _BlockingPreferences(prefs);
      final auth = create(
        MockClient((_) async => _signedIn('a@dtc.vn', 'rt-A')),
      );
      await auth.restore(blocking);
      final login = auth.signIn('a@dtc.vn', 'password');
      await blocking.entered.future;
      final logout = auth.signOut();
      expect(auth.isSignedIn, isFalse);
      blocking.release.complete();
      await Future.wait([login, logout]);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getInt('auth_last_verified_ms'), isNull);
      expect(auth.isSignedIn, isFalse);
    },
  );

  test(
    'ghi phiên cũ, đăng xuất, đăng nhập B chạy tuần tự và lưu đúng B',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final blocking = _BlockingPreferences(prefs);
      final auth = create(
        MockClient((request) async {
          final email = (jsonDecode(request.body) as Map)['email'] as String;
          return _signedIn(email, email.startsWith('a') ? 'rt-A' : 'rt-B');
        }),
      );
      await auth.restore(blocking);
      final oldLogin = auth.signIn('a@dtc.vn', 'password');
      await blocking.entered.future;
      final logout = auth.signOut();
      final newLogin = auth.signIn('b@dtc.vn', 'password');
      blocking.release.complete();
      await Future.wait([oldLogin, logout, newLogin]);
      expect(auth.isSignedIn, isTrue);
      expect(auth.email, 'b@dtc.vn');
      expect(prefs.getString('auth_email'), 'b@dtc.vn');
      expect(prefs.getString('auth_refresh_token'), 'rt-B');
      expect(prefs.getInt('auth_last_verified_ms'), now.millisecondsSinceEpoch);
    },
  );

  for (final code in [
    'USER_DISABLED',
    'USER_NOT_FOUND',
    'TOKEN_EXPIRED',
    'INVALID_REFRESH_TOKEN',
  ]) {
    test('lỗi phiên $code thu hồi truy cập và xóa phiên', () async {
      final prefs = await session();
      final auth = create(MockClient((_) async => _error('$code : detail')));
      await auth.restore(prefs);
      await auth.verify(force: true);
      expect(auth.isSignedIn, isFalse);
      expect(auth.canRetryVerify, isFalse);
      expect(auth.notice, isNotNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
    });
  }

  for (final reply in [
    _error('PROJECT_NUMBER_MISMATCH'),
    _error('TOO_MANY_ATTEMPTS_TRY_LATER', 429),
    _error('SERVER_ERROR', 503),
  ]) {
    test(
      'lỗi máy chủ ${reply.statusCode} không xóa phiên còn hạn offline',
      () async {
        final prefs = await session(age: const Duration(days: 6));
        final verified = prefs.getInt('auth_last_verified_ms');
        final auth = create(MockClient((_) async => reply));
        await auth.restore(prefs);
        await auth.verify(force: true);
        expect(auth.isSignedIn, isTrue);
        expect(prefs.getString('auth_refresh_token'), 'rt-old');
        expect(prefs.getInt('auth_last_verified_ms'), verified);
      },
    );
  }

  final malformed = [
    http.Response('<html>error</html>', 200),
    _response(200, {}),
    _response(200, {'refreshToken': 'rt', 'email': 'a@dtc.vn'}),
    _response(200, {'refreshToken': 123, 'idToken': 'id', 'email': 'a@dtc.vn'}),
    _response(200, {'refreshToken': '', 'idToken': 'id', 'email': 'a@dtc.vn'}),
  ];
  for (var i = 0; i < malformed.length; i++) {
    test('đăng nhập với phản hồi lỗi dạng $i không cấp phiên', () async {
      final prefs = await SharedPreferences.getInstance();
      final auth = create(MockClient((_) async => malformed[i]));
      await auth.restore(prefs);
      await expectLater(
        auth.signIn('a@dtc.vn', 'password'),
        throwsA(isA<AuthException>()),
      );
      expect(auth.isSignedIn, isFalse);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getInt('auth_last_verified_ms'), isNull);
    });
  }

  for (final age in [const Duration(days: 6), const Duration(days: 8)]) {
    for (final reply in [
      http.Response('bad-json', 200),
      _response(200, {}),
      _response(200, {'refresh_token': 'rt-new'}),
    ]) {
      test(
        'refresh thiếu dữ liệu, tuổi phiên ${age.inDays} ngày không gia hạn offline',
        () async {
          final prefs = await session(age: age);
          final verified = prefs.getInt('auth_last_verified_ms');
          final auth = create(MockClient((_) async => reply));
          await auth.restore(prefs);
          await auth.verify(force: true);
          expect(auth.isSignedIn, age.inDays < 7);
          expect(prefs.getString('auth_refresh_token'), 'rt-old');
          expect(prefs.getInt('auth_last_verified_ms'), verified);
          if (age.inDays > 7) {
            expect(auth.canRetryVerify, isTrue);
            expect(auth.notice, contains('dữ liệu'));
          }
        },
      );
    }
  }

  test(
    'thời gian xác minh nằm trong tương lai không cho dùng offline',
    () async {
      final auth = create(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      await auth.restore(
        await session(
          verifiedMs: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        ),
      );
      await auth.verify(force: true);
      expect(auth.isSignedIn, isFalse);
      expect(auth.canRetryVerify, isTrue);
      expect(auth.notice, contains('Thời gian'));
    },
  );

  test(
    'mốc thời gian lưu ngoài miền DateTime không làm crash khởi động',
    () async {
      final auth = create(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      await auth.restore(await session(verifiedMs: 9223372036854775807));
      await auth.verify(force: true);
      expect(auth.isSignedIn, isFalse);
      expect(auth.notice, contains('Chưa có lần xác minh'));
    },
  );

  test(
    'dispose trong khi xác minh không thông báo hoặc khôi phục phiên',
    () async {
      final pending = Completer<http.Response>();
      final auth = AuthService.test(
        client: MockClient((_) => pending.future),
        now: () => now,
      );
      await auth.restore(await session());
      final verification = auth.verify(force: true);
      await flush();
      var notifications = 0;
      auth.addListener(() => notifications++);
      auth.dispose();
      pending.complete(_refreshed());
      await verification;
      expect(notifications, 0);
    },
  );

  testWidgets('mất mạng chỉ thử tự động mỗi giờ, không gửi yêu cầu mỗi phút', (
    tester,
  ) async {
    var requests = 0;
    final auth = AuthService.test(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('offline');
      }),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await auth.restore(await session(age: const Duration(hours: 2)));
    await auth.verify();
    expect(requests, 1);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(requests, 1);
    now = now.add(const Duration(minutes: 59));
    await tester.pump(const Duration(minutes: 59));
    await tester.pump();
    expect(requests, 2);
    expect(auth.isSignedIn, isTrue);
    auth.dispose();
  });

  testWidgets(
    'mạng không trả lời hết thời gian chờ thì hiện Thử lại, không treo spinner',
    (tester) async {
      final pending = Completer<http.Response>();
      final auth = AuthService.test(
        now: () => now,
        client: MockClient((_) => pending.future),
      );
      await auth.restore(await session(age: const Duration(days: 8)));
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
      await tester.pump();
      expect(find.text('Đang xác minh tài khoản...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(auth.isSignedIn, isFalse);
      expect(auth.isVerifying, isFalse);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Đang xác minh tài khoản...'), findsNothing);
      await auth.signOut();
      pending.complete(_refreshed());
      await tester.pumpAndSettle();
      expect(auth.isSignedIn, isFalse);
      expect(auth.canRetryVerify, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets('app mở liên tục xác minh sau một giờ, không gọi mỗi phút', (
    tester,
  ) async {
    var requests = 0;
    final auth = AuthService.test(
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return _refreshed();
      }),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await auth.restore(await session());
    await tester.pump(const Duration(minutes: 59));
    expect(requests, 0);
    now = now.add(const Duration(hours: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(requests, 1);
    await tester.pump(const Duration(minutes: 5));
    expect(requests, 1);
    auth.dispose();
  });

  testWidgets('hết hạn offline trong lúc app mở chặn ngay dù HTTP chưa trả', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final auth = AuthService.test(
      now: () => now,
      client: MockClient((_) => pending.future),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await auth.restore(await session(age: const Duration(days: 7)));
    expect(auth.isSignedIn, isTrue);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(auth.isSignedIn, isFalse);
    expect(auth.notice, contains('7 ngày'));
    expect(auth.canRetryVerify, isTrue);
    pending.complete(_refreshed());
    await auth.verify(force: true);
    expect(auth.isSignedIn, isTrue);
    auth.dispose();
  });

  testWidgets(
    'vào nền dừng kiểm tra; quay lại xác minh và xử lý tài khoản khóa',
    (tester) async {
      var requests = 0;
      final auth = AuthService.test(
        now: () => now,
        client: MockClient((_) async {
          requests++;
          return _error('USER_DISABLED');
        }),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await auth.restore(await session());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 2));
      await tester.pump(const Duration(hours: 2));
      expect(requests, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await auth.verify();
      expect(requests, 1);
      expect(auth.isSignedIn, isFalse);
      expect(auth.notice, contains('bị khoá'));
      auth.dispose();
    },
  );

  testWidgets(
    'màn hình 320px hiển thị đang xác minh, lỗi và Thử lại thành công',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<http.Response>();
      var requests = 0;
      final auth = AuthService.test(
        now: () => now,
        client: MockClient((_) {
          requests++;
          return requests == 1 ? pending.future : Future.value(_refreshed());
        }),
      );
      await auth.restore(await session(age: const Duration(days: 8)));
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
      await tester.pump();
      expect(find.text('Đang xác minh tài khoản...'), findsOneWidget);
      pending.complete(_error('SERVER_ERROR', 503));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(auth.isSignedIn, isTrue);
      expect(auth.notice, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets('quên mật khẩu khóa bấm lặp và không cập nhật màn hình đã đóng', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final auth = AuthService.test(
      client: MockClient((_) {
        requests++;
        return pending.future;
      }),
    );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.enterText(find.byKey(const Key('login_email')), 'a@dtc.vn');
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login_submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Quên mật khẩu?'));
    expect(requests, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete(_response(200, {'email': 'a@dtc.vn'}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    auth.dispose();
  });
}
