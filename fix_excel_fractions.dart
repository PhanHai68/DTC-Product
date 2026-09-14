import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\CAC_LOI_THUONG_GAP_CUA_MNK.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  void fixSheet(String sheetName, int startRow) {
    var sheet = excel.tables[sheetName];
    if (sheet == null) return;
    for (int r = startRow; r < sheet.maxRows; r++) {
      var row = sheet.row(r);
      for (int c = 1; c < row.length; c++) {
        var cellValue = row[c]?.value?.toString();
        if (cellValue != null && cellValue.contains('\n- ')) {
          // Replace "digit.\n- digit" with "digit/digit"
          var fixed = cellValue.replaceAllMapped(RegExp(r'(\d)\.\n- (\d)'), (match) => '${match.group(1)}/${match.group(2)}');
          if (fixed != cellValue) {
            sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r), TextCellValue(fixed));
          }
        }
      }
    }
  }

  fixSheet('Lỗi_MNK_Thường_gặp', 3);
  fixSheet('Lỗi_MNK_HDSD_BĐK', 3);
  fixSheet('Lỗi_MNK_Hao_Dầu', 1);

  var newBytes = excel.encode();
  if (newBytes != null) {
    File(file).writeAsBytesSync(newBytes);
    print("Fixed fractions in excel");
  }
}
