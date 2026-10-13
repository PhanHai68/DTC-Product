import 'package:flutter/material.dart';

import '../data/product_data.dart';
import 'packing_machine.dart';

/// Một đặc điểm nổi bật của máy cân đóng gói, đọc từ
/// assets/database/packing_scale/features.json.
class PackingFeature {
  final String title;
  final String summary;
  final String detail;

  /// Tên icon Material, phải có trong [packingFeatureIcons].
  final String iconName;

  const PackingFeature({
    required this.title,
    required this.summary,
    required this.detail,
    required this.iconName,
  });

  IconData get icon =>
      packingFeatureIcons[iconName] ?? Icons.check_circle_outline;
}

/// Icon dùng được trong features.json. Flutter chỉ đóng gói icon được nhắc
/// tới trong code, nên muốn dùng icon mới phải thêm vào bảng này.
const packingFeatureIcons = <String, IconData>{
  'build_circle_outlined': Icons.build_circle_outlined,
  'cable_outlined': Icons.cable_outlined,
  'call_split_rounded': Icons.call_split_rounded,
  'cancel_presentation_outlined': Icons.cancel_presentation_outlined,
  'change_circle_outlined': Icons.change_circle_outlined,
  'cleaning_services_outlined': Icons.cleaning_services_outlined,
  'content_cut_rounded': Icons.content_cut_rounded,
  'crop_portrait_rounded': Icons.crop_portrait_rounded,
  'device_thermostat_outlined': Icons.device_thermostat_outlined,
  'display_settings_outlined': Icons.display_settings_outlined,
  'electrical_services_outlined': Icons.electrical_services_outlined,
  'grain_outlined': Icons.grain_outlined,
  'horizontal_rule_rounded': Icons.horizontal_rule_rounded,
  'hub_outlined': Icons.hub_outlined,
  'input_rounded': Icons.input_rounded,
  'inventory_2_outlined': Icons.inventory_2_outlined,
  'linear_scale_rounded': Icons.linear_scale_rounded,
  'lock_outline_rounded': Icons.lock_outline_rounded,
  'notification_important_outlined': Icons.notification_important_outlined,
  'oil_barrel_outlined': Icons.oil_barrel_outlined,
  'print_outlined': Icons.print_outlined,
  'scale_outlined': Icons.scale_outlined,
  'sensors_outlined': Icons.sensors_outlined,
  'settings_remote_outlined': Icons.settings_remote_outlined,
  'settings_suggest_outlined': Icons.settings_suggest_outlined,
  'shield_outlined': Icons.shield_outlined,
  'shuffle_rounded': Icons.shuffle_rounded,
  'speed_outlined': Icons.speed_outlined,
  'stacked_bar_chart_outlined': Icons.stacked_bar_chart_outlined,
  'straighten_outlined': Icons.straighten_outlined,
  'swap_horiz_rounded': Icons.swap_horiz_rounded,
  'tune_rounded': Icons.tune_rounded,
  'touch_app_outlined': Icons.touch_app_outlined,
  'track_changes_outlined': Icons.track_changes_outlined,
  'verified_outlined': Icons.verified_outlined,
  'view_module_outlined': Icons.view_module_outlined,
};

/// Bộ đặc điểm của máy theo trường `feature_set` trong machines.json.
List<PackingFeature> packingFeaturesFor(PackingMachine machine) {
  final set = packingFeatureSets[machine.featureSet];
  if (set == null) return const [];
  return [
    for (final item in set)
      PackingFeature(
        title: item['title'] ?? '',
        summary: item['summary'] ?? '',
        detail: item['detail'] ?? '',
        iconName: item['icon'] ?? '',
      ),
  ];
}
