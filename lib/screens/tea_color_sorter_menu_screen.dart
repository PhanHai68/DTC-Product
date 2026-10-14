import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class TeaColorSorterMenuScreen extends StatelessWidget {
  const TeaColorSorterMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy tách màu Trà',
      entries: [
        TechnologyMenuEntry(
          id: 'tea_color_sorter_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/tea_color_sorter'),
        ),
        TechnologyMenuEntry(
          id: 'tea_color_sorter_aux_btn',
          title: 'Thiết bị phụ trợ',
          icon: Icons.settings_outlined,
          onTap: () => context.push('/tea_aux_equip', extra: 'DF53 Pro'),
        ),
        TechnologyMenuEntry(
          id: 'tea_color_sorter_payback_btn',
          title: 'Phân tích hoàn vốn',
          icon: Icons.query_stats_rounded,
          subtitle: 'Hiện có cho DF53 Pro',
          onTap: () => context.push('/payback_analysis?line=tea'),
        ),
        TechnologyMenuEntry(
          id: 'tea_color_sorter_errors_btn',
          title: 'Tra cứu lỗi',
          icon: Icons.troubleshoot_rounded,
          onTap: () => context.push(
            '/color_sorter_errors?line=${Uri.encodeQueryComponent('Máy tách màu Trà')}',
          ),
        ),
      ],
    );
  }
}
