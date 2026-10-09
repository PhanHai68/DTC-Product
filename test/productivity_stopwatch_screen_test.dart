import 'dart:convert';

import 'package:dtc_product/screens/productivity/productivity_calc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'mở lại màn hình khi đồng hồ đang chạy → hiện đúng thời gian đã trôi',
    (tester) async {
      // Bấm giờ từ 95 giây trước rồi app bị đóng (tắt màn hình lâu).
      final startedAt = DateTime.now().subtract(const Duration(seconds: 95));
      SharedPreferences.setMockInitialValues({
        'productivity_stopwatch': jsonEncode({
          'accumulatedMs': 0,
          'runningSinceMs': startedAt.millisecondsSinceEpoch,
        }),
      });

      await tester.pumpWidget(
        const MaterialApp(home: ProductivityCalcScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('00:01:3'), findsOneWidget);
      expect(find.text('Tạm dừng'), findsOneWidget);

      // Rời màn hình để huỷ timer vẽ lại.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('đồng hồ đã tạm dừng được khôi phục đúng số giây', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'productivity_stopwatch': jsonEncode({
        'accumulatedMs': 125000,
        'runningSinceMs': null,
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: ProductivityCalcScreen()));
    await tester.pump();

    expect(find.text('00:02:05'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });
}
