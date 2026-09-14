import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('DTC Product'), findsOneWidget);
  });
}
