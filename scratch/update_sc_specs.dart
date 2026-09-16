import 'dart:io';

void main() {
  final file = File('lib/data/specs_data.dart');
  var content = file.readAsStringSync();
  
  // Update SC16 Pro (Optional, leave as is if not mentioned, or maybe we update what we know)
  // Wait, let's just do regex replacements for the specific models.
  
  String updateModel(String text, String model, String hp, String tank) {
    // Find the block for the model
    // This is a bit tricky with Regex, so let's do it by finding the model index
    int index = text.indexOf('"Model": "$model"');
    if (index == -1) index = text.indexOf('"Model": "$model Pro"'); // Just in case
    
    if (index != -1) {
      // Find the next end of map '}'
      int endIndex = text.indexOf('}', index);
      String block = text.substring(index, endIndex);
      
      // Replace Máy nén khí đồng bộ
      block = block.replaceAll(RegExp(r'"Máy nén khí đồng bộ": ".*?"'), '"Máy nén khí đồng bộ": "$hp"');
      
      // Replace Bình tích khí đồng bộ
      block = block.replaceAll(RegExp(r'"Bình tích khí đồng bộ": ".*?"'), '"Bình tích khí đồng bộ": "$tank"');
      
      return text.substring(0, index) + block + text.substring(endIndex);
    }
    return text;
  }
  
  content = updateModel(content, 'SC12', '75HP', '1500 lít');
  content = updateModel(content, 'SC10', '50HP', '1500 lít');
  content = updateModel(content, 'SC8', '50HP', '1500 lít');
  content = updateModel(content, 'SC4', '30HP', '1000 lít');
  
  // Wait, SC16 Pro is the first one, did the user want SC16 updated?
  // User only mentioned SC12, SC10, SC8, SC4. I'll leave SC16 as is unless they want it changed.

  file.writeAsStringSync(content);
  print('Updated specs_data.dart');
}
