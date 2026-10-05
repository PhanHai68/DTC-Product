import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../widgets/technology_menu.dart';
import '../../packing_machine/providers/packing_machine_provider.dart';
import '../providers/grinding_machine_provider.dart';

/// Menu trung gian khi bấm "Máy nghiền" ở Home: chọn giữa danh mục máy
/// nghiền (các model đã có) và máy đóng gói (catalog riêng). Cùng kiểu menu
/// "Cân đóng gói" / "Máy nén khí".
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
      context.read<PackingMachineProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final grinding = context.watch<GrindingMachineProvider>();
    final packing = context.watch<PackingMachineProvider>();
    String? counts(int series, int models) =>
        series == 0 ? null : '$series dòng · $models model';
    return TechnologyMenuScaffold(
      title: 'Máy nghiền & đóng gói',
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
        TechnologyMenuEntry(
          id: 'grinding_menu_packing_btn',
          title: 'Máy đóng gói',
          icon: Icons.inventory_2_outlined,
          imagePath: 'assets/images/catalog_packing_aspm_vertical.png',
          iconBackgroundColor: Colors.white,
          subtitle: counts(packing.series.length, packing.machines.length),
          onTap: () => context.push('/packing_machine'),
        ),
      ],
    );
  }
}
