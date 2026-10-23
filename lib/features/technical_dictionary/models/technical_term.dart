/// Một thuật ngữ trong Từ điển chuyên ngành (nạp từ
/// `assets/database/dictionary/technical_terms.json`, sinh từ Excel bằng
/// `tool/data/build_technical_dictionary.dart`).
class TechnicalTerm {
  const TechnicalTerm({
    required this.id,
    required this.term,
    required this.meaning,
    required this.group,
    required this.type,
    this.abbreviation = '',
    this.ipa = '',
    this.explanation = '',
    this.example = '',
    this.exampleMeaning = '',
    this.related = const [],
    this.aliases = const [],
  });

  factory TechnicalTerm.fromJson(Map<String, dynamic> json) => TechnicalTerm(
    id: json['id'] as int,
    term: json['term'] as String,
    meaning: json['meaning'] as String,
    group: json['group'] as String,
    type: json['type'] as String,
    abbreviation: json['abbreviation'] as String? ?? '',
    ipa: json['ipa'] as String? ?? '',
    explanation: json['explanation'] as String? ?? '',
    example: json['example'] as String? ?? '',
    exampleMeaning: json['exampleMeaning'] as String? ?? '',
    related: [...?(json['related'] as List?)?.cast<String>()],
    aliases: [...?(json['aliases'] as List?)?.cast<String>()],
  );

  /// STT trong Excel.
  final int id;
  final String term;
  final String meaning;
  final String group;
  final String type;
  final String abbreviation;
  final String ipa;
  final String explanation;
  final String example;
  final String exampleMeaning;
  final List<String> related;

  /// Cách gọi khác của cùng thuật ngữ (cột "Tên gọi khác").
  final List<String> aliases;

  /// Khóa lưu trạng thái học / ghi chú. Dùng thuật ngữ thay cho STT để chèn
  /// hoặc sắp lại dòng trong Excel không làm lệch dữ liệu đã lưu.
  String get key => term.trim().toLowerCase();
}

/// Mức độ học của người dùng với một thuật ngữ.
enum TermStatus {
  learning('Đang học'),
  learned('Đã thuộc');

  const TermStatus(this.label);
  final String label;

  static TermStatus? fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// Dữ liệu riêng của người dùng cho một thuật ngữ.
class TermProgress {
  const TermProgress({this.status, this.note = ''});

  final TermStatus? status;
  final String note;

  bool get isEmpty => status == null && note.trim().isEmpty;
}

/// Toàn bộ dữ liệu từ điển: danh sách nhóm, loại theo đúng thứ tự trong
/// Excel và các thuật ngữ.
class TechnicalDictionaryData {
  const TechnicalDictionaryData({
    required this.groups,
    required this.types,
    required this.terms,
  });

  factory TechnicalDictionaryData.fromJson(Map<String, dynamic> json) =>
      TechnicalDictionaryData(
        groups: (json['groups'] as List).cast<String>(),
        types: (json['types'] as List).cast<String>(),
        terms: [
          for (final item in json['terms'] as List)
            TechnicalTerm.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<String> groups;
  final List<String> types;
  final List<TechnicalTerm> terms;
}
