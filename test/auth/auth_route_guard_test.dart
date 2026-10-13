import 'package:dtc_product/features/auth/services/auth_service.dart';
import 'package:dtc_product/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('chưa đăng nhập mở đường dẫn module vẫn về login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.signOut();
    appRouter.go('/acomp_menu');
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.text('Máy nén khí ACOMP'), findsNothing);
    appRouter.go('/machine_selector');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.text('Chọn Máy Theo Yêu Cầu'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('đăng xuất khỏi module chuyển login và chặn mở lại đường dẫn', (
    tester,
  ) async {
    AuthService.instance.debugSetSignedIn('a@dtc.vn');
    appRouter.go('/acomp_menu');
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    expect(find.text('Máy nén khí ACOMP'), findsOneWidget);
    await AuthService.instance.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    appRouter.go('/acomp_menu');
    await tester.pumpAndSettle();
    expect(find.text('Máy nén khí ACOMP'), findsNothing);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
