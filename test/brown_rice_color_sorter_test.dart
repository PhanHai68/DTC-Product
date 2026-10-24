import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/providers/paddy_color_sorter_provider.dart';
import 'package:dtc_product/screens/color_sorter_categories_screen.dart';
import 'package:dtc_product/screens/paddy_color_sorter/paddy_aux_equip_screen.dart';
import 'package:dtc_product/screens/paddy_color_sorter/paddy_color_sorter_menu_screen.dart';
import 'package:dtc_product/screens/paddy_color_sorter/paddy_color_sorter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lúa và Gạo lứt: dữ liệu giống Lúa giống, file riêng', () {
    expect(brownRiceColorSorterSpecs, hasLength(paddyColorSorterSpecs.length));
    for (var i = 0; i < paddyColorSorterSpecs.length; i++) {
      final paddy = {...paddyColorSorterSpecs[i]}
        ..remove('Nguyên liệu phù hợp');
      final brown = {...brownRiceColorSorterSpecs[i]}
        ..remove('Nguyên liệu phù hợp');
      expect(brown, paddy, reason: paddy['Model']);
      expect(
        brownRiceColorSorterSpecs[i]['Nguyên liệu phù hợp'],
        'Lúa và gạo lứt',
      );
    }
    expect(
      identical(sfLineSpecs(ColorSorterLine.brownRice), paddyColorSorterSpecs),
      isFalse,
    );
    expect(
      powerConsumptionModels(ColorSorterLine.brownRice),
      powerConsumptionModels(ColorSorterLine.paddy),
    );
  });

  test('provider dòng Lúa và Gạo lứt tra theo dữ liệu của dòng', () {
    final provider = PaddyColorSorterProvider(line: ColorSorterLine.brownRice);
    expect(provider.selectedModel, 'SF7D Pro');
    expect(provider.specs?['Nguyên liệu phù hợp'], 'Lúa và gạo lứt');
    expect(provider.suggestModelByCapacity(4)?['model'], 'SF7D Pro');
  });

  testWidgets('menu Máy tách màu: Lúa và Gạo lứt nằm ngay dưới Lúa giống', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ColorSorterCategoriesScreen()),
    );
    await tester.pumpAndSettle();

    // Thứ tự đọc của lưới: trên xuống, rồi trái sang phải.
    bool before(String a, String b) {
      final pa = tester.getTopLeft(find.byKey(Key(a)));
      final pb = tester.getTopLeft(find.byKey(Key(b)));
      return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
    }

    expect(find.text('Lúa và Gạo lứt'), findsOneWidget);
    expect(before('category_paddy', 'category_brown_rice'), isTrue);
    expect(before('category_brown_rice', 'category_tea'), isTrue);
  });

  testWidgets('menu dòng Lúa và Gạo lứt có tiêu đề riêng', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaddyColorSorterMenuScreen(line: ColorSorterLine.brownRice),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Máy tách màu Lúa và Gạo lứt'), findsOneWidget);
    expect(find.text('Thông số kỹ thuật'), findsOneWidget);
    expect(find.text('Thiết bị phụ trợ'), findsOneWidget);
    expect(find.text('Phân tích hoàn vốn'), findsOneWidget);
    expect(find.text('Tra cứu lỗi'), findsOneWidget);
  });

  testWidgets('thiết bị phụ trợ dòng Lúa và Gạo lứt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: PaddyAuxEquipScreen(line: ColorSorterLine.brownRice),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị phụ trợ SF7D Pro'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'SF3D Pro'), findsOneWidget);
  });

  for (final line in [ColorSorterLine.brownRice, ColorSorterLine.paddy]) {
    for (final model in sfLineSpecs(line).map((s) => s['Model']!)) {
      testWidgets('Chi Tiết Ứng Dụng ${line.name} $model', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: PaddyColorSorterScreen(line: line, initialModel: model),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.text('Chi Tiết Ứng Dụng');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        final brown = line == ColorSorterLine.brownRice;
        expect(
          find.textContaining('Giảm Gãy Vỡ'),
          brown ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('AI Super Agent PRO'),
          brown ? findsOneWidget : findsNothing,
        );
        expect(find.text('≤ 2%'), brown ? findsOneWidget : findsNothing);
        expect(find.text('≥ 3%'), brown ? findsOneWidget : findsNothing);
        expect(find.text('≥ 5%'), brown ? findsOneWidget : findsNothing);
        expect(
          find.textContaining('dòng SFD PRO'),
          brown ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
