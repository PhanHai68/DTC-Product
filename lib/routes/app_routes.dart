import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/sample_record/sample_record_screen.dart';
import '../screens/productivity/productivity_calc_screen.dart';
import '../screens/technical_converter/technical_converter_screen.dart';
import '../screens/color_sorter_menu_screen.dart';
import '../screens/color_sorter/color_sorter_screen.dart';
import '../screens/color_sorter/color_sorter_3d_screen.dart';
import '../screens/color_sorter/color_sorter_manual_screen.dart';
import '../screens/aux_equip/aux_equip_screen.dart';
import '../screens/payback_analysis_menu_screen.dart';
import '../screens/payback/power_consumption_screen.dart';
import '../screens/payback/electricity_bill_screen.dart';
import '../screens/payback/processing_profit_screen.dart';
import '../screens/payback/payback_period_screen.dart';
import '../screens/payback/self_business_screen.dart';
import '../screens/payback/payback_chart_screen.dart';
import '../screens/acomp/acomp_menu_screen.dart';
import '../screens/acomp/acomp_tech_category_screen.dart';
import '../screens/acomp/acomp_tech_detail_screen.dart';
import '../screens/acomp/acomp_suitable_screen.dart';
import '../screens/acomp/acomp_tank_screen.dart';
import '../screens/acomp/acomp_mccb_cable_screen.dart';
import '../screens/acomp/acomp_pipe_screen.dart';
import '../screens/acomp/acomp_installation_drawing_screen.dart';
import '../screens/acomp/acomp_tank_fill_time_screen.dart';
import '../screens/acomp/acomp_troubleshooting_menu_screen.dart';
import '../screens/acomp/acomp_common_errors_screen.dart';
import '../screens/acomp/acomp_ds8011_settings_screen.dart';
import '../screens/acomp/acomp_operation_manual_screen.dart';
// Packing module screens
import '../screens/packing/packing_menu_screen.dart';
import '../screens/packing/packing_search_screen.dart';
import '../screens/packing/machine_detail_screen.dart';
import '../screens/packing/machine_selector_screen.dart';
import '../screens/packing/machine_catalog_screen.dart';
import '../screens/packing/compare_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/extensions',
      builder: (context, state) => const ExtensionsScreen(),
    ),
    GoRoute(
      path: '/sample_record',
      builder: (context, state) => const SampleRecordScreen(),
    ),
    GoRoute(
      path: '/productivity_calc',
      builder: (context, state) => const ProductivityCalcScreen(),
    ),
    GoRoute(
      path: '/technical_converter',
      builder: (context, state) => const TechnicalConverterScreen(),
    ),
    GoRoute(
      path: '/color_sorter_menu',
      builder: (context, state) => const ColorSorterMenuScreen(),
    ),
    GoRoute(
      path: '/acomp_menu',
      builder: (context, state) => const AcompMenuScreen(),
    ),
    GoRoute(
      path: '/acomp_tech_category',
      builder: (context, state) => const AcompTechCategoryScreen(),
    ),
    GoRoute(
      path: '/acomp_tech_detail',
      builder: (context, state) {
        final categoryType = state.extra as String? ?? 'PV';
        return AcompTechDetailScreen(categoryType: categoryType);
      },
    ),
    GoRoute(
      path: '/acomp_suitable',
      builder: (context, state) => const AcompSuitableScreen(),
    ),
    GoRoute(
      path: '/acomp_tank',
      builder: (context, state) => const AcompTankScreen(),
    ),
    GoRoute(
      path: '/acomp_mccb_cable',
      builder: (context, state) => const AcompMccbCableScreen(),
    ),
    GoRoute(
      path: '/acomp_pipe',
      builder: (context, state) => const AcompPipeScreen(),
    ),
    GoRoute(
      path: '/acomp_drawing',
      builder: (context, state) => const AcompInstallationDrawingScreen(),
    ),
    GoRoute(
      path: '/acomp_tank_fill_time',
      builder: (context, state) => const AcompTankFillTimeScreen(),
    ),
    GoRoute(
      path: '/acomp_troubleshooting',
      builder: (context, state) => const AcompTroubleshootingMenuScreen(),
    ),
    GoRoute(
      path: '/acomp_common_errors',
      builder: (context, state) => const AcompCommonErrorsScreen(),
    ),
    GoRoute(
      path: '/acomp_ds8011_settings',
      builder: (context, state) => const AcompDs8011SettingsScreen(),
    ),
    GoRoute(
      path: '/acomp_operation_manual',
      builder: (context, state) => const AcompOperationManualScreen(),
    ),
    GoRoute(
      path: '/color_sorter',
      builder: (context, state) => const ColorSorterScreen(),
    ),
    GoRoute(
      path: '/color_sorter_3d',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final modelName = extra?['modelName'] ?? 'SC16 Pro';
        final modelPath = extra?['modelPath'] ?? 'assets/models/sc16_pro.glb';
        return ColorSorter3dScreen(modelName: modelName, modelPath: modelPath);
      },
    ),
    GoRoute(
      path: '/color_sorter_manual',
      builder: (context, state) => const ColorSorterManualScreen(),
    ),
    GoRoute(
      path: '/aux_equip',
      builder: (context, state) {
        final initialModel = state.extra as String?;
        return AuxEquipScreen(initialModel: initialModel);
      },
    ),
    GoRoute(
      path: '/payback_analysis',
      builder: (context, state) => const PaybackAnalysisMenuScreen(),
    ),
    GoRoute(
      path: '/power_consumption',
      builder: (context, state) => const PowerConsumptionScreen(),
    ),
    GoRoute(
      path: '/electricity_bill',
      builder: (context, state) => const ElectricityBillScreen(),
    ),
    GoRoute(
      path: '/processing_profit',
      builder: (context, state) => const ProcessingProfitScreen(),
    ),
    GoRoute(
      path: '/payback_period',
      builder: (context, state) => const PaybackPeriodScreen(),
    ),
    GoRoute(
      path: '/self_business',
      builder: (context, state) => const SelfBusinessScreen(),
    ),
    GoRoute(
      path: '/payback_chart',
      builder: (context, state) => const PaybackChartScreen(),
    ),
    // ─── Packing Module ──────────────────────────────────────────────────────
    GoRoute(
      path: '/packing_menu',
      builder: (context, state) => const PackingMenuScreen(),
    ),
    GoRoute(
      path: '/packing_search',
      builder: (context, state) => const PackingSearchScreen(),
    ),
    GoRoute(
      path: '/packing_detail',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          return MachineDetailScreen(
            modelName: extra['model'] as String? ?? '',
            showCatalog: extra['showCatalog'] as bool? ?? true,
          );
        }
        return MachineDetailScreen(modelName: extra as String? ?? '');
      },
    ),
    GoRoute(
      path: '/machine_selector',
      builder: (context, state) => const MachineSelectorScreen(),
    ),
    GoRoute(
      path: '/machine_catalog',
      builder: (context, state) => const MachineCatalogScreen(),
    ),
    GoRoute(
      path: '/machine_compare',
      builder: (context, state) => const CompareScreen(),
    ),
    GoRoute(
      path: '/packing_catalog_viewer',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return PackingCatalogViewerScreen(
          assetPath: extra['path'] as String? ?? '',
          initialPage: extra['page'] as int? ?? 1,
          modelName: extra['model'] as String? ?? '',
        );
      },
    ),
  ],
);
