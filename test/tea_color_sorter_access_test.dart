import 'package:dtc_product/providers/tea_color_sorter_provider.dart';
import 'package:dtc_product/screens/color_sorter_categories_screen.dart';
import 'package:dtc_product/screens/tea_color_sorter/tea_color_sorter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<void> _pumpTeaSpecs(WidgetTester tester, {required String model}) async {
  final provider = TeaColorSorterProvider()..selectModel(model);
  addTearDown(provider.dispose);

  final router = GoRouter(
    initialLocation: '/tea_color_sorter',
    routes: [
      GoRoute(
        path: '/tea_color_sorter',
        builder: (_, _) => const TeaColorSorterScreen(),
      ),
      GoRoute(
        path: '/tea_aux_equip',
        builder: (_, state) => Scaffold(body: Text('Auxiliary ${state.extra}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<TeaColorSorterProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAuxiliaryButton(WidgetTester tester) async {
  final button = find.byKey(const Key('tea_aux_equip_button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('DF53 Pro mở được thiết bị phụ trợ đồng bộ', (tester) async {
    await _pumpTeaSpecs(tester, model: 'DF53 Pro');

    final button = find.byKey(const Key('tea_aux_equip_button'));
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.settings_outlined),
      ),
      findsOneWidget,
    );

    await _tapAuxiliaryButton(tester);

    expect(find.text('Auxiliary DF53 Pro'), findsOneWidget);
  });

  testWidgets('model trà khác DF53 Pro chỉ hiện thông báo đang phát triển', (
    tester,
  ) async {
    await _pumpTeaSpecs(tester, model: 'DF36 Pro');

    await _tapAuxiliaryButton(tester);

    expect(
      find.text('Chức năng đang được phát triển. Vui lòng quay lại sau!'),
      findsOneWidget,
    );
    expect(find.textContaining('Auxiliary'), findsNothing);
  });

  testWidgets('Khoáng sản dùng icon khối đá thay cho kim cương', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ColorSorterCategoriesScreen()),
    );
    await tester.pumpAndSettle();

    final mineralCard = find.byKey(const Key('category_mineral'));
    expect(
      find.descendant(
        of: mineralCard,
        matching: find.byIcon(Icons.terrain_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mineralCard,
        matching: find.byIcon(Icons.diamond_rounded),
      ),
      findsNothing,
    );
  });
}
