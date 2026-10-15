import 'package:dtc_product/models/acomp_spec_model.dart';
import 'package:dtc_product/providers/acomp_spec_provider.dart';
import 'package:dtc_product/screens/acomp/acomp_tech_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'danh sách 4 trong 1: 8 model ACA, cùng công suất thì cố định trước',
    () {
      final list = AcompSpecProvider().fourInOneList;
      expect(list.map((m) => m.modelCode), [
        'ACA-10F',
        'ACA-10PV',
        'ACA-15F',
        'ACA-15PV',
        'ACA-20F',
        'ACA-20PV',
        'ACA-30F',
        'ACA-30PV',
      ]);
      expect(list.first.airTank, 380);
      expect(list.last.airTank, 500);
    },
  );

  testWidgets('màn thông số 4 trong 1 hiện bình chứa, không có nút so sánh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AcompSpecProvider(),
        child: const MaterialApp(
          home: AcompTechDetailScreen(categoryType: '4IN1'),
        ),
      ),
    );
    expect(find.text('Trục vít 4 trong 1 (ACA)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<AcompSpecModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ACA-10PV').last);
    await tester.pumpAndSettle();

    expect(find.text('Thông số Model: ACA-10PV'), findsOneWidget);
    expect(find.text('Biến tần PM VSD'), findsOneWidget);
    expect(find.text('Bình chứa khí tích hợp'), findsOneWidget);
    expect(find.text('380.0 Lít'), findsOneWidget);
    expect(find.byKey(const Key('acomp_compare_same_size')), findsNothing);
  });
}
