import 'package:flutter/material.dart';

import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import 'grinding_format.dart';
import 'grinding_series_images.dart';

/// 1 dòng thông số đã sẵn sàng hiển thị (nhãn tiếng Việt, giá trị có đơn vị,
/// icon + màu theo cùng quy ước trang máy tách màu).
class GrindingSpecItem {
  const GrindingSpecItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

/// Chuẩn bị dữ liệu trang "Thông số kỹ thuật" máy nghiền theo bố cục 3 tab
/// giống máy tách màu. CHỈ dùng dữ liệu có trong database — field null thì
/// bỏ dòng, không tự điền giá trị.
class GrindingSpecSheet {
  GrindingSpecSheet({
    required this.machine,
    required this.series,
    required List<GrindingExtraSpec> extraSpecs,
  }) : extraRows = _buildExtraRows(extraSpecs);

  final GrindingMachine machine;
  final GrindingSeries? series;
  final List<GrindingSpecItem> extraRows;

  // Cùng bảng màu theo loại thông số của máy tách màu.
  static const capacityColor = Color(0xFFEA6C00);
  static const structureColor = Color(0xFF0D47A1);
  static const finenessColor = Color(0xFF2E7D32);
  static const electricColor = Color(0xFFF57F17);
  static const airColor = Color(0xFF006064);
  static const weightColor = Color(0xFF4A148C);
  static const sizeColor = Color(0xFF1A237E);
  static const neutralColor = Color(0xFF37474F);
  static const hotColor = Color(0xFFB71C1C);

  /// Ảnh máy theo dòng — chỉ dòng có ảnh mới hiện khung ảnh (bảng ảnh ở
  /// GrindingSeriesImages).
  String? get imagePath => GrindingSeriesImages.pathFor(machine.seriesCode);
  String? get imageCaption =>
      GrindingSeriesImages.captionFor(machine.seriesCode);
  bool get has3dModel => machine.seriesCode == 'ASP_ULTRAFINE';

  String get title => 'MÁY NGHIỀN ${machine.model.toUpperCase()}';

  // Tên dòng máy đã hiện ngay dưới tiêu đề nên không lặp lại thành 1 dòng.
  List<GrindingSpecItem> get technicalRows => [
    if (GrindingFormat.capacityRange(machine) case final v?)
      GrindingSpecItem(
        label: 'Công suất xử lý',
        value: v,
        icon: Icons.speed,
        color: capacityColor,
      ),
    if (GrindingFormat.inputSize(machine) case final v?)
      GrindingSpecItem(
        label: 'Kích thước đầu vào',
        value: v,
        icon: Icons.input_rounded,
        color: weightColor,
      ),
    if (GrindingFormat.finenessRange(machine) case final v?)
      GrindingSpecItem(
        label: 'Độ mịn đầu ra',
        value: v,
        icon: Icons.grain,
        color: finenessColor,
      ),
    if (GrindingFormat.motorRange(machine) case final v?)
      GrindingSpecItem(
        label: 'Công suất động cơ chính',
        value: v,
        icon: Icons.electrical_services,
        color: electricColor,
      ),
    if (machine.speedRpmMin != null || machine.speedRpmMax != null)
      GrindingSpecItem(
        label: 'Tốc độ',
        value: _range(machine.speedRpmMin, machine.speedRpmMax, 'vòng/phút'),
        icon: Icons.autorenew_rounded,
        color: structureColor,
      ),
  ];

  List<GrindingSpecItem> get installRows => [
    if (machine.dimensionsDisplay case final v?)
      GrindingSpecItem(
        label: 'Kích thước máy (D x R x C)',
        value: v,
        icon: Icons.straighten,
        color: sizeColor,
      ),
    if (machine.weightKg case final w?)
      GrindingSpecItem(
        label: 'Trọng lượng',
        value: '${_num(w)} kg',
        icon: Icons.scale,
        color: weightColor,
      ),
  ];

