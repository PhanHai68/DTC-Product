import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/technology_menu.dart';

class AcompTroubleshootingMenuScreen extends StatelessWidget {
  const AcompTroubleshootingMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Hướng dẫn xử lý sự cố',
      entries: [
        TechnologyMenuEntry(
          id: 'acomp_common_errors_btn',
          title: 'Các lỗi thường gặp',
          icon: Icons.warning_amber_rounded,
          featured: true,
          onTap: () => context.push('/acomp_common_errors'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_ds8011_settings_btn',
          title: 'Tham số cài đặt bộ điều khiển DS8011',
          icon: Icons.tune_rounded,
          onTap: () => context.push('/acomp_ds8011_settings'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_operation_manual_btn',
          title: 'Tài liệu vận hành',
          icon: Icons.menu_book_rounded,
          onTap: () => context.push('/acomp_operation_manual'),
        ),
      ],
    );
  }
}
