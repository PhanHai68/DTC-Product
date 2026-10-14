import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/product_data.dart';
import '../../providers/tea_color_sorter_provider.dart';
import '../tea_color_sorter/tea_color_sorter_screen.dart';
import 'agro_air_system.dart';

class AgroColorSorterScreen extends StatelessWidget {
  const AgroColorSorterScreen({super.key, this.initialModel});

  /// Model mở sẵn (VD từ tìm kiếm); mặc định H7.
  final String? initialModel;

  @override
  Widget build(BuildContext context) {
    final specs = agroColorSorterSpecs.map(withAgroAirSystem).toList();
    final models = [
      for (final spec in specs)
        if ((spec['model'] ?? '').isNotEmpty) spec['model']!,
    ];
    final requested = initialModel?.trim() ?? '';
    final startModel = models.firstWhere(
      (m) => m.toLowerCase() == requested.toLowerCase(),
      orElse: () => 'H7',
    );

    return ChangeNotifierProvider<TeaColorSorterProvider>(
      create: (_) => TeaColorSorterProvider(
        data: specs,
        initialModel: startModel,
      ),
      child: TeaColorSorterScreen(
        initialModel: startModel,
        availableModels: models,
      ),
    );
  }
}
