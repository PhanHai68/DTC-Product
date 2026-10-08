import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../widgets/technology_menu.dart';
import '../../equipment_catalog/equipment_catalog_config.dart';
import '../../equipment_catalog/providers/equipment_catalog_provider.dart';
import '../providers/grinding_machine_provider.dart';

/// Menu trung gian khi bấm "Máy nghiền" ở Home: danh mục máy nghiền (các
/// model đã có) và các thiết bị trong dây chuyền bột — máy đóng gói, máy
/// trộn, máy sàng (catalog riêng). Cùng kiểu menu "Cân đóng gói".
class GrindingMenuScreen extends StatefulWidget {
  const GrindingMenuScreen({super.key});

  @override
  State<GrindingMenuScreen> createState() => _GrindingMenuScreenState();
}

class _GrindingMenuScreenState extends State<GrindingMenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrindingMachineProvider>().loadHome();
      final catalogs = context.read<EquipmentCatalogProvider>();
      for (final config in EquipmentCatalogs.powderLine) {
        catalogs.load(config);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grinding = context.watch<GrindingMachineProvider>();
    final catalogs = context.watch<EquipmentCatalogProvider>();
    String? counts(int series, int models) =>
        series == 0 ? null : '$series dòng · $models model';
    return TechnologyMenuScaffold(
      title: 'Máy nghiền & dây chuyền bột',
      entries: [
        TechnologyMenuEntry(
          id: 'grinding_menu_grinding_btn',
          title: 'Máy nghiền',
          icon: Icons.blender_outlined,
          imagePath: 'assets/images/home_grinding_machine_asp350.png',
          iconBackgroundColor: Colors.white,
          subtitle: counts(grinding.series.length, grinding.machines.length),
          featured: true,
          onTap: () => context.push('/grinding_machine'),
        ),
        for (final config in EquipmentCatalogs.powderLine)
          TechnologyMenuEntry(
            id: 'grinding_menu_${config.id}_btn',
            title: config.menuTitle,
            icon: config.icon,
            imagePath: config.menuImage,
            iconBackgroundColor: Colors.white,
            subtitle: switch (catalogs.catalog(config)) {
              final c? => counts(c.series.length, c.machines.length),
              null => null,
            },
            onTap: () => context.push(config.routeBase),
          ),
      ],
    );
  }
}
