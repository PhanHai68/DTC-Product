import 'package:dtc_product/models/maintenance_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('addCalendarMonths', () {
    test('giữ nguyên ngày khi tháng đích có ngày tương ứng', () {
      expect(
        addCalendarMonths(DateTime(2026, 1, 15), 1),
        DateTime(2026, 2, 15),
      );
    });

    test('đưa ngày cuối tháng về ngày hợp lệ gần nhất', () {
      expect(
        addCalendarMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        addCalendarMonths(DateTime(2024, 1, 31), 1),
        DateTime(2024, 2, 29),
      );
    });

    test('xử lý đúng khi cộng tháng qua năm mới', () {
      expect(
        addCalendarMonths(DateTime(2026, 12, 31), 2),
        DateTime(2027, 2, 28),
      );
    });
  });
}
