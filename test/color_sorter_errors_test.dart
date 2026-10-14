import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/screens/color_sorter_errors/color_sorter_errors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dữ liệu tra cứu lỗi khớp file Excel CAC_LOI_THUONG_GAP_MAY_TACH_MAU', () {
    final data = colorSorterErrors;
    expect(data.common, hasLength(17));
    expect(data.detailed, hasLength(11));
    expect(data.poorSorting, hasLength(10));
    expect(data.blocks, hasLength(12));
    expect(data.etmOutputs.map((o) => o.output), [
      '#1',
      '#2',
      '#3',
      '#4',
      '#5',
      '#6',
      '#7',
    ]);

    for (final item in data.common) {
      expect(item.checks, isNotEmpty, reason: item.error);
    }
    for (final item in data.detailed) {
      expect(item.causes, isNotEmpty, reason: item.error);
      for (final c in item.causes) {
        expect(c.cause.trim(), isNotEmpty, reason: item.error);
        expect(c.fix.trim(), isNotEmpty, reason: item.error);
      }
    }
    final guns = data.detailed.firstWhere((e) => e.error == 'Súng không bắn');
    expect(guns.causes, hasLength(7));
  });

  testWidgets('màn tra cứu lỗi: hiện dòng máy, tìm không dấu lọc kết quả', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: ColorSorterErrorsScreen(machineLine: 'Máy tách màu Gạo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Máy tách màu Gạo'), findsOneWidget);
    expect(find.text('Lỗi thường gặp (17)'), findsOneWidget);
    expect(find.text('Màn hình LCD không lên'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('color_sorter_errors_search')),
      'sung khong ban',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lỗi thường gặp (2)'), findsOneWidget);
    expect(find.text('Một vài súng không bắn'), findsOneWidget);
    expect(find.text('Toàn bộ súng không bắn'), findsOneWidget);
    expect(find.text('Màn hình LCD không lên'), findsNothing);
    // Khi đang tìm, thẻ tự mở để thấy ngay cách kiểm tra.
    expect(find.text('Nguồn 48VDC cấp cho mạch súng động lực.'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Nguồn & kết nối'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nguồn & kết nối'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('color_sorter_errors_search')),
      'lau kinh',
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngõ ra ETM'), findsOneWidget);
    expect(find.text('Lau kính'), findsOneWidget);
  });
}
