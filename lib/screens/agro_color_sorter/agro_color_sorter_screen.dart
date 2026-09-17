import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/agro_specs_data.dart';
import '../../providers/tea_color_sorter_provider.dart';
import '../tea_color_sorter/tea_color_sorter_screen.dart';

class AgroColorSorterScreen extends StatelessWidget {
  const AgroColorSorterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TeaColorSorterProvider>(
      create: (_) => TeaColorSorterProvider(
        data: agroColorSorterSpecs,
        initialModel: 'H7',
      ),
      child: const TeaColorSorterScreen(
        initialModel: 'H7',
        availableModels: ['H7'],
      ),
    );
  }
}
