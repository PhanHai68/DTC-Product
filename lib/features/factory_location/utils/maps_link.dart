typedef MapsCoordinates = ({double latitude, double longitude});

String buildMapsUrl(double latitude, double longitude) =>
    'https://www.google.com/maps/search/?api=1&query='
    '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';

bool isShortMapsLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && uri.path.startsWith('/maps'));
}

final _number = r'(-?\d{1,3}(?:\.\d+)?)';
final _pinPattern = RegExp('!3d$_number!4d$_number');
final _viewportPattern = RegExp('@$_number,$_number');
final _pairPattern = RegExp('^\\s*$_number\\s*,\\s*$_number\\s*\$');
const _coordinateParams = [
  'query',
  'q',
  'll',
  'center',
  'destination',
  'daddr',
];

/// Ưu tiên ghim địa điểm (!3d!4d) > tham số query > tâm bản đồ (@lat,lng).
MapsCoordinates? parseMapsCoordinates(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final direct = _parsePair(text);
  if (direct != null) return direct;

  String decoded;
  try {
    decoded = Uri.decodeFull(text);
  } on ArgumentError {
    decoded = text;
  }

  final pin = _pinPattern.firstMatch(decoded);
  if (pin != null) {
    final value = _validated(pin.group(1)!, pin.group(2)!);
    if (value != null) return value;
  }

  final uri = Uri.tryParse(text);
  if (uri != null) {
    for (final key in _coordinateParams) {
      final value = uri.queryParameters[key];
      if (value == null) continue;
      final parsed = _parsePair(value);
      if (parsed != null) return parsed;
    }
  }

  final viewport = _viewportPattern.firstMatch(decoded);
  if (viewport != null) {
    return _validated(viewport.group(1)!, viewport.group(2)!);
  }
  return null;
}

MapsCoordinates? _parsePair(String value) {
  final match = _pairPattern.firstMatch(value.replaceAll('+', ''));
  if (match == null) return null;
  return _validated(match.group(1)!, match.group(2)!);
}

MapsCoordinates? _validated(String lat, String lng) {
  final latitude = double.tryParse(lat);
  final longitude = double.tryParse(lng);
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return (latitude: latitude, longitude: longitude);
}

String normalizeForSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().trim().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticMap[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

final Map<String, String> _diacriticMap = () {
  const groups = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  };
  final map = <String, String>{};
  groups.forEach((base, chars) {
    for (final rune in chars.runes) {
      map[String.fromCharCode(rune)] = base;
    }
  });
  return map;
}();
