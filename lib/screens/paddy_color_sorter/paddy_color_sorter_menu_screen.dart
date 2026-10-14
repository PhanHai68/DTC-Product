import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/technology_menu.dart';

// Bản vẽ lắp đặt và tài liệu vận hành nằm trong "Thư viện tài liệu" ở trang chủ.
class PaddyColorSorterMenuScreen extends StatelessWidget {
  const PaddyColorSorterMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy tách màu Thóc',
      entries: [
        TechnologyMenuEntry(
          id: 'paddy_color_sorter_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/paddy_color_sorter'),
        ),
        TechnologyMenuEntry(
          id: 'paddy_color_sorter_aux_btn',
          title: 'Thiết bị phụ trợ',
          icon: Icons.settings_outlined,
          onTap: () => context.push('/paddy_aux_equip'),
        ),
        TechnologyMenuEntry(
          id: 'paddy_color_sorter_payback_btn',
          title: 'Phân tích hoàn vốn',
          icon: Icons.query_stats_rounded,
          onTap: () => context.push('/payback_analysis?line=paddy'),
        ),
        TechnologyMenuEntry(
          id: 'paddy_color_sorter_errors_btn',
          title: 'Tra cứu lỗi',
          icon: Icons.troubleshoot_rounded,
          onTap: () => context.push(
            '/color_sorter_errors?line=${Uri.encodeQueryComponent('Máy tách màu Thóc')}',
          ),
        ),
      ],
    );
  }
}
