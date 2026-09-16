import 'package:dtc_product/screens/global_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('global search finds a color sorter model', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: GlobalSearchScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'SC12');
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'SC12'), findsOneWidget);
    expect(find.text('Máy tách màu Gạo'), findsOneWidget);
  });
}
