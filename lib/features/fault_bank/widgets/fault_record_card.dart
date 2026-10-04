import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/dtc_palette.dart';
import '../models/fault_record.dart';

/// 1 dòng kết quả tra cứu: model máy, nhóm lỗi, mô tả lỗi rút gọn, ngày cập
/// nhật.
class FaultRecordCard extends StatelessWidget {
  const FaultRecordCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.dense = false,
  });

  final FaultRecordSummary summary;
  final VoidCallback onTap;

  /// Bản gọn dùng trong khung "bản ghi tương tự" ở form.
  final bool dense;

  static final _date = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('fault_record_${summary.id}'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            dense ? 10 : 12,
            10,
            dense ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          summary.machineModelName,
                          style: TextStyle(
                            color: palette.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: dense ? 14 : 15,
                          ),
                        ),
                        if (summary.faultGroup != null && !dense)
                          FaultTag(
                            text: summary.faultGroup!,
                            color: palette.muted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.symptom,
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.ink, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        'Cập nhật ${_date.format(summary.updatedAt)}',
                        if (summary.source == FaultRecordSource.imported)
                          'Nhập vào',
                      ].join(' · '),
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn nhỏ dạng viên thuốc (nhóm lỗi, tagname).
class FaultTag extends StatelessWidget {
  const FaultTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
