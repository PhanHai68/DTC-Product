import 'localized_number.dart';

const _digits = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];

/// Đọc số tiền VNĐ thành chữ, viết hoa chữ đầu, ví dụ
/// `16000000000` → `Mười sáu tỷ đồng`,
/// `1205000` → `Một triệu hai trăm linh năm nghìn đồng`.
String vndToWords(int amount) {
  if (amount == 0) return 'Không đồng';
  final words = amount < 0 ? 'âm ${_read(-amount)}' : _read(amount);
  return '${words[0].toUpperCase()}${words.substring(1)} đồng';
}

/// Chữ của số đang nhập trong ô tiền (có dấu `,`); `null` khi ô trống hoặc
/// không phải số nguyên.
String? vndTextToWords(String text) {
  final value = int.tryParse(stripThousandsSeparators(text.trim()));
  return value == null ? null : vndToWords(value);
}

/// [full]: đã có hàng lớn hơn đứng trước nên đọc đủ "không trăm", "linh".
String _read(int n, {bool full = false}) {
  const billion = 1000000000;
  if (n < billion) return _readBelowBillion(n, full: full);
  final rest = n % billion;
  return [
    _read(n ~/ billion, full: full),
    'tỷ',
    if (rest > 0) _readBelowBillion(rest, full: true),
  ].join(' ');
}

String _readBelowBillion(int n, {required bool full}) {
  final groups = [(n ~/ 1000000, 'triệu'), (n ~/ 1000 % 1000, 'nghìn'), (n % 1000, '')];
  final parts = <String>[];
  var started = full;
  for (final (value, unit) in groups) {
    if (value == 0) continue;
    parts.add(_readTriple(value, full: started));
    if (unit.isNotEmpty) parts.add(unit);
    started = true;
  }
  return parts.join(' ');
}

String _readTriple(int n, {required bool full}) {
  final hundreds = n ~/ 100;
  final tens = n ~/ 10 % 10;
  final units = n % 10;
  final parts = <String>[];
  if (full || hundreds > 0) parts.add('${_digits[hundreds]} trăm');
  if (tens == 0) {
    if (units > 0 && (full || hundreds > 0)) parts.add('linh');
  } else if (tens == 1) {
    parts.add('mười');
  } else {
    parts.add('${_digits[tens]} mươi');
  }
  if (units > 0) {
    parts.add(switch (units) {
      1 when tens >= 2 => 'mốt',
      4 when tens >= 2 => 'tư',
      5 when tens >= 1 => 'lăm',
      _ => _digits[units],
    });
  }
  return parts.join(' ');
}
