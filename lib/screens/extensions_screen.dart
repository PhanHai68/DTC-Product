import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class ExtensionsScreen extends StatelessWidget {
  const ExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Công cụ & Tiện ích',
      backButtonKey: const Key('extensions_back_button'),
      entries: [
        TechnologyMenuEntry(
          id: 'extension_notes',
          title: 'Ghi Chú & Nhắc Hẹn',
          icon: Icons.edit_note_rounded,
          featured: true,
          onTap: () => context.push('/notes'),
        ),
        TechnologyMenuEntry(
          id: 'extension_maintenance',
          title: 'Nhắc Nhở Lịch Bảo Trì',
          icon: Icons.build_circle_outlined,
          featured: true,
          onTap: () => context.push('/maintenance'),
        ),
        TechnologyMenuEntry(
          id: 'extension_project_tracking',
          title: 'Project Timeline',
          icon: Icons.engineering_outlined,
          featured: true,
          onTap: () => context.push('/projects'),
        ),
        TechnologyMenuEntry(
          id: 'extension_sample_record',
          title: 'Lập Form Lưu Mẫu',
          icon: Icons.assignment_turned_in_outlined,
          featured: true,
          onTap: () => context.push('/sample_record'),
        ),
        TechnologyMenuEntry(
          id: 'extension_maintenance_report',
          title: 'Báo Cáo Bảo Trì',
          icon: Icons.build_rounded,
          featured: true,
          onTap: () => context.push('/maintenance_report'),
        ),
        TechnologyMenuEntry(
          id: 'extension_productivity_calc',
          title: 'Tính Năng Suất',
          icon: Icons.speed_rounded,
          onTap: () => context.push('/productivity_calc'),
        ),
        TechnologyMenuEntry(
          id: 'extension_technical_converter',
          title: 'Chuyển Đổi Đơn Vị',
          icon: Icons.swap_horiz_rounded,
          onTap: () => context.push('/technical_converter'),
        ),
      ],
    );
  }
}
