import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/fault_record.dart';
import '../utils/fault_duration.dart';

/// Xuất danh sách sự cố ra file Excel (.xlsx) để chia sẻ. Mỗi bản ghi 1
/// dòng; các bước xử lý gộp vào 1 ô, mỗi bước 1 dòng có đánh số.
class FaultExcelExportService {
  const FaultExcelExportService._();

  static const sheetName = 'Ngân hàng lỗi';

  static const mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Tiêu đề cột và độ rộng tương ứng.
  static const columns = <(String, double)>[
    ('STT', 6),
    ('Model máy', 18),
    ('Tagname', 14),
    ('Nhóm lỗi', 16),
    ('Mô tả lỗi', 40),
    ('Nguyên nhân', 36),
    ('Cách xử lý', 50),
    ('Vật tư cần thay thế', 28),
    ('Dụng cụ', 22),
    ('Thời gian xử lý (giờ)', 12),
    ('Người ghi', 20),
    ('Ngày tạo', 17),
    ('Cập nhật', 17),
    ('Mã bản ghi', 30),
  ];

  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String fileName(DateTime now) =>
      'NganHangLoi_${DateFormat('yyyyMMdd_HHmm').format(now)}.xlsx';

  static Uint8List buildWorkbook(List<FaultRecord> records) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    excel.rename(defaultSheet, sheetName);
    excel.setDefaultSheet(sheetName);
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0B2A4A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );

    sheet.appendRow([for (final (title, _) in columns) TextCellValue(title)]);
    for (var i = 0; i < records.length; i++) {
      sheet.appendRow(_row(i + 1, records[i]));
    }

    for (var c = 0; c < columns.length; c++) {
      sheet.setColumnWidth(c, columns[c].$2);
      for (var r = 0; r <= records.length; r++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = r == 0
            ? headerStyle
            : bodyStyle;
      }
    }
    sheet.setRowHeight(0, 30);

    return Uint8List.fromList(excel.encode()!);
  }

  static List<CellValue?> _row(int index, FaultRecord r) {
    final steps = [for (final s in r.steps) '${s.order}. ${s.content}']
        .join('\n');
    return [
      IntCellValue(index),
      TextCellValue(r.machineModelName),
      _text(r.serialNumber),
      _text(r.faultGroup),
      TextCellValue(r.symptom),
      TextCellValue(r.cause),
      TextCellValue(steps),
      _text(r.parts),
      _text(r.tools),
      r.durationMinutes == null
          ? null
          : DoubleCellValue(FaultDuration.hours(r.durationMinutes!)),
      TextCellValue(r.authorName),
      TextCellValue(_dateTime.format(r.createdAt)),
      TextCellValue(_dateTime.format(r.updatedAt)),
      TextCellValue(r.id),
    ];
  }

  static CellValue? _text(String? value) =>
      value == null || value.trim().isEmpty ? null : TextCellValue(value);
}
