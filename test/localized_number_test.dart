import 'package:dtc_product/core/input/localized_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLocalizedDouble', () {
    test('accepts Vietnamese and international decimal separators', () {
      expect(parseLocalizedDouble('1,5'), 1.5);
      expect(parseLocalizedDouble('1.5'), 1.5);
      expect(parseLocalizedDouble('1.234,56'), 1234.56);
      expect(parseLocalizedDouble('1,234.56'), 1234.56);
      expect(parseLocalizedDouble(' 12 345,75 '), 12345.75);
    });

    test('rejects empty and invalid values', () {
      expect(parseLocalizedDouble(''), isNull);
      expect(parseLocalizedDouble('abc'), isNull);
      expect(parseLocalizedInt('2,5'), isNull);
      expect(parseLocalizedInt('12'), 12);
    });
  });
}
