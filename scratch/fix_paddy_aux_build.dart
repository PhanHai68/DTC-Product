import 'dart:io';

void main() {
  final file = File('lib/screens/paddy_color_sorter/paddy_aux_equip_screen.dart');
  var content = file.readAsStringSync();
  
  // Fix provider method
  content = content.replaceFirst('provider.fetchAuxEquipData(_modelName);', 'provider.selectModel(_modelName);');
  
  // Fix Text numeric error
  content = content.replaceAll("Text(\n                        'SL',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                        numeric: true,\n                      )", "Text(\n                        'SL',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      )");
  
  content = content.replaceAll("Text(\n                        'Điện năng (HP)',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                        numeric: true,\n                      )", "Text(\n                        'Điện năng (HP)',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      )");

  // We need to move `numeric: true` to the `DataColumn` instead!
  content = content.replaceAll(
    "DataColumn(\n                      label: Text(\n                        'SL',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      ),\n                    ),",
    "DataColumn(\n                      label: Text(\n                        'SL',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      ),\n                      numeric: true,\n                    ),"
  );
  content = content.replaceAll(
    "DataColumn(\n                      label: Text(\n                        'Điện năng (HP)',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      ),\n                    ),",
    "DataColumn(\n                      label: Text(\n                        'Điện năng (HP)',\n                        style: TextStyle(fontWeight: FontWeight.bold),\n                      ),\n                      numeric: true,\n                    ),"
  );
  
  file.writeAsStringSync(content);
}
