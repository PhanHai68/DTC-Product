import 'package:dtc_product/features/grinding_machine/utils/grinding_number_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDouble', () {
    test('"1000" -> 1000', () {
      expect(GrindingNumberParser.parseDouble('1000'), 1000);
    });
    test('"1000.5" -> 1000.5', () {
      expect(GrindingNumberParser.parseDouble('1000.5'), 1000.5);
    });
    test('"1000,5" (dấu phẩy = thập phân, quy ước hiện tại) -> 1000.5', () {
      expect(GrindingNumberParser.parseDouble('1000,5'), 1000.5);
    });
    test('rỗng -> null', () {
      expect(GrindingNumberParser.parseDouble(''), isNull);
      expect(GrindingNumberParser.parseDouble('   '), isNull);
    });
    test('null -> null', () {
      expect(GrindingNumberParser.parseDouble(null), isNull);
    });
    test('"-1" -> -1 (parser không tự chặn âm, validation làm việc đó)', () {
      expect(GrindingNumberParser.parseDouble('-1'), -1);
    });
    test('text không phải số -> null', () {
      expect(GrindingNumberParser.parseDouble('abc'), isNull);
      expect(GrindingNumberParser.parseDouble('12abc'), isNull);
    });
    test('"NaN"/"Infinity" -> null (loại trừ dù Dart tryParse chấp nhận)', () {
      expect(GrindingNumberParser.parseDouble('NaN'), isNull);
      expect(GrindingNumberParser.parseDouble('Infinity'), isNull);
      expect(GrindingNumberParser.parseDouble('-Infinity'), isNull);
    });
    test('có khoảng trắng 2 đầu -> vẫn parse đúng', () {
      expect(GrindingNumberParser.parseDouble('  1000  '), 1000);
    });
  });

  group('parseInt', () {
    test('"30" -> 30', () {
      expect(GrindingNumberParser.parseInt('30'), 30);
    });
    test('rỗng/null -> null', () {
      expect(GrindingNumberParser.parseInt(''), isNull);
      expect(GrindingNumberParser.parseInt(null), isNull);
    });
    test('số thập phân -> null (parseInt không nhận)', () {
      expect(GrindingNumberParser.parseInt('30.5'), isNull);
    });
    test('text không phải số -> null', () {
      expect(GrindingNumberParser.parseInt('abc'), isNull);
    });
    test('số âm -> parse được (validation chặn ở nơi khác)', () {
      expect(GrindingNumberParser.parseInt('-5'), -5);
    });
  });
}
