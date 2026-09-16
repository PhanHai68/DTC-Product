import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mineral_specs_data.dart';
import '../../providers/tea_color_sorter_provider.dart';
import '../tea_color_sorter/tea_color_sorter_screen.dart';

class MineralColorSorterScreen extends StatelessWidget {
  const MineralColorSorterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TeaColorSorterProvider>(
      create: (_) => TeaColorSorterProvider(
        data: mineralColorSorterSpecs,
        initialModel: 'SX8',
      ),
      child: const TeaColorSorterScreen(
        initialModel: 'SX8',
        availableModels: ['SX8'],
      ),
    );
  }
}
