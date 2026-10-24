import 'package:dtc_product/core/input/vnd_words.dart';
import 'package:dtc_product/widgets/money_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vndToWords', () {
    test('đọc số nhỏ đúng mốt / tư / lăm / linh / mười', () {
      expect(vndToWords(0), 'Không đồng');
      expect(vndToWords(5), 'Năm đồng');
      expect(vndToWords(10), 'Mười đồng');
      expect(vndToWords(11), 'Mười một đồng');
      expect(vndToWords(14), 'Mười bốn đồng');
      expect(vndToWords(15), 'Mười lăm đồng');
      expect(vndToWords(21), 'Hai mươi mốt đồng');
      expect(vndToWords(24), 'Hai mươi tư đồng');
      expect(vndToWords(25), 'Hai mươi lăm đồng');
      expect(vndToWords(100), 'Một trăm đồng');
      expect(vndToWords(105), 'Một trăm linh năm đồng');
      expect(vndToWords(110), 'Một trăm mười đồng');
    });

    test('đọc hàng nghìn, triệu, tỷ', () {
      expect(vndToWords(1811), 'Một nghìn tám trăm mười một đồng');
      expect(vndToWords(1005), 'Một nghìn không trăm linh năm đồng');
      expect(vndToWords(1205000), 'Một triệu hai trăm linh năm nghìn đồng');
      expect(vndToWords(1000005), 'Một triệu không trăm linh năm đồng');
      expect(vndToWords(16000000000), 'Mười sáu tỷ đồng');
      expect(
        vndToWords(2000050000),
        'Hai tỷ không trăm năm mươi nghìn đồng',
      );
      expect(vndToWords(1500000000000), 'Một nghìn năm trăm tỷ đồng');
      expect(
        vndToWords(999999999999999),
        'Chín trăm chín mươi chín nghìn chín trăm chín mươi chín tỷ '
        'chín trăm chín mươi chín triệu chín trăm chín mươi chín nghìn '
        'chín trăm chín mươi chín đồng',
      );
    });

    test('vndTextToWords đọc chuỗi có dấu phẩy, bỏ qua ô trống', () {
      expect(vndTextToWords('16,000,000,000'), 'Mười sáu tỷ đồng');
      expect(vndTextToWords(''), isNull);
      expect(vndTextToWords('12,500.5'), isNull);
    });
  });

  group('MoneyFormField', () {
    Future<void> pump(WidgetTester tester, Widget field) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Form(child: field))),
    );

    testWidgets('gõ số thì có dấu phẩy, đơn vị VNĐ và chữ bên dưới', (
      tester,
    ) async {
      String? changed;
      await pump(
        tester,
        MoneyFormField(
          labelText: 'Giá máy',
          helperText: 'Gợi ý',
          onChanged: (v) => changed = v,
        ),
      );
      expect(find.text('VNĐ'), findsOneWidget);
      expect(find.text('Gợi ý'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '16000000000');
      await tester.pump();

      expect(find.text('16,000,000,000'), findsOneWidget);
      expect(find.text('Mười sáu tỷ đồng'), findsOneWidget);
      expect(find.text('Gợi ý'), findsNothing);
      expect(changed, '16000000000');
    });

    testWidgets('showWords: false (USD) không hiện chữ, cho số lẻ', (
      tester,
    ) async {
      await pump(
        tester,
        const MoneyFormField(unit: 'USD', showWords: false, decimalDigits: 2),
      );
      await tester.enterText(find.byType(TextFormField), '12500.50');
      await tester.pump();
      expect(find.text('12,500.50'), findsOneWidget);
      expect(find.textContaining('đồng'), findsNothing);
    });

    testWidgets('controller điền sẵn cũng hiện chữ', (tester) async {
      final controller = TextEditingController(text: '1,811');
      addTearDown(controller.dispose);
      await pump(tester, MoneyFormField(controller: controller));
      expect(find.text('Một nghìn tám trăm mười một đồng'), findsOneWidget);
      controller.text = '2,000';
      await tester.pump();
      expect(find.text('Hai nghìn đồng'), findsOneWidget);
    });
  });
}
