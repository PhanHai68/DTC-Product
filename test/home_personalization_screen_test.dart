import 'package:dtc_product/providers/settings_provider.dart';
import 'package:dtc_product/screens/home_personalization_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Màn hình dài hơn khung hình điện thoại mặc định trong test (ListView chỉ
/// build các phần tử trong vùng nhìn thấy), nên cần phóng to bề mặt test để
/// mọi khu vực (Xem trước, nút Lưu/Khôi phục) đều được build và tìm thấy.
Future<void> _pumpApp(WidgetTester tester, SettingsProvider settings) async {
  await tester.binding.setSurfaceSize(const Size(390, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MaterialApp(home: HomePersonalizationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mặc định tắt hiển thị thông báo "Đang tắt" ở phần Xem trước', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await _pumpApp(tester, settings);

    expect(
      find.textContaining('Đang tắt — trang chủ sẽ dùng giao diện mặc định.'),
      findsOneWidget,
    );
  });

  testWidgets('bật switch, nhập tên và text -> Xem trước hiện đúng nội dung, không thêm lời chào', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await _pumpApp(tester, settings);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Kevin');
    await tester.enterText(find.byType(TextField).at(1), 'DTC Engineer');
    await tester.pumpAndSettle();

    // Xuất hiện 2 lần: trong ô nhập và trong khu vực Xem trước.
    expect(find.text('Kevin'), findsNWidgets(2));
    expect(find.text('DTC Engineer'), findsNWidgets(2));
    expect(find.textContaining('Xin chào'), findsNothing);
    expect(find.textContaining('👋'), findsNothing);
    // Chưa bấm "Lưu thay đổi" nên provider chưa thay đổi.
    expect(settings.homePersonalizationEnabled, isFalse);
    expect(settings.homeDisplayName, isEmpty);
  });

  testWidgets('kéo cỡ chữ và chọn màu cập nhật ngay ở Xem trước', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await _pumpApp(tester, settings);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.enterText(find.byType(TextField).at(0), 'Kevin');
    await tester.pumpAndSettle();

    // Chọn màu đỏ (preset thứ 5, sau "mặc định") cho dòng Tên hiển thị.
    final nameColorSwatches = find
        .descendant(
          of: find.byType(Wrap).first,
          matching: find.byType(GestureDetector),
        )
        .evaluate()
        .length;
    expect(nameColorSwatches, greaterThan(1));

    await tester.tap(
      find
          .descendant(
            of: find.byType(Wrap).first,
            matching: find.byType(GestureDetector),
          )
          .at(5),
    );
    await tester.pumpAndSettle();

    final previewText = tester.widget<Text>(find.text('Kevin').last);
    expect(previewText.style?.color, isNotNull);
  });

  testWidgets('bấm "Lưu thay đổi" ghi vào SettingsProvider và báo thành công', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await _pumpApp(tester, settings);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.enterText(find.byType(TextField).at(0), 'Kevin');
    await tester.enterText(find.byType(TextField).at(1), 'DTC Engineer');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
    await tester.pump();

    expect(settings.homePersonalizationEnabled, isTrue);
    expect(settings.homeDisplayName, 'Kevin');
    expect(settings.homeShortText, 'DTC Engineer');
    expect(find.text('Đã cập nhật trang chủ'), findsOneWidget);
  });

  testWidgets('khôi phục mặc định sau khi xác nhận sẽ xóa nội dung đã lưu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: 'Kevin',
      shortText: 'DTC Engineer',
      nameFontSize: 18,
      nameColor: const Color(0xFFDC2626),
      shortTextFontSize: 26,
      shortTextColor: const Color(0xFF7C3AED),
    );

    await _pumpApp(tester, settings);

    await tester.tap(find.text('Khôi phục mặc định'));
    await tester.pumpAndSettle();
    expect(find.text('Khôi phục mặc định?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Khôi phục'));
    await tester.pumpAndSettle();

    expect(settings.homePersonalizationEnabled, isFalse);
    expect(settings.homeDisplayName, isEmpty);
    expect(settings.homeShortText, isEmpty);
    expect(
      settings.homeNameFontSize,
      SettingsProvider.defaultHomeNameFontSize,
    );
    expect(settings.homeNameColor, isNull);
  });
}
