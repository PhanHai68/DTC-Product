import 'dart:io';
import 'dart:convert';

import 'package:excel/excel.dart';

void main() {
  var file =
      "D:/Flutter_Project/DTCproduct/docs/1 Máy tách màu/1.3 Phan_Tich_Hoan_Von_MTM.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  var sheet = excel.tables[excel.tables.keys.first]!;

  Map<String, List<Map<String, String>>> powerSpecsByModel = {};

  // Headers in A2:J2
  List<String> headers = [];
  var headerRow = sheet.row(1);
  for (var cell in headerRow) {
    headers.add(cell?.value?.toString().trim() ?? "");
  }

  // Data in A3:J8
  for (int i = 2; i <= 7; i++) {
    var row = sheet.row(i);
    var modelName = row[0]?.value?.toString().trim() ?? "";
    if (modelName.isEmpty) continue;

    double mayTachMau = double.tryParse(row[2]?.value?.toString() ?? "0") ?? 0;
    double gauTai = double.tryParse(row[3]?.value?.toString() ?? "0") ?? 0;
    double quatHut = double.tryParse(row[4]?.value?.toString() ?? "0") ?? 0;
    double nenKhi = double.tryParse(row[5]?.value?.toString() ?? "0") ?? 0;
    double tongToiDa = mayTachMau + gauTai + quatHut + nenKhi;
    double tongTrungBinh = tongToiDa * 0.8;

    List<Map<String, String>> specs = [
      {
        "Tiêu chí": "Năng suất (Tấn/h)",
        "Thông số": row[1]?.value?.toString().trim() ?? "",
      },
      {"Tiêu chí": "Máy tách màu (kW)", "Thông số": mayTachMau.toString()},
      {"Tiêu chí": "Hệ thống gàu tải (kW)", "Thông số": gauTai.toString()},
      {"Tiêu chí": "Quạt hút bụi (kW)", "Thông số": quatHut.toString()},
      {"Tiêu chí": "Hệ thống nén khí (kW)", "Thông số": nenKhi.toString()},
      {
        "Tiêu chí": "Công suất tối đa (kW)",
        "Thông số": tongToiDa.toStringAsFixed(2),
      },
      {
        "Tiêu chí": "Công suất trung bình (kW)",
        "Thông số": tongTrungBinh.toStringAsFixed(2),
      },
    ];

    powerSpecsByModel[modelName] = specs;
  }

  String jsonStr = jsonEncode(powerSpecsByModel);
  String dartCode =
      '// GENERATED FILE - DO NOT EDIT MANUALLY\nimport \'dart:convert\';\n\nconst String _powerConsumptionJson = \'\'\'$jsonStr\'\'\';\n\nfinal Map<String, List<Map<String, String>>> powerConsumptionData =\n    (jsonDecode(_powerConsumptionJson) as Map<String, dynamic>).map(\n  (k, v) => MapEntry(\n    k,\n    (v as List).map((e) => Map<String, String>.from(e as Map)).toList(),\n  ),\n);\n';

  File("D:/Flutter_Project/DTCproduct/lib/data/power_consumption_data.dart")
      .writeAsStringSync(dartCode);
  print("Done! Generated lib/data/power_consumption_data.dart");
}
