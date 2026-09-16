import 'dart:io';

void main() {
  final file = File('lib/routes/app_routes.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('/paddy_aux_equip')) {
    content = content.replaceFirst(
      "import '../screens/aux_equip/aux_equip_screen.dart';",
      "import '../screens/aux_equip/aux_equip_screen.dart';\nimport '../screens/paddy_color_sorter/paddy_aux_equip_screen.dart';"
    );
    
    final auxRoute = '''
    GoRoute(
      path: '/paddy_aux_equip',
      builder: (context, state) => const PaddyAuxEquipScreen(),
    ),
''';
    
    content = content.replaceFirst(
      "    GoRoute(",
      auxRoute + "    GoRoute("
    );
    file.writeAsStringSync(content);
    print('Added /paddy_aux_equip to app_routes.dart');
  }

  final menuFile = File('lib/screens/paddy_color_sorter/paddy_color_sorter_menu_screen.dart');
  var menuContent = menuFile.readAsStringSync();
  menuContent = menuContent.replaceFirst(
    "onTap: () => context.push('/aux_equip'), // temporarily use rice aux",
    "onTap: () => context.push('/paddy_aux_equip'),"
  );
  menuFile.writeAsStringSync(menuContent);
  print('Updated paddy_color_sorter_menu_screen.dart');
}
