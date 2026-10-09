import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:dtc_product/main.dart';
import 'package:dtc_product/providers/settings_provider.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    AuthService.instance.debugSetSignedIn('test@dtc.vn');
    await tester.pumpWidget(MyApp(settingsProvider: SettingsProvider(prefs)));
    expect(find.byKey(const Key('home_brand_wordmark')), findsOneWidget);
  });
}
