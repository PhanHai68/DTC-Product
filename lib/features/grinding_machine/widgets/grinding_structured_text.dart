import 'package:flutter/material.dart';

/// Hiển thị văn bản nhiều dòng có cấu trúc, canh trái:
/// - dòng "- ..." -> gạch đầu dòng "•";
/// - dòng có "→" (sơ đồ quy trình) -> chữ màu nhấn;
/// - tiêu đề mục ("Bước N ...", hoặc dòng ngắn không có dấu câu cuối như
///   "Cấu tạo hệ thống") -> in đậm;
/// - còn lại -> đoạn văn thường.
class GrindingStructuredText extends StatelessWidget {
  const GrindingStructuredText({super.key, required this.text});

  final String text;

  static final _stepHeading = RegExp(r'^Bước\s+\d+');
  static final _endsWithPunctuation = RegExp(r'[.:,;!?)]$');

  /// "1. Vùng nghiền thô" -> số thứ tự + nội dung.
  static final _numbered = RegExp(r'^(\d+\.)\s+(.+)$');

  static bool _isHeading(String line) =>
      _stepHeading.hasMatch(line) ||
      (!line.contains('→') &&
          line.length <= 60 &&
          !_endsWithPunctuation.hasMatch(line));

  @override
  Widget build(BuildContext context) {
    final accent = Colors.blue.shade900;
    final body = TextStyle(
      color: Colors.grey.shade800,
      fontSize: 13,
      height: 1.45,
    );
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.startsWith('- '))
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: body.copyWith(color: accent)),
                  Expanded(child: Text(line.substring(2), style: body)),
                ],
              ),
            )
          else if (_numbered.firstMatch(line) case final m?)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.group(1)}  ',
                    style: body.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(child: Text(m.group(2)!, style: body)),
                ],
              ),
            )
          else if (_isHeading(line))
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                line,
                style: body.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (line.contains('→'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                style: body.copyWith(
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(line, style: body),
            ),
      ],
    );
  }
}

/// Mục văn bản nhiều dòng ("Ứng dụng", "Cấu tạo", "Nguyên lý hoạt động"):
/// khung nền nhạt có tiêu đề, nội dung dài thì thu gọn còn
/// [_collapsedLines] dòng đầu kèm nút "Xem thêm". Mặc định nền xám; truyền
/// [backgroundColor]/[borderColor]/[titleColor]/[emoji] để đổi kiểu (VD thẻ
/// "Ứng dụng" xanh giống thẻ trong "Chi Tiết Ứng Dụng Thực Tế").
class GrindingTextSection extends StatefulWidget {
  const GrindingTextSection({
    super.key,
    required this.title,
    required this.text,
    required this.toggleKey,
    this.emoji,
    this.backgroundColor,
    this.borderColor,
    this.titleColor,
  });

  final String title;
  final String text;
  final Key toggleKey;
  final String? emoji;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? titleColor;

  @override
  State<GrindingTextSection> createState() => _GrindingTextSectionState();
}

class _GrindingTextSectionState extends State<GrindingTextSection> {
  static const _collapsedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lines = widget.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final canCollapse = lines.length > _collapsedLines;
    final shown = canCollapse && !_expanded
        ? lines.take(_collapsedLines).join('\n')
        : lines.join('\n');
    final accent = widget.titleColor ?? Colors.blue.shade900;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.borderColor ?? Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.emoji != null) ...[
                Text(widget.emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GrindingStructuredText(text: shown),
          if (canCollapse)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: widget.toggleKey,
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(_expanded ? 'Thu gọn' : 'Xem thêm'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Khối "Đặc điểm chính" — mỗi dòng của [text] là 1 ý (VD "1. Nhiệt độ
/// nghiền thấp: ..."); phần trước dấu ":" in đậm để dễ đọc lướt.
class GrindingFeatureList extends StatelessWidget {
  const GrindingFeatureList({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final accent = Colors.blue.shade900;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đặc điểm chính',
            style: TextStyle(
              color: accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            if (line.startsWith('- '))
              // Gạch đầu dòng "- ..." -> "•" (VD ưu điểm của ASP).
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        _featureSpan(line.substring(2), accent),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  _featureSpan(line, accent),
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static TextSpan _featureSpan(String line, Color accent) {
    final colon = line.indexOf(':');
    if (colon <= 0) return TextSpan(text: line);
    return TextSpan(
      children: [
        TextSpan(
          text: line.substring(0, colon + 1),
          style: TextStyle(color: accent, fontWeight: FontWeight.w700),
        ),
        TextSpan(text: line.substring(colon + 1)),
      ],
    );
  }
}
