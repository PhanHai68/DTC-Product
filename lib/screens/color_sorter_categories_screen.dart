import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class ColorSorterCategoriesScreen extends StatelessWidget {
  const ColorSorterCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void developing() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tính năng đang được phát triển')),
      );
    }

    return TechnologyMenuScaffold(
      title: 'Máy tách màu',
      entries: [
        TechnologyMenuEntry(
          id: 'category_rice',
          title: 'Máy tách màu Gạo',
          icon: Icons.grass_rounded,
          featured: true,
          onTap: () => context.push('/color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_paddy',
          title: 'Máy tách màu Thóc và Gạo xô',
          icon: Icons.agriculture_rounded,
          onTap: developing,
        ),
        TechnologyMenuEntry(
          id: 'category_tea',
          title: 'Máy tách màu Trà',
          icon: Icons.emoji_nature_rounded,
          onTap: () => context.push('/tea_color_sorter_menu'),
        ),
        TechnologyMenuEntry(
          id: 'category_mineral',
          title: 'Máy tách màu khoáng sản',
          icon: Icons.landslide_rounded,
          onTap: developing,
        ),
        TechnologyMenuEntry(
          id: 'category_agro',
          title: 'Máy tách màu nông sản và các loại hạt',
          icon: Icons.eco_rounded,
          onTap: developing,
        ),
      ],
    );
  }
}
