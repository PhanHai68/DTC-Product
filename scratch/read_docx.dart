import 'dart:io';

void main() async {
  final file = File(r'D:\Flutter_Project\DTCproduct\scratch\icons\word\document.xml');
  final content = await file.readAsString();
  
  final regex = RegExp(r'<w:t>([^<]+)</w:t>|<a:blip r:embed="([^"]+)"');
  final matches = regex.allMatches(content);
  
  for (final match in matches) {
    if (match.group(1) != null) {
      print('TEXT: ${match.group(1)}');
    } else if (match.group(2) != null) {
      print('IMAGE: ${match.group(2)}');
    }
  }
}
