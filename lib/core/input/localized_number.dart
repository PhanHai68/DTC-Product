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

/// Removes the `,` thousands separators added by
/// [ThousandsSeparatorInputFormatter], e.g. `1,000,000` → `1000000`.
String stripThousandsSeparators(String raw) => raw.replaceAll(',', '');

/// Formats [value] the way [ThousandsSeparatorInputFormatter] shows it, for
/// pre-filling a controller (programmatic text skips input formatters),
/// e.g. `1811` → `1,811`, `12500.5` → `12,500.5` with `decimalDigits: 2`.
String formatThousands(num value, {int decimalDigits = 0}) {
  final fixed = value.abs().toStringAsFixed(decimalDigits);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  var fraction = dot < 0 ? '' : fixed.substring(dot + 1);
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final sign = value < 0 ? '-' : '';
  final grouped = ThousandsSeparatorInputFormatter._group(intPart);
  return fraction.isEmpty ? '$sign$grouped' : '$sign$grouped.$fraction';
}

/// Accepts non-negative numbers and groups the integer part with `,` while
/// typing, e.g. `1000000` → `1,000,000`. Whole numbers only unless
/// [decimalDigits] > 0, in which case `.` starts the fraction (`12,500.50`).
/// Read the value back through [stripThousandsSeparators] before parsing.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter({
    this.decimalDigits = 0,
    this.maxIntegerDigits = 15,
  });

  /// Digits allowed after `.`; 0 rejects any fraction.
  final int decimalDigits;

  /// Caps the integer part so the value stays exact as a `double`.
  final int maxIntegerDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    final pattern = decimalDigits > 0
        ? RegExp('^\\d{0,$maxIntegerDigits}(\\.\\d{0,$decimalDigits})?\$')
        : RegExp('^\\d{0,$maxIntegerDigits}\$');
    if (!pattern.hasMatch(raw)) return oldValue;

    final dot = raw.indexOf('.');
    final formatted = dot < 0
        ? _group(raw)
        : '${_group(raw.substring(0, dot))}${raw.substring(dot)}';
    // Keep the cursor after the same number of characters it had before
    // grouping.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final charsBeforeCursor =
        newValue.text.substring(0, cursor).replaceAll(',', '').length;
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < charsBeforeCursor) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
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
