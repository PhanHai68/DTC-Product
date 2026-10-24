import 'package:dtc_product/core/input/localized_number.dart';
import 'package:flutter/services.dart';
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

  group('ThousandsSeparatorInputFormatter', () {
    const formatter = ThousandsSeparatorInputFormatter();

    TextEditingValue type(String text, [int? cursor]) =>
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor ?? text.length),
          ),
        );

    test('groups digits with commas and keeps the cursor at the end', () {
      final value = type('1000000');
      expect(value.text, '1,000,000');
      expect(value.selection.end, value.text.length);
      expect(type('100').text, '100');
      expect(type('').text, '');
    });

    test('regroups after an edit and keeps the cursor after the same digit', () {
      // "1,000" with "5" typed after the "1" → "15,000", cursor after "5".
      final value = type('15,000', 2);
      expect(value.text, '15,000');
      expect(value.selection.end, 2);
      final moved = type('1,0000', 3); // typed "0" → "10,000", cursor after 2nd digit
      expect(moved.text, '10,000');
      expect(moved.selection.end, 2);
    });

    test('rejects non-digit input', () {
      final old = const TextEditingValue(text: '1,000');
      expect(formatter.formatEditUpdate(old, const TextEditingValue(text: '1,000.5')), old);
    });

    test('stripped value parses back to the number', () {
      expect(parseLocalizedDouble(stripThousandsSeparators('16,000,000,000')),
          16000000000);
    });

    test('caps the integer part at 15 digits', () {
      final old = const TextEditingValue(text: '100,000,000,000,000');
      expect(
        formatter.formatEditUpdate(
          old,
          const TextEditingValue(text: '1,000,000,000,000,000'),
        ),
        old,
      );
    });

    test('decimalDigits allows a "." fraction and groups the integer part', () {
      const usd = ThousandsSeparatorInputFormatter(decimalDigits: 2);
      TextEditingValue typeUsd(String text) => usd.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      expect(typeUsd('12500.50').text, '12,500.50');
      expect(typeUsd('12500.').text, '12,500.');
      final old = const TextEditingValue(text: '12,500.50');
      expect(
        usd.formatEditUpdate(old, const TextEditingValue(text: '12,500.505')),
        old,
      );
    });
  });

  group('formatThousands', () {
    test('groups whole and fractional values for pre-filling', () {
      expect(formatThousands(1811), '1,811');
      expect(formatThousands(16000000000), '16,000,000,000');
      expect(formatThousands(0), '0');
      expect(formatThousands(12500.5, decimalDigits: 2), '12,500.5');
      expect(formatThousands(500000000, decimalDigits: 2), '500,000,000');
    });
  });
}
