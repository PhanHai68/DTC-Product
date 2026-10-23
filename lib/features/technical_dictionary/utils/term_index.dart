import '../../fault_bank/utils/vietnamese_fold.dart';
import '../models/technical_term.dart';

/// Tra cứu thuật ngữ theo tên (dùng cho "Từ liên quan") và tìm kiếm.
///
/// Một thuật ngữ có nhiều tên: thuật ngữ chính, viết tắt, tên gọi khác. Ô
/// gộp kiểu "load / unload" (dấu "/" có khoảng trắng hai bên) được tách thành
/// từng tên; viết tắt liền như "L/C", "m³/min" giữ nguyên.
class TermIndex {
  TermIndex(List<TechnicalTerm> terms) {
    final byId = [...terms]..sort((a, b) => a.id.compareTo(b.id));
    // Tên chính đăng ký trước để không bị tên gọi khác của mục khác chiếm.
    for (final term in byId) {
      for (final name in [
        ..._splitCombined(term.term),
        ..._splitCombined(term.abbreviation),
      ]) {
        _register(name, term);
      }
    }
    for (final term in byId) {
      for (final name in term.aliases) {
        _register(name, term);
      }
    }
    for (final term in byId) {
      _entries[term.id] = _SearchEntry(term);
    }
  }

  final _exact = <String, TechnicalTerm>{};
  final _folded = <String, TechnicalTerm>{};
  final _entries = <int, _SearchEntry>{};

  static final _parenthesis = RegExp(r'\([^)]*\)');
  static final _spacedSlash = RegExp(r'\s+/\s+');
  static final _slash = RegExp(r'\s*/\s*');
  static final _spaces = RegExp(r'\s+');

  /// Bỏ phần ghi chú trong ngoặc, chuẩn hóa dấu "/" và khoảng trắng.
  /// "cold dryer (cách gọi TQ)" → "cold dryer", "load / unload" → "load/unload".
  static String normalizeName(String name) => name
      .replaceAll(_parenthesis, ' ')
      .replaceAll(_slash, '/')
      .replaceAll(_spaces, ' ')
      .trim();

  static List<String> _splitCombined(String value) {
    if (value.trim().isEmpty) return const [];
    return [
      value,
      if (_spacedSlash.hasMatch(value)) ...value.split(_spacedSlash),
    ];
  }

  void _register(String name, TechnicalTerm term) {
    final normalized = normalizeName(name);
    if (normalized.isEmpty) return;
    _exact.putIfAbsent(normalized, () => term);
    _folded.putIfAbsent(VietnameseFold.fold(normalized), () => term);
  }

  /// Thuật ngữ mang tên [name]. Ưu tiên khớp đúng chữ hoa/thường (để "PSI"
  /// ra kiểm hàng, "psi" ra đơn vị áp suất), rồi tới khớp không phân biệt.
  /// Tên gộp "a / b" không khớp nguyên cụm thì thử từng phần.
  TechnicalTerm? lookup(String name) {
    final normalized = normalizeName(name);
    if (normalized.isEmpty) return null;
    final direct =
        _exact[normalized] ?? _folded[VietnameseFold.fold(normalized)];
    if (direct != null) return direct;
    if (!normalized.contains('/')) return null;
    for (final part in normalized.split('/')) {
      final found = _folded[VietnameseFold.fold(part)];
      if (found != null) return found;
    }
    return null;
  }

  /// Lọc và xếp hạng [pool] theo [query]. Gõ không dấu thì so khớp bỏ dấu
  /// ("tam" ra cả "tấm" lẫn "tâm"); gõ có dấu thì so khớp đúng dấu.
  /// Không có từ khóa thì xếp theo thứ tự chữ cái của thuật ngữ.
  List<TechnicalTerm> search(String query, Iterable<TechnicalTerm> pool) {
    final folded = VietnameseFold.fold(query);
    if (folded.isEmpty) {
      return [...pool]..sort(compareByTerm);
    }
    final lower = _lower(query);
    final accentSensitive = lower != folded;
    final q = accentSensitive ? lower : folded;
    final tokens = q.split(' ');
    final scored = <(int, TechnicalTerm)>[];
    for (final term in pool) {
      final entry = _entries[term.id];
      final score = (accentSensitive ? entry?.exact : entry?.folded)?.score(
        q,
        tokens,
      );
      if (score != null) scored.add((score, term));
    }
    scored.sort((a, b) {
      final byScore = a.$1.compareTo(b.$1);
      return byScore != 0 ? byScore : compareByTerm(a.$2, b.$2);
    });
    return [for (final item in scored) item.$2];
  }

  static int compareByTerm(TechnicalTerm a, TechnicalTerm b) {
    final byName = a.term.toLowerCase().compareTo(b.term.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }
}

/// Chữ thường, gộp khoảng trắng, giữ dấu.
String _lower(String input) =>
    input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

class _SearchEntry {
  _SearchEntry(TechnicalTerm term)
    : folded = _SearchText(term, VietnameseFold.fold),
      exact = _SearchText(term, _lower);

  /// Đã bỏ dấu — dùng khi người dùng gõ không dấu.
  final _SearchText folded;

  /// Giữ dấu — dùng khi người dùng gõ có dấu.
  final _SearchText exact;
}

class _SearchText {
  _SearchText(TechnicalTerm term, String Function(String) normalize)
    : names = [
        for (final name in [term.term, term.abbreviation, ...term.aliases])
          if (name.trim().isNotEmpty) normalize(name),
      ],
      meaning = normalize(term.meaning) {
    final body = normalize(
      [
        term.explanation,
        term.example,
        term.exampleMeaning,
        ...term.related,
      ].join(' '),
    );
    _headWords = _words('${names.join(' ')} $meaning');
    _bodyWords = _words(body);
  }

  static final _separator = RegExp(r'[\s,;:.()/\[\]"“”–-]+');
  static Set<String> _words(String text) =>
      text.split(_separator).where((w) => w.isNotEmpty).toSet();

  final List<String> names;
  final String meaning;
  late final Set<String> _headWords;
  late final Set<String> _bodyWords;

  /// Mỗi từ khóa phải là đầu của một từ ("tam" khớp "tấm", không khớp "tamarind"
  /// lẫn giữa chữ).
  static bool _hasWordStartingWith(Set<String> words, String token) =>
      words.any((w) => w.startsWith(token));

  /// Điểm càng nhỏ càng khớp; `null` là không khớp.
  int? score(String q, List<String> tokens) {
    if (names.any((n) => n == q)) return 0;
    if (names.any((n) => n.startsWith(q))) return 1;
    if (meaning == q || meaning.startsWith(q)) return 2;
    if (names.any((n) => n.contains(q))) return 3;
    if (meaning.contains(q)) return 4;
    if (tokens.every((t) => _hasWordStartingWith(_headWords, t))) return 5;
    if (tokens.every(
      (t) =>
          _hasWordStartingWith(_headWords, t) ||
          _hasWordStartingWith(_bodyWords, t),
    )) {
      return 6;
    }
    return null;
  }
}
