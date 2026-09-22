import 'package:dtc_product/providers/settings_provider.dart';
import 'package:dtc_product/widgets/home_personalization_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: const MaterialApp(
      home: Scaffold(body: HomePersonalizationWidget()),
    ),
  );
}

void main() {
  testWidgets('không hiển thị gì khi cá nhân hóa đang tắt', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    await tester.pumpWidget(_wrap(settings));

    expect(find.byType(HomePersonalizationWidget), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('hiển thị đúng nội dung đã nhập, không tự thêm lời chào/icon', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: 'Kevin',
      shortText: 'DTC Engineer',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));

    expect(find.text('Kevin'), findsOneWidget);
    expect(find.text('DTC Engineer'), findsOneWidget);
    expect(find.textContaining('Xin chào'), findsNothing);
    expect(find.textContaining('Chào buổi'), findsNothing);
    expect(find.textContaining('👋'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tên trống chỉ hiện dòng giới thiệu, không có "null" hay dòng thừa', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: '',
      shortText: 'Have a productive day',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));

    expect(find.text('Have a productive day'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('bật nhưng chưa nhập gì thì không hiển thị dòng nào', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: '',
      shortText: '',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('tên và text rất dài không gây lỗi tràn layout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: 'A' * 30,
      shortText: 'B' * 60,
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('màu chữ tùy chỉnh được áp dụng cho từng dòng', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    const nameColor = Color(0xFFDC2626);
    const shortTextColor = Color(0xFF7C3AED);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: 'Kevin',
      shortText: 'DTC Engineer',
      nameFontSize: 16,
      nameColor: nameColor,
      nameItalic: false,
      shortTextFontSize: 24,
      shortTextColor: shortTextColor,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));

    final nameWidget = tester.widget<Text>(find.text('Kevin'));
    final shortTextWidget = tester.widget<Text>(find.text('DTC Engineer'));
    expect(nameWidget.style?.fontSize, 16);
    expect(nameWidget.style?.color, nameColor);
    expect(shortTextWidget.style?.fontSize, 24);
    expect(shortTextWidget.style?.color, shortTextColor);
  });

  testWidgets('bật in nghiêng áp dụng đúng cho từng dòng độc lập', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: true,
      displayName: 'Kevin',
      shortText: 'DTC Engineer',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: true,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
    );

    await tester.pumpWidget(_wrap(settings));

    final nameWidget = tester.widget<Text>(find.text('Kevin'));
    final shortTextWidget = tester.widget<Text>(find.text('DTC Engineer'));
    expect(nameWidget.style?.fontStyle, FontStyle.italic);
    expect(shortTextWidget.style?.fontStyle, FontStyle.normal);
  });
}
