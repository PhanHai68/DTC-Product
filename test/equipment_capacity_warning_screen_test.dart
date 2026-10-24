import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/acomp_suitable_provider.dart';
import 'package:dtc_product/providers/acomp_tank_provider.dart';
import 'package:dtc_product/screens/acomp/acomp_suitable_screen.dart';
import 'package:dtc_product/screens/acomp/acomp_tank_screen.dart';
import 'package:dtc_product/screens/color_sorter/color_sorter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('máy nén vượt dải hiển thị cảnh báo, không ghi đề xuất 90 kW', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = AcompSuitableProvider()
      ..setMaterial(materialDataList.first)
      ..setEjectorCount('100000');
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: AcompSuitableScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('vượt 90 kW'), findsOneWidget);
    expect(find.text('90 kW'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bình vượt dải cảnh báo; nhập lại giá trị hợp lệ khôi phục đề xuất',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = AcompTankProvider()..setQc('100');
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AcompTankScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('vượt 15.000 lít'), findsOneWidget);
      expect(find.text('15000 Lít'), findsNothing);
      expect(
        find.byKey(const Key('acomp_tank_recommended_details')),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '100.0',
      );
      await tester.enterText(find.byType(TextField).first, '19,5');
      await tester.pumpAndSettle();
      expect(find.textContaining('vượt 15.000 lít'), findsNothing);
      // 3.355,5 lít → bình nhỏ nhất không nhỏ hơn là V4000.
      expect(find.text('4000 Lít'), findsOneWidget);
      expect(find.text('V4000'), findsOneWidget);
      expect(find.text('10 kgf/cm²'), findsOneWidget);
      expect(find.text('15 kgf/cm²'), findsOneWidget);
      expect(find.text('1.450 mm'), findsOneWidget);
      expect(find.text('1.185 kg'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1,0');
      await tester.pumpAndSettle();
      expect(find.text('200 Lít'), findsOneWidget);
      provider.setDeltaP('0');
      await tester.pump();
      expect(find.textContaining('phải lớn hơn 0'), findsOneWidget);
      expect(find.text('0 Lít'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tư vấn màu gỡ nút xem model khi vượt dải hoặc đầu vào sai/rỗng',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ColorSorterScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tư vấn chọn máy'));
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, '16,1');
      await tester.pumpAndSettle();
      expect(find.text('Xem chi tiết SC16 Pro'), findsOneWidget);
      await tester.enterText(input, '22,1');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có đề xuất phù hợp'), findsOneWidget);
      expect(find.textContaining('vượt mức tối đa 22'), findsOneWidget);
      expect(find.text('Xem chi tiết SC16 Pro'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      await tester.enterText(input, 'abc');
      await tester.pumpAndSettle();
      expect(find.textContaining('số hữu hạn lớn hơn 0'), findsOneWidget);
      expect(find.text('Xem chi tiết SC16 Pro'), findsNothing);
      await tester.enterText(input, '');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có đề xuất phù hợp'), findsNothing);
      expect(find.text('Xem chi tiết SC16 Pro'), findsNothing);
      await tester.enterText(input, '6');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết SC4'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('SC4'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
