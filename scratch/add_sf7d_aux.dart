import 'dart:io';

void main() {
  final file = File('lib/data/aux_equip_data.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('SF7D Pro')) {
    // Find SC10 data
    final sc10Regex = RegExp(r"'SC10':\s*\[(.*?)\]", dotAll: true);
    final match = sc10Regex.firstMatch(content);
    if (match != null) {
      final sc10Data = match.group(1);
      final insertIndex = content.lastIndexOf('};');
      content = content.substring(0, insertIndex) + ",\n  'SF7D Pro': [" + sc10Data! + "]\n};" + content.substring(insertIndex + 2);
      file.writeAsStringSync(content);
      print('Added SF7D Pro to aux_equip_data.dart');
    }
  } else {
    print('SF7D Pro already in aux_equip_data.dart');
  }
}
