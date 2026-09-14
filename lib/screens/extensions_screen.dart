import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class ExtensionsScreen extends StatelessWidget {
  const ExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Tiện ích mở rộng',
      backButtonKey: const Key('extensions_back_button'),
      entries: [
        TechnologyMenuEntry(
          id: 'extension_sample_record',
          title: 'Lập Form Lưu Mẫu',
          icon: Icons.assignment_turned_in_outlined,
          featured: true,
          onTap: () => context.push('/sample_record'),
        ),
        TechnologyMenuEntry(
          id: 'extension_productivity_calc',
          title: 'Tính Năng Suất',
          icon: Icons.speed_rounded,
          onTap: () => context.push('/productivity_calc'),
        ),
        TechnologyMenuEntry(
          id: 'extension_technical_converter',
          title: 'Quy Đổi Kỹ Thuật',
          icon: Icons.swap_horiz_rounded,
          onTap: () => context.push('/technical_converter'),
        ),
      ],
    );
  }
}
