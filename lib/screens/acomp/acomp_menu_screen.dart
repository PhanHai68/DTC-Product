import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/technology_menu.dart';

class AcompMenuScreen extends StatelessWidget {
  const AcompMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy nén khí ACOMP',
      entries: [
        TechnologyMenuEntry(
          id: 'acomp_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/acomp_tech_category'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_suitable_btn',
          title: 'Chọn công suất phù hợp',
          icon: Icons.tune_rounded,
          onTap: () => context.push('/acomp_suitable'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_vsd_compare_btn',
          title: 'So sánh biến tần – cố định',
          icon: Icons.compare_arrows_rounded,
          onTap: () => context.push('/acomp_vsd_compare'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_tank_btn',
          title: 'Tính thể tích bình chứa',
          icon: Icons.propane_tank_outlined,
          onTap: () => context.push('/acomp_tank'),
        ),
        TechnologyMenuEntry(
          id: 'air_system_config_btn',
          title: 'Cấu hình hệ thống khí nén',
          icon: Icons.account_tree_outlined,
          onTap: () => context.push('/air_system_config'),
        ),
        TechnologyMenuEntry(
          id: 'air_room_layout_btn',
          title: 'Tính toán phòng lắp đặt',
          icon: Icons.meeting_room_outlined,
          // Tab "Phòng lắp đặt" của Cấu hình hệ thống khí nén.
          onTap: () => context.push('/air_system_config?tab=room'),
        ),
        TechnologyMenuEntry(
          id: 'pipe_survey_btn',
          title: 'Khảo sát vật tư ngoại tuyến',
          icon: Icons.route_outlined,
          // Vẽ tuyến ống tại công trình, bóc vật tư theo thực tế.
          onTap: () => context.push('/pipe_survey'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_mccb_btn',
          title: 'Chọn MCCB và dây điện',
          icon: Icons.electrical_services_rounded,
          onTap: () => context.push('/acomp_mccb_cable'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_pipe_btn',
          title: 'Tính đường ống khí nén',
          icon: Icons.plumbing_rounded,
          onTap: () => context.push('/acomp_pipe'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_fill_time_btn',
          title: 'Thời gian nạp đầy bình',
          icon: Icons.timer_outlined,
          onTap: () => context.push('/acomp_tank_fill_time'),
        ),
        TechnologyMenuEntry(
          id: 'acomp_troubleshooting_btn',
          title: 'Hướng dẫn xử lý sự cố',
          icon: Icons.build_circle_outlined,
          onTap: () => context.push('/acomp_troubleshooting'),
        ),
      ],
    );
  }
}
