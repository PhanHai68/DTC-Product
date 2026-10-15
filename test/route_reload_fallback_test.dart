import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:dtc_product/providers/acomp_spec_provider.dart';
import 'package:dtc_product/providers/storage_provider.dart';
import 'package:dtc_product/routes/app_routes.dart';
import 'package:dtc_product/screens/storage/storage_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tải lại trang web (hoặc hệ điều hành khôi phục app) làm mất `extra` của
/// route: các màn phải tự lấy dữ liệu từ địa chỉ hoặc quay về màn cha, không
/// được hiện màn lỗi.
void main() {
  Future<void> open(WidgetTester tester, String location) async {
    AuthService.instance.debugSetSignedIn('a@dtc.vn');
    appRouter.go(location);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AcompSpecProvider()),
          ChangeNotifierProvider(create: (_) => StorageProvider()),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pump();
  }

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.signOut();
  });

  testWidgets('thông số máy nén khí đọc loại máy từ địa chỉ', (tester) async {
    await open(tester, '/acomp_tech_detail?type=4IN1');
    expect(find.text('Trục vít 4 trong 1 (ACA)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final path in ['/storage/pdf', '/storage/image', '/storage/model']) {
    testWidgets('$path không có tệp thì về Bộ nhớ & Tệp đã lưu', (
      tester,
    ) async {
      await open(tester, path);
      expect(tester.takeException(), isNull);
      expect(find.byType(StorageOverviewScreen), findsOneWidget);
    });
  }
}
