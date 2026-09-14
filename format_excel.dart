import 'dart:io';
import 'package:excel/excel.dart';

String formatText(String text) {
  if (text.isEmpty) return '';
  var parts = text.split(RegExp(r'[/_\n]'));
  List<String> formatted = [];
  
  for (var p in parts) {
    p = p.trim();
    if (p.isEmpty) continue;
    
    if (p.startsWith('-')) p = p.substring(1).trim();
    if (p.startsWith('+')) p = p.substring(1).trim();
    if (p.startsWith('_')) p = p.substring(1).trim();
    
    p = p.replaceAll(RegExp(r'[;:,.\s]+$'), '');
    
    if (p.isNotEmpty) {
      p = p[0].toUpperCase() + p.substring(1);
      formatted.add('- $p.');
    }
  }
  return formatted.join('\n');
}

String formatTitle(String text) {
  if (text.isEmpty) return '';
  text = text.trim();
  text = text.replaceAll(RegExp(r'[;:,.\s]+$'), '');
  if (text.isNotEmpty) {
    text = text[0].toUpperCase() + text.substring(1);
  }
  return text;
}

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\CAC_LOI_THUONG_GAP_CUA_MNK.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  var sheet1 = excel.tables['Lỗi_MNK_Thường_gặp'];
  if (sheet1 != null) {
    for (int r = 3; r < sheet1.maxRows; r++) {
      var row = sheet1.row(r);
      if (row.length > 1 && row[1]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r);
        sheet1.updateCell(cellIndex, TextCellValue(formatTitle(row[1]!.value.toString())));
      }
      if (row.length > 2 && row[2]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r);
        sheet1.updateCell(cellIndex, TextCellValue(formatText(row[2]!.value.toString())));
      }
    }
  }

  var sheet2 = excel.tables['Lỗi_MNK_HDSD_BĐK'];
  if (sheet2 != null) {
    for (int r = 3; r < sheet2.maxRows; r++) {
      var row = sheet2.row(r);
      if (row.length > 1 && row[1]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r);
        sheet2.updateCell(cellIndex, TextCellValue(formatTitle(row[1]!.value.toString())));
      }
      if (row.length > 2 && row[2]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r);
        sheet2.updateCell(cellIndex, TextCellValue(formatText(row[2]!.value.toString())));
      }
      if (row.length > 3 && row[3]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r);
        sheet2.updateCell(cellIndex, TextCellValue(formatText(row[3]!.value.toString())));
      }
    }
  }

  var sheet3 = excel.tables['Lỗi_MNK_Hao_Dầu'];
  if (sheet3 != null) {
    for (int r = 1; r < sheet3.maxRows; r++) {
      var row = sheet3.row(r);
      if (row.length > 1 && row[1]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r);
        sheet3.updateCell(cellIndex, TextCellValue(formatTitle(row[1]!.value.toString())));
      }
      if (row.length > 2 && row[2]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r);
        sheet3.updateCell(cellIndex, TextCellValue(formatText(row[2]!.value.toString())));
      }
      if (row.length > 3 && row[3]?.value != null) {
        var cellIndex = CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r);
        sheet3.updateCell(cellIndex, TextCellValue(formatText(row[3]!.value.toString())));
      }
    }
  }

  var newBytes = excel.encode();
  if (newBytes != null) {
    File(file).writeAsBytesSync(newBytes);
    print("Excel updated successfully");
  } else {
    print("Failed to encode excel");
  }
}