  /// Giá trị thẻ chỉ số nổi bật: số không kèm đơn vị, đơn vị nằm ở nhãn —
  /// giống "16 - 22 / Năng suất (T/h)" của máy tách màu.
  List<(String title, String value, IconData icon, Color color)>
  get highlights => [
    if (machine.capacityMinKgH != null || machine.capacityMaxKgH != null)
      (
        'Công suất (kg/h)',
        _range(machine.capacityMinKgH, machine.capacityMaxKgH, null),
        Icons.speed,
        Colors.orange.shade800,
      ),
    if ((machine.finenessUnit ?? '').isNotEmpty &&
        (machine.finenessMin != null || machine.finenessMax != null))
      (
        'Độ mịn (${machine.finenessUnit})',
        _range(machine.finenessMin, machine.finenessMax, null),
        Icons.grain,
        Colors.blue.shade800,
      ),
    if (machine.mainMotorKwMin != null || machine.mainMotorKwMax != null)
      (
        'Động cơ (kW)',
        _range(machine.mainMotorKwMin, machine.mainMotorKwMax, null),
        Icons.electrical_services,
        Colors.green.shade800,
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
      buffer.writeln('• ${row.label}: ${row.value.replaceAll('\n', ' ')}');
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

  // ---------------------------------------------------------------------------

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _range(double? min, double? max, String? unit) {
    final suffix = unit == null ? '' : ' $unit';
    if (min != null && max != null && min != max) {
      return '${_num(min)} - ${_num(max)}$suffix';
    }
    return '${_num((min ?? max)!)}$suffix';
  }

  /// Khoá nội bộ phục vụ kiểm tra dữ liệu, không hiển thị cho khách hàng.
  static const _hiddenKeys = {
    'needs_verification',
    'compressed_air_consumption_source_unit',
  };

  static const _labels = <String, String>{
    'blower_motor_kw': 'Động cơ quạt hút',
    'discharge_motor_kw': 'Động cơ xả liệu',
    'discharge_motor_kw_': 'Động cơ xả liệu',
    'feed_motor_kw': 'Động cơ cấp liệu',
    'classifier_speed_rpm': 'Tốc độ bộ phân cấp',
    'classifier_motor_kw': 'Động cơ bộ phân cấp',
    'roller_length_mm': 'Chiều dài trục cán',
    'roller_diameter_mm': 'Đường kính trục cán',
    'roller_count': 'Số trục cán',
    'pressure_mpa_': 'Áp suất làm việc',
    'electrical_consumption_kw': 'Điện năng tiêu thụ',
    'compressed_air_consumption_source_value': 'Lượng khí nén tiêu thụ',
    'door_motor_kw_': 'Động cơ cửa',
    'chamber_motor_kw_': 'Động cơ buồng nghiền',
    'temperature_c_': 'Nhiệt độ làm việc',
    'performance_note': 'Lưu ý hiệu suất',
    'loading_unloading': 'Nạp / xả liệu',
    'grinding_chamber_mm': 'Kích thước buồng nghiền',
    'cooling_medium': 'Môi chất làm lạnh',
    'chamber_diameter_mm': 'Đường kính buồng nghiền',
  };

  static List<GrindingSpecItem> _buildExtraRows(List<GrindingExtraSpec> specs) {
    final byKey = {for (final s in specs) s.specKey: s};
    final rows = <GrindingSpecItem>[];
    final consumed = <String>{};

    for (final spec in specs) {
      final key = spec.specKey;
      if (_hiddenKeys.contains(key) || consumed.contains(key)) continue;

      // Gộp cặp "<base>_min" + "<base>_max" thành 1 dòng khoảng giá trị.
      String labelKey = key;
      String? value;
      if (key.endsWith('_min') || key.endsWith('_max')) {
        final base = key.substring(0, key.length - 3);
        final min = byKey['${base}min'];
        final max = byKey['${base}max'];
        consumed
          ..add('${base}min')
          ..add('${base}max');
        labelKey = base;
        value = _pairValue(min, max);
      } else {
        value = spec.displayValue;
      }
      if (value == null || value.trim().isEmpty) continue;
      // Đơn vị "count" (số lượng) trong database: chỉ hiện con số.
      value = value.replaceFirst(RegExp(r'\s*count$'), '');

      final (icon, color) = _style(labelKey);
      rows.add(
        GrindingSpecItem(
          label: _labels[labelKey] ?? _humanize(labelKey),
          value: value,
          icon: icon,
          color: color,
        ),
      );
    }
    return rows;
  }

  static String? _pairValue(GrindingExtraSpec? min, GrindingExtraSpec? max) {
    final a = min?.specValueNumber;
    final b = max?.specValueNumber;
    final unit = (min?.unit ?? max?.unit ?? '').trim();
    if (a == null && b == null) {
      return min?.displayValue ?? max?.displayValue;
    }
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (a != null && b != null && a != b) {
      return '${_num(a)} - ${_num(b)}$suffix';
    }
    return '${_num((a ?? b)!)}$suffix';
  }

  static (IconData, Color) _style(String key) {
    if (key.contains('temperature')) return (Icons.thermostat, hotColor);
    if (key.contains('cooling')) return (Icons.ac_unit, airColor);
    if (key.contains('pressure')) return (Icons.compress, airColor);
    if (key.contains('compressed_air')) return (Icons.air, airColor);
    if (key.contains('speed') || key.contains('rpm')) {
      return (Icons.autorenew_rounded, structureColor);
    }
    if (key.contains('motor') || key.contains('_kw') || key.endsWith('kw_')) {
      return (Icons.electrical_services, electricColor);
    }
    if (key.contains('count')) return (Icons.numbers, structureColor);
    if (key.contains('_mm')) return (Icons.straighten, sizeColor);
    if (key.contains('loading')) return (Icons.swap_vert, weightColor);
    return (Icons.info_outline, neutralColor);
  }

  static String _humanize(String key) {
    final text = key.replaceAll('_', ' ').trim();
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
