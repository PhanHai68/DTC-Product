import 'package:go_router/go_router.dart';

import 'equipment_catalog_config.dart';
import 'screens/equipment_compare_screen.dart';
import 'screens/equipment_detail_screen.dart';
import 'screens/equipment_home_screen.dart';
import 'screens/equipment_search_screen.dart';
import 'screens/equipment_selector_screen.dart';
import 'screens/equipment_series_screen.dart';

/// Các route của 1 catalog thiết bị, đặt dưới [EquipmentCatalogConfig.routeBase]
/// (VD /packing_machine, /packing_machine/detail/:machineId...).
List<GoRoute> equipmentRoutes(EquipmentCatalogConfig config) => [
  GoRoute(
    path: config.routeBase,
    builder: (_, _) => EquipmentHomeScreen(config: config),
  ),
  GoRoute(
    path: '${config.routeBase}/search',
    builder: (_, _) => EquipmentSearchScreen(config: config),
  ),
  GoRoute(
    path: '${config.routeBase}/series',
    builder: (_, state) {
      // Mã series nằm trên địa chỉ (?code=) để tải lại trang web vẫn mở đúng;
      // không có mã thì về trang chính của danh mục.
      final code =
          state.uri.queryParameters['code'] ??
          (state.extra is String ? state.extra as String : null);
      if (code == null) return EquipmentHomeScreen(config: config);
      return EquipmentSeriesScreen(config: config, seriesCode: code);
    },
  ),
  GoRoute(
    path: '${config.routeBase}/detail/:machineId',
    builder: (_, state) => EquipmentDetailScreen(
      config: config,
      machineId: state.pathParameters['machineId']!,
    ),
  ),
  GoRoute(
    path: '${config.routeBase}/selector',
    builder: (_, _) => EquipmentSelectorScreen(config: config),
  ),
  GoRoute(
    path: '${config.routeBase}/compare',
    builder: (_, state) => EquipmentCompareScreen(
      config: config,
      initialMachineIds: state.extra is List<String>
          ? state.extra as List<String>
          : null,
    ),
  ),
];
