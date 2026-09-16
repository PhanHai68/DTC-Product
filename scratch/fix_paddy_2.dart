import 'dart:io';

void main() {
  final dest = File('lib/screens/paddy_color_sorter/paddy_color_sorter_screen.dart');
  var content = dest.readAsStringSync();

  // 1. Rename Provider & State
  content = content.replaceAll('ColorSorterProvider', 'PaddyColorSorterProvider');
  content = content.replaceAll('color_sorter_provider.dart', 'paddy_color_sorter_provider.dart');
  content = content.replaceAll('ColorSorterScreen', 'PaddyColorSorterScreen');
  
  // 2. Fix Vietnamese Texts
  content = content.replaceAll('Máy tách màu gạo', 'Máy tách màu thóc');
  content = content.replaceAll('Máy tách màu Gạo', 'Máy tách màu Thóc');

  // 3. Fix imports
  content = content.replaceAll("import 'spec_image_export_dialog.dart';", "import '../color_sorter/spec_image_export_dialog.dart';");
  content = content.replaceAll("import 'color_sorter_3d_screen.dart';", "import '../color_sorter/color_sorter_3d_screen.dart';");
  content = content.replaceAll("import '../../theme/colors.dart';", "");

  // 4. Update _getImageForModel
  content = content.replaceAll(
    "if (m.contains('sc4')) return 'assets/images/color_sorter/sc4.jpeg';",
    "if (m.contains('sc4')) return 'assets/images/color_sorter/sc4.jpeg';\n    if (m.contains('sf7d')) return 'assets/images/color_sorter/sc10.jpeg';"
  );

  dest.writeAsStringSync(content);
}
