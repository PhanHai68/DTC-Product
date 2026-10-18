import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:dtc_product/features/auth/services/session_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secure = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('token của bản cũ được chuyển sang kho bảo mật', () async {
    SharedPreferences.setMockInitialValues({'auth_refresh_token': 'rt-old'});
    final prefs = await SharedPreferences.getInstance();
    final store = SecureSessionTokenStore();

    expect(await store.read(prefs), 'rt-old');
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(await secure.read(key: 'auth_refresh_token'), 'rt-old');
    // Lần đọc sau lấy từ kho bảo mật.
    expect(await store.read(prefs), 'rt-old');
  });

  test('ghi và xóa chỉ dùng kho bảo mật', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SecureSessionTokenStore();

    await store.write(prefs, 'rt-1');
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(await store.read(prefs), 'rt-1');

    await store.delete(prefs);
    expect(await store.read(prefs), isNull);
  });

  test('cập nhật app không bắt đăng nhập lại', () async {
    final now = DateTime(2026, 10, 18, 9);
    SharedPreferences.setMockInitialValues({
      'auth_email': 'a@dtc.vn',
      'auth_refresh_token': 'rt-old',
      'auth_last_verified_ms': now.millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService.test(
      client: MockClient((_) async => http.Response('{}', 503)),
      now: () => now,
      tokenStore: SecureSessionTokenStore(),
    );
    addTearDown(auth.dispose);

    await auth.restore(prefs);

    expect(auth.isSignedIn, isTrue);
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(await secure.read(key: 'auth_refresh_token'), 'rt-old');

    await auth.signOut();
    expect(await secure.read(key: 'auth_refresh_token'), isNull);
  });
}
