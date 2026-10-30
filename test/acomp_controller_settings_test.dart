import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/screens/acomp/acomp_controller_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CT8893D: danh mục đầu mở sẵn (mã cảnh báo + ghi chú), mở danh '
      'mục khác xem tham số', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AcompControllerSettingsScreen(
          title: 'Tham số cài đặt CT8893D',
          categories: ct8893dParameters,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mã cảnh báo trên màn hình'), findsOneWidget);
    expect(find.textContaining('tắt rồi cấp điện lại'), findsOneWidget);
    expect(find.text('A21'), findsOneWidget);
    expect(find.text('Lỗi cảm biến nhiệt độ điểm sương'), findsOneWidget);
    // Danh mục khác đóng sẵn: mở ra mới thấy tham số.
    expect(find.text('F42'), findsNothing);
    await tester.tap(find.text('Cài đặt quạt và chống đóng băng'));
    await tester.pumpAndSettle();
    expect(find.text('F42'), findsOneWidget);
    expect(find.text('Nhiệt độ bật quạt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DS8011 dùng chung màn hình', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AcompControllerSettingsScreen(
          title: 'Tham số cài đặt DS8011',
          categories: ds8011Parameters,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tham số cài đặt DS8011'), findsOneWidget);
    expect(find.text('F11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
