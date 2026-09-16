import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/data/aux_equip_data.dart');
  final bytes = file.readAsBytesSync();
  String content = utf8.decode(bytes, allowMalformed: true);
  
  if (content.contains('SF7D Pro')) {
    print('Already contains SF7D Pro');
    return;
  }
  
  // Find SC10 start
  int sc10Start = content.indexOf('"SC10":[');
  if (sc10Start == -1) sc10Start = content.indexOf("'SC10':[");
  if (sc10Start == -1) sc10Start = content.indexOf('"SC10": [');
  if (sc10Start == -1) sc10Start = content.indexOf("'SC10': [");
  
  if (sc10Start != -1) {
    // find the end of SC10 array. SC10 is followed by 'SC8' or "SC8"
    int sc8Start = content.indexOf('"SC8":', sc10Start);
    if (sc8Start == -1) sc8Start = content.indexOf("'SC8':", sc10Start);
    
    if (sc8Start != -1) {
      // The SC10 array ends just before SC8Start (usually a comma)
      String sc10Data = content.substring(sc10Start, sc8Start);
      // sc10Data looks like: "SC10": [...], 
      
      // Let's create SF7D Pro data
      String sf7dData = sc10Data.replaceFirst('"SC10"', '"SF7D Pro"').replaceFirst("'SC10'", "'SF7D Pro'");
      
      // Insert it before SC10
      content = content.substring(0, sc10Start) + sf7dData + content.substring(sc10Start);
      
      file.writeAsBytesSync(utf8.encode(content));
      print('Added SF7D Pro aux equip data successfully!');
    } else {
      print('Could not find SC8');
    }
  } else {
    print('Could not find SC10');
  }
}
