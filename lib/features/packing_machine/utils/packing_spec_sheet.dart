import 'package:flutter/material.dart';

import '../../grinding_machine/utils/grinding_spec_sheet.dart';
import '../models/packing_catalog.dart';

/// Chuẩn bị dữ liệu trang "Thông số kỹ thuật" của 1 model máy đóng gói theo
/// đúng bố cục 3 tab + bảng màu của máy nghiền ([GrindingSpecItem]).
class PackingSpecSheet {
  const PackingSpecSheet({
    required this.machine,
    required this.series,
    this.imagePath,
    this.imageCaption,
  });

  final PackingMachine machine;
  final PackingSeries? series;
  final String? imagePath;
  final String? imageCaption;

  String get title => 'MÁY ĐÓNG GÓI ${machine.model.toUpperCase()}';

  List<GrindingSpecItem> get technicalRows => _rows(PackingSpecGroup.technical);
  List<GrindingSpecItem> get extraRows => _rows(PackingSpecGroup.extra);
  List<GrindingSpecItem> get installRows => _rows(PackingSpecGroup.install);

  List<(String title, String value, IconData icon, Color color)>
  get highlights => [
    for (final h in machine.highlights)
      if (_highlightStyle(h.kind) case (final icon, final color))
        (h.title, h.value, icon, color),
  ];

  /// 2 ô giá trị trên thẻ model: khối lượng gói + tốc độ.
  List<(String, Color)> get chips => [
    if (machine.valueOf('pack_weight') case final v?)
      (_short(v), GrindingSpecSheet.capacityColor),
    if (machine.valueOf('speed') case final v?)
      (_short(v), GrindingSpecSheet.structureColor),
  ];

  List<GrindingSpecItem> _rows(PackingSpecGroup group) => [
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
    'weight' => (Icons.scale, Colors.blue.shade800),
    _ => (Icons.electrical_services, Colors.green.shade800),
  };

  /// Icon + màu theo loại thông số, cùng quy ước với máy nghiền.
  static (IconData, Color) styleOf(String key) => switch (key) {
    'pack_weight' => (Icons.scale, GrindingSpecSheet.capacityColor),
    'speed' => (Icons.speed, GrindingSpecSheet.structureColor),
    'accuracy' => (Icons.track_changes, GrindingSpecSheet.finenessColor),
    'bag_size' ||
    'outer_bag' ||
    'tag_size' => (Icons.crop_portrait_rounded, GrindingSpecSheet.sizeColor),
    'sealing' => (Icons.compress, GrindingSpecSheet.hotColor),
    'dosing' ||
    'feed_method' => (Icons.tune_rounded, GrindingSpecSheet.weightColor),
    'power_kw' => (Icons.electrical_services, GrindingSpecSheet.electricColor),
    'power_supply' => (Icons.power, GrindingSpecSheet.electricColor),
    'film_width' ||
    'coil' ||
    'packaging_material' => (Icons.layers_outlined, GrindingSpecSheet.airColor),
    'hopper_volume' || 'hopper_count' => (
      Icons.inventory_2_outlined,
      GrindingSpecSheet.weightColor,
    ),
    'container' => (Icons.shopping_bag_outlined, GrindingSpecSheet.airColor),
    'material' => (Icons.shield_outlined, GrindingSpecSheet.neutralColor),
    'dimensions' => (Icons.straighten, GrindingSpecSheet.sizeColor),
    'weight' => (Icons.scale, GrindingSpecSheet.weightColor),
    'air' => (Icons.air, GrindingSpecSheet.airColor),
    _ => (Icons.info_outline, GrindingSpecSheet.neutralColor),
  };
}
