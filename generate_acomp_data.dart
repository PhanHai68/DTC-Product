import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = "docs/2 Máy nén khí/2.1 Thong_So_Ky_Thuat_May_Nen_Khi.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  var sheet = excel.tables['Datasheet AC Series'];
  if (sheet == null) {
    print('Sheet not found');
    return;
  }

  StringBuffer buffer = StringBuffer();
  buffer.writeln("import '../models/acomp_spec_model.dart';");
  buffer.writeln("");
  buffer.writeln("final List<AcompSpecModel> acompSpecData = [");

  for (int i = 1; i < sheet.maxRows; i++) {
    var row = sheet.rows[i];
    if (row.isEmpty || row[0]?.value == null) continue;
    
    var modelCode = row[0]?.value?.toString() ?? '';
    var series = row[1]?.value?.toString() ?? '';
    var powerKW = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
    var powerHP = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
    var flow7Bar = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
    var flow8Bar = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
    var airOutlet = row[6]?.value?.toString() ?? '';
    var lubricant = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
    var weight = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0;
    var dimensions = row[9]?.value?.toString() ?? '';

    buffer.writeln("  AcompSpecModel(");
    buffer.writeln("    modelCode: '$modelCode',");
    buffer.writeln("    series: '$series',");
    buffer.writeln("    powerKW: $powerKW,");
    buffer.writeln("    powerHP: $powerHP,");
    buffer.writeln("    flow7Bar: $flow7Bar,");
    buffer.writeln("    flow8Bar: $flow8Bar,");
    buffer.writeln("    airOutlet: '$airOutlet',");
    buffer.writeln("    lubricant: $lubricant,");
    buffer.writeln("    weight: $weight,");
    buffer.writeln("    dimensions: '$dimensions',");
    buffer.writeln("  ),");
  }

  buffer.writeln("];");

  File('lib/data/acomp_spec_data.dart').writeAsStringSync(buffer.toString());
  print('Data generated at lib/data/acomp_spec_data.dart');
}
