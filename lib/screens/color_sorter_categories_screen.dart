import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class ColorSorterCategoriesScreen extends StatelessWidget {
  const ColorSorterCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy tách màu',
      entries: [
        TechnologyMenuEntry(
          id: 'category_rice',
          title: 'Gạo',
          icon: Icons.rice_bowl_rounded,
          imagePath: 'assets/images/icon_paddy.jpg',
          iconColor: const Color(0xFFE65100),
          iconBackgroundColor: const Color(0xFFFFF3E0),
          featured: true,
          onTap: () => context.push('/color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_paddy',
          title: 'Thóc và Gạo xô',
          icon: Icons.grass_rounded,
          imagePath: 'assets/images/icon_paddy.jpg',
          iconColor: const Color(0xFFF57F17),
          iconBackgroundColor: const Color(0xFFFFFDE7),
          onTap: () => context.push('/paddy_color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_tea',
          title: 'Trà (Chè)',
          icon: Icons.eco_rounded,
          imagePath: 'assets/images/icon_tea.jpg',
          iconColor: const Color(0xFF2E7D32),
          iconBackgroundColor: const Color(0xFFE8F5E9),
          onTap: () => context.push('/tea_color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_mineral',
          title: 'Khoáng sản',
          icon: Icons.terrain_rounded,
          imagePath: 'assets/images/icon_mineral.jpg',
          iconColor: const Color(0xFF00838F),
          iconBackgroundColor: const Color(0xFFE0F7FA),
          onTap: () => context.push('/mineral_color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_agro',
          title: 'Nông sản và các loại hạt',
          icon: Icons.spa_rounded,
          imagePath: 'assets/images/icon_agro.jpg',
          iconColor: const Color(0xFF5D4037),
          iconBackgroundColor: const Color(0xFFEFEBE9),
          onTap: () => context.push('/agro_color_sorter_menu'),
        ),
      ],
    );
  }
}
