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

/// Form field validator: requires a non-empty value strictly greater than 0.
/// Use for calculator inputs where a blank or zero value would silently
/// produce a misleading result (e.g. a price or rate).
String? validateRequiredPositiveNumber(String? value, {String label = 'giá trị'}) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập $label';
  }
  final parsed = parseLocalizedDouble(value);
  if (parsed == null) {
    return 'Giá trị không hợp lệ';
  }
  if (parsed <= 0) {
    return 'Giá trị phải lớn hơn 0';
  }
  return null;
}

/// Form field validator: requires a non-empty value that is zero or more.
/// Use where 0 is a legitimate input (e.g. salary, by-product price).
String? validateRequiredNonNegativeNumber(String? value, {String label = 'giá trị'}) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập $label';
  }
  final parsed = parseLocalizedDouble(value);
  if (parsed == null) {
    return 'Giá trị không hợp lệ';
  }
  if (parsed < 0) {
    return 'Giá trị không được âm';
  }
  return null;
}

/// Form field validator: requires a non-empty value within `[0, max]`.
/// Use for hour-of-day style inputs.
String? validateHoursInRange(String? value, {double max = 24}) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập số giờ';
  }
  final parsed = parseLocalizedDouble(value);
  if (parsed == null) {
    return 'Giá trị không hợp lệ';
  }
  if (parsed < 0 || parsed > max) {
    return 'Phải trong khoảng 0-${max.toInt()} giờ';
  }
  return null;
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
