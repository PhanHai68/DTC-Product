import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class MineralColorSorterMenuScreen extends StatelessWidget {
  const MineralColorSorterMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy tách màu Khoáng sản',
      entries: [
        TechnologyMenuEntry(
          id: 'mineral_color_sorter_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/mineral_color_sorter'),
        ),
        const TechnologyMenuEntry(
          id: 'mineral_color_sorter_aux_btn',
          title: 'Thiết bị phụ trợ',
          icon: Icons.settings_outlined,
          statusLabel: 'Sắp có',
        ),
        const TechnologyMenuEntry(
          id: 'mineral_color_sorter_payback_btn',
          title: 'Phân tích hoàn vốn',
          icon: Icons.query_stats_rounded,
          statusLabel: 'Sắp có',
        ),
        const TechnologyMenuEntry(
          id: 'mineral_color_sorter_errors_btn',
          title: 'Tra cứu lỗi',
          icon: Icons.troubleshoot_rounded,
          statusLabel: 'Sắp có',
        ),
        const TechnologyMenuEntry(
          id: 'mineral_color_sorter_manual_btn',
          title: 'Tài liệu vận hành',
          icon: Icons.menu_book_rounded,
          statusLabel: 'Sắp có',
        ),
      ],
    );
  }
}
