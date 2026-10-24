import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/product_data.dart';
import '../../widgets/technology_menu.dart';

// Bản vẽ lắp đặt và tài liệu vận hành nằm trong "Thư viện tài liệu" ở trang chủ.
/// Menu dòng SF Pro: [line] là Lúa giống (mặc định) hoặc Lúa và Gạo lứt.
class PaddyColorSorterMenuScreen extends StatelessWidget {
  const PaddyColorSorterMenuScreen({
    super.key,
    this.line = ColorSorterLine.paddy,
  });

  final ColorSorterLine line;

  @override
  Widget build(BuildContext context) {
    final lineQuery = 'line=${line.name}';
    final idPrefix = line == ColorSorterLine.brownRice
        ? 'brown_rice_color_sorter'
        : 'paddy_color_sorter';
    return TechnologyMenuScaffold(
      title: line.title,
      entries: [
        TechnologyMenuEntry(
          id: '${idPrefix}_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/paddy_color_sorter?$lineQuery'),
        ),
        TechnologyMenuEntry(
          id: '${idPrefix}_aux_btn',
          title: 'Thiết bị phụ trợ',
          icon: Icons.settings_outlined,
          onTap: () => context.push('/paddy_aux_equip?$lineQuery'),
        ),
        TechnologyMenuEntry(
          id: '${idPrefix}_payback_btn',
          title: 'Phân tích hoàn vốn',
          icon: Icons.query_stats_rounded,
          onTap: () => context.push('/payback_analysis?$lineQuery'),
        ),
        TechnologyMenuEntry(
          id: '${idPrefix}_errors_btn',
          title: 'Tra cứu lỗi',
          icon: Icons.troubleshoot_rounded,
          onTap: () => context.push(
            '/color_sorter_errors?line=${Uri.encodeQueryComponent(line.title)}',
          ),
        ),
      ],
    );
  }
}
