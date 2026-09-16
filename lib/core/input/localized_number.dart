import 'package:flutter/services.dart';

/// Parses numbers entered with either Vietnamese or international separators.
///
/// Examples: `1,5`, `1.5`, `1.234,56`, `1,234.56`.
double? parseLocalizedDouble(String? raw) {
  if (raw == null) return null;
  var value = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (value.isEmpty) return null;

  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    final decimalSeparator = comma > dot ? ',' : '.';
    final groupingSeparator = decimalSeparator == ',' ? '.' : ',';
    value = value.replaceAll(groupingSeparator, '');
    value = value.replaceAll(decimalSeparator, '.');
  } else if (comma >= 0) {
    value = value.replaceAll(',', '.');
  }

  return double.tryParse(value);
}

int? parseLocalizedInt(String? raw) {
  final value = parseLocalizedDouble(raw);
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}

/// Allows a signed decimal value and accepts both `,` and `.` while typing.
class LocalizedDecimalTextInputFormatter extends TextInputFormatter {
  const LocalizedDecimalTextInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pattern = allowNegative
        ? RegExp(r'^-?\d*([.,]\d*)?$')
        : RegExp(r'^\d*([.,]\d*)?$');
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
