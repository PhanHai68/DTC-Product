import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/packing_provider.dart';
import '../../widgets/technology_menu.dart';

class PackingMenuScreen extends StatefulWidget {
  const PackingMenuScreen({super.key});

  @override
  State<PackingMenuScreen> createState() => _PackingMenuScreenState();
}

class _PackingMenuScreenState extends State<PackingMenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PackingProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Cân đóng gói',
      backButtonKey: const Key('packing_home_button'),
      entries: [
        TechnologyMenuEntry(
          id: 'machine_catalog_btn',
          title: 'Danh mục sản phẩm',
          icon: Icons.grid_view_rounded,
          featured: true,
          onTap: () => context.push('/machine_catalog'),
        ),
        TechnologyMenuEntry(
          id: 'packing_search_btn',
          title: 'Tìm nhanh theo tên model',
          icon: Icons.search_rounded,
          onTap: () => context.push('/packing_search'),
        ),
        TechnologyMenuEntry(
          id: 'machine_selector_btn',
          title: 'Chọn máy theo yêu cầu',
          icon: Icons.manage_search_rounded,
          onTap: () => context.push('/machine_selector'),
        ),
        TechnologyMenuEntry(
          id: 'machine_compare_btn',
          title: 'So sánh model',
          icon: Icons.compare_arrows_rounded,
          onTap: () => context.push('/machine_compare'),
        ),
      ],
    );
  }
}
