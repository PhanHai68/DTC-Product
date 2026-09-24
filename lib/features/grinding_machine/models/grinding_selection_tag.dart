/// 1 tag ứng dụng/kỹ thuật gắn theo DÒNG MÁY (không phải theo model) — VD
/// "food", "chemical", "fibrous", "hard_material" — lấy từ sheet
/// `Selection_Tags`, dùng cho filter theo Application và Selection Engine.
class GrindingSelectionTag {
  final int? id;
  final String seriesCode;
  final String tag;
  final String? note;

  const GrindingSelectionTag({
    this.id,
    required this.seriesCode,
    required this.tag,
    this.note,
  });

  factory GrindingSelectionTag.fromJson(Map<String, dynamic> json) =>
      GrindingSelectionTag(
        id: json['id'] as int?,
        seriesCode: json['seriesCode'] as String,
        tag: json['tag'] as String,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'seriesCode': seriesCode,
    'tag': tag,
    'note': note,
  };
}
