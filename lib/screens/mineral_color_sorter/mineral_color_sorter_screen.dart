import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/product_data.dart';
import '../../providers/tea_color_sorter_provider.dart';
import '../tea_color_sorter/tea_color_sorter_screen.dart';

class MineralColorSorterScreen extends StatelessWidget {
  const MineralColorSorterScreen({super.key, this.initialModel});

  /// Model mở sẵn (VD từ "Chọn máy phù hợp"); mặc định SX8.
  final String? initialModel;

  @override
  Widget build(BuildContext context) {
    // Danh sách model lấy theo thứ tự trong color_sorter/sx8_mineral.json.
    final models = [
      for (final spec in mineralColorSorterSpecs)
        if ((spec['model'] ?? '').isNotEmpty) spec['model']!,
    ];
    final model = models.contains(initialModel) ? initialModel! : 'SX8';
    return ChangeNotifierProvider<TeaColorSorterProvider>(
      create: (_) => TeaColorSorterProvider(
        data: mineralColorSorterSpecs,
        initialModel: model,
      ),
      child: TeaColorSorterScreen(initialModel: model, availableModels: models),
    );
  }
}
