import 'package:flutter/material.dart';

import '../../grinding_machine/utils/grinding_spec_sheet.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';

/// Chuẩn bị dữ liệu trang "Thông số kỹ thuật" của 1 model thiết bị theo đúng
/// bố cục 3 tab + bảng màu của máy nghiền ([GrindingSpecItem]).
class EquipmentSpecSheet {
  const EquipmentSpecSheet({
    required this.config,
    required this.machine,
    required this.series,
    this.imagePath,
    this.imageCaption,
  });

  final EquipmentCatalogConfig config;
  final EquipmentMachine machine;
  final EquipmentSeries? series;
  final String? imagePath;
  final String? imageCaption;

  String get title => '${config.upperLabel} ${machine.model.toUpperCase()}';

  List<GrindingSpecItem> get technicalRows =>
      _rows(EquipmentSpecGroup.technical);
  List<GrindingSpecItem> get extraRows => _rows(EquipmentSpecGroup.extra);
  List<GrindingSpecItem> get installRows => _rows(EquipmentSpecGroup.install);

  List<(String title, String value, IconData icon, Color color)>
  get highlights => [
    for (final h in machine.highlights)
      if (_highlightStyle(h.kind) case (final icon, final color))
        (h.title, h.value, icon, color),
  ];

  /// Ô giá trị trên thẻ model theo [EquipmentCatalogConfig.chipKeys].
  List<(String, Color)> get chips {
    const colors = [
      GrindingSpecSheet.capacityColor,
      GrindingSpecSheet.structureColor,
    ];
    final result = <(String, Color)>[];
    for (final group in config.chipKeys) {
      for (final key in group) {
        if (machine.valueOf(key) case final v?) {
          result.add((_short(v), colors[result.length % colors.length]));
          break;
        }
      }
    }
    return result;
  }

  List<GrindingSpecItem> _rows(EquipmentSpecGroup group) => [
    for (final spec in machine.specsOf(group))
      GrindingSpecItem(
        label: spec.label,
        value: spec.value,
        icon: styleOf(spec.key).$1,
        color: styleOf(spec.key).$2,
      ),
  ];

  /// Văn bản gửi khách hàng (Zalo/SMS...).
  String shareText({
    required String contactName,
    required String contactPhone,
  }) {
    final buffer = StringBuffer()..writeln('📋 THÔNG SỐ KỸ THUẬT $title');
    if (series != null) {
      buffer.writeln('Dòng máy: ${series!.displayCode} · ${series!.nameVi}');
    }
    buffer.writeln();
    for (final row in [...technicalRows, ...extraRows, ...installRows]) {
      buffer.writeln('• ${row.label}: ${row.value.replaceAll('\n', '; ')}');
    }
    if (series != null && series!.applicationVi.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Ứng dụng: ${series!.applicationVi}');
    }
    buffer
      ..writeln()
      ..writeln('👤 Liên hệ tư vấn: $contactName')
      ..writeln('📞 Điện thoại: $contactPhone');
    return buffer.toString().trimRight();
  }

  /// Bỏ phần chú thích trong ngoặc để ô giá trị trên thẻ model gọn
  /// ("5 - 50 kg (tùy nguyên liệu)" → "5 - 50 kg").
  static String _short(String value) =>
      value.split('\n').first.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();

  static (IconData, Color) _highlightStyle(String kind) => switch (kind) {
    'speed' => (Icons.speed, Colors.orange.shade800),
    'capacity' => (Icons.speed, Colors.orange.shade800),
    'weight' => (Icons.scale, Colors.blue.shade800),
    'volume' => (Icons.propane_tank_outlined, Colors.blue.shade800),
    'mesh' => (Icons.grain, Colors.blue.shade800),
    'time' => (Icons.timer_outlined, Colors.orange.shade800),
    'air' => (Icons.air, Colors.teal.shade700),
    'size' => (Icons.straighten, Colors.blue.shade800),
    _ => (Icons.electrical_services, Colors.green.shade800),
  };

  /// Icon + màu theo loại thông số, cùng quy ước với máy nghiền.
  static (IconData, Color) styleOf(String key) => switch (key) {
    'pack_weight' ||
    'capacity' ||
    'capacity_line' ||
    'capacity_long' ||
    'capacity_round' ||
    'capacity_rice' ||
    'capacity_paddy' ||
    'max_load_weight' => (Icons.scale, GrindingSpecSheet.capacityColor),
    'speed' ||
    'speed_rpm' ||
    'vibration_freq' => (Icons.speed, GrindingSpecSheet.structureColor),
    'mixing_time' || 'load_time' || 'discharge_time' => (
      Icons.timer_outlined,
      GrindingSpecSheet.structureColor,
    ),
    'moisture_rate' => (
      Icons.water_drop_outlined,
      GrindingSpecSheet.finenessColor,
    ),
    'energy' || 'fuel' => (
      Icons.local_fire_department_outlined,
      GrindingSpecSheet.hotColor,
    ),
    'safety' => (Icons.verified_user_outlined, GrindingSpecSheet.neutralColor),
    'roller' => (Icons.album_outlined, GrindingSpecSheet.structureColor),
    'pressure' ||
    'resistance' ||
    'water_pressure' => (Icons.compress, GrindingSpecSheet.airColor),
    'bag_length' ||
    'head_diameter' ||
    'length' ||
    'width_mm' ||
    'height_mm' ||
    'distance' => (Icons.straighten, GrindingSpecSheet.sizeColor),
    'filter_area' => (Icons.filter_alt_outlined, GrindingSpecSheet.airColor),
    'accuracy' => (Icons.track_changes, GrindingSpecSheet.finenessColor),
    'mesh' || 'granularity' => (Icons.grain, GrindingSpecSheet.finenessColor),
    'work_volume' || 'total_volume' => (
      Icons.propane_tank_outlined,
      GrindingSpecSheet.weightColor,
    ),
    'bag_size' ||
    'outer_bag' ||
    'tag_size' => (Icons.crop_portrait_rounded, GrindingSpecSheet.sizeColor),
    'sealing' => (Icons.compress, GrindingSpecSheet.hotColor),
    'dosing' ||
    'feed_method' => (Icons.tune_rounded, GrindingSpecSheet.weightColor),
    'power_kw' ||
    'power_main' ||
    'power_feed' ||
    'power_fan' ||
    'dumping_motor' ||
    'intensifier_motor' => (
      Icons.electrical_services,
      GrindingSpecSheet.electricColor,
    ),
    'power_supply' => (Icons.power, GrindingSpecSheet.electricColor),
    'film_width' ||
    'coil' ||
    'packaging_material' => (Icons.layers_outlined, GrindingSpecSheet.airColor),
    'hopper_volume' || 'hopper_count' => (
      Icons.inventory_2_outlined,
      GrindingSpecSheet.weightColor,
    ),
    'loading_coefficient' ||
    'density' => (Icons.percent_rounded, GrindingSpecSheet.weightColor),
    'container' => (Icons.shopping_bag_outlined, GrindingSpecSheet.airColor),
    'output_size' => (Icons.output_rounded, GrindingSpecSheet.sizeColor),
    'material' => (Icons.shield_outlined, GrindingSpecSheet.neutralColor),
    'dimensions' ||
    'rotation_height' => (Icons.straighten, GrindingSpecSheet.sizeColor),
    'weight' => (Icons.scale, GrindingSpecSheet.weightColor),
    'air' || 'air_flow' => (Icons.air, GrindingSpecSheet.airColor),
    _ => (Icons.info_outline, GrindingSpecSheet.neutralColor),
  };
}
