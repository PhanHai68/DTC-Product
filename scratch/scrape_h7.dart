import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final url = Uri.parse('https://www.dtcgroup.vn/san-pham/may-tach-mau-hat-h-7/');
  final response = await http.get(url);
  final html = response.body;
  
  final regex = RegExp(r'<img[^>]+src="([^">]+)"');
  final matches = regex.allMatches(html);
  
  for (final match in matches) {
    final src = match.group(1);
    if (src != null) {
      if (src.contains('H-7') || src.contains('H-12') || src.contains('H-1')) {
        print('FOUND: \$src');
      } else if (src.contains('may-tach-mau') && (src.endsWith('.jpg') || src.endsWith('.png'))) {
        print('FOUND_MTM: \$src');
      }
    }
  }
}
