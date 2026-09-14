/// Model Dart đại diện cho một máy cân đóng gói.
/// Ánh xạ trực tiếp từ bảng packing_machines trong SQLite database.

class PackingMachine {
  final int id;
  final int? stt;
  final String? productGroup; // Nhóm sản phẩm: Túi PE, Bao PP, Định lượng
  final String? machineLine; // Dòng máy: Máy trộn gạo, Cân lưu lượng...
  final String model; // Ví dụ: LZB-600-R10
  final String? automationLevel; // Bán tự động / Hoàn toàn tự động / Tự động
  final String? automationOriginal; // Mô tả gốc đầy đủ
  final String? bagMaterial; // PE / PP
  final String? bagEdges; // 2 cạnh / 6 cạnh / 2 & 6 cạnh
  final String? bagShape; // Túi phẳng / Túi vuông
  final String? materials; // Nguyên liệu phù hợp
  final String? headsStations; // Số đầu cân / trạm (dạng text vì có '-')
  final double? weightMinKg;
  final double? weightMaxKg;
  final String? weightUnit; // kg / tấn
  final double? capacityMin;
  final double? capacityMax;
  final String? capacityUnit; // túi/giờ / tấn / tấn/giờ
  final String? powerSystem; // AC / 4N-AC
  final double? voltageV;
  final double? frequencyHz;
  final double? powerKw;
  final double? airPressureMinMpa;
  final double? airPressureMaxMpa;
  final double? airConsumptionM3h;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final String? notes; // Ghi chú
  final String? sourceCatalog; // Tên file catalog PDF
  final String? imageFile; // Tên file ảnh
  final String? imageMainPath; // Đường dẫn asset ảnh chính
  final String? image2Path; // Đường dẫn asset ảnh thứ 2
  final String? imageBagPath; // Đường dẫn asset ảnh túi
  final String? diagramImagePath; // Đường dẫn sơ đồ
  final String? catalogAssetPath; // Đường dẫn asset PDF catalog
  final int? catalogPage; // Trang cụ thể trong catalog

  const PackingMachine({
    required this.id,
    this.stt,
    this.productGroup,
    this.machineLine,
    required this.model,
    this.automationLevel,
    this.automationOriginal,
    this.bagMaterial,
    this.bagEdges,
    this.bagShape,
    this.materials,
    this.headsStations,
    this.weightMinKg,
    this.weightMaxKg,
    this.weightUnit,
    this.capacityMin,
    this.capacityMax,
    this.capacityUnit,
    this.powerSystem,
    this.voltageV,
    this.frequencyHz,
    this.powerKw,
    this.airPressureMinMpa,
    this.airPressureMaxMpa,
    this.airConsumptionM3h,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.notes,
    this.sourceCatalog,
    this.imageFile,
    this.imageMainPath,
    this.image2Path,
    this.imageBagPath,
    this.diagramImagePath,
    this.catalogAssetPath,
    this.catalogPage,
  });

  /// Tạo PackingMachine từ Map (kết quả từ SQLite query)
  factory PackingMachine.fromMap(Map<String, dynamic> map) {
    return PackingMachine(
      id: (map['id'] as num?)?.toInt() ?? 0,
      stt: (map['stt'] as num?)?.toInt(),
      productGroup: map['product_group'] as String?,
      machineLine: map['machine_line'] as String?,
      model: map['model'] as String? ?? '',
      automationLevel: map['automation_level'] as String?,
      automationOriginal: map['automation_original'] as String?,
      bagMaterial: map['bag_material'] as String?,
      bagEdges: map['bag_edges'] as String?,
      bagShape: map['bag_shape'] as String?,
      materials: map['materials'] as String?,
      headsStations: map['heads_stations'] as String?,
      weightMinKg: (map['weight_min_kg'] as num?)?.toDouble(),
      weightMaxKg: (map['weight_max_kg'] as num?)?.toDouble(),
      weightUnit: map['weight_unit'] as String?,
      capacityMin: (map['capacity_min'] as num?)?.toDouble(),
      capacityMax: (map['capacity_max'] as num?)?.toDouble(),
      capacityUnit: map['capacity_unit'] as String?,
      powerSystem: map['power_system'] as String?,
      voltageV: (map['voltage_v'] as num?)?.toDouble(),
      frequencyHz: (map['frequency_hz'] as num?)?.toDouble(),
      powerKw: (map['power_kw'] as num?)?.toDouble(),
      airPressureMinMpa: (map['air_pressure_min_mpa'] as num?)?.toDouble(),
      airPressureMaxMpa: (map['air_pressure_max_mpa'] as num?)?.toDouble(),
      airConsumptionM3h: (map['air_consumption_m3h'] as num?)?.toDouble(),
      lengthMm: (map['length_mm'] as num?)?.toDouble(),
      widthMm: (map['width_mm'] as num?)?.toDouble(),
      heightMm: (map['height_mm'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      sourceCatalog: map['source_catalog'] as String?,
      imageFile: map['image_file'] as String?,
      imageMainPath: map['image_main_path'] as String?,
      image2Path: map['image_2_path'] as String?,
      imageBagPath: map['image_bag_path'] as String?,
      diagramImagePath: map['diagram_image_path'] as String?,
      catalogAssetPath: map['catalog_asset_path'] as String?,
      catalogPage: (map['catalog_page'] as num?)?.toInt(),
    );
  }

  // ─── Computed Getters ───────────────────────────────────────────────────────

  /// Dải trọng lượng dạng text: "0.35 - 5 kg"
  String get weightRangeText {
    final unit = weightUnit ?? 'kg';
    if (weightMinKg != null && weightMaxKg != null) {
      final min = _formatNum(weightMinKg!);
      final max = _formatNum(weightMaxKg!);
      return '$min - $max $unit';
    } else if (weightMaxKg != null) {
      return '≤ ${_formatNum(weightMaxKg!)} $unit';
    }
    return 'N/A';
  }

  /// Dải năng suất dạng text: "540 - 600 túi/giờ"
  String get capacityRangeText {
    final unit = capacityUnit ?? '';
    if (capacityMin != null && capacityMax != null) {
      final min = _formatNum(capacityMin!);
      final max = _formatNum(capacityMax!);
      return '$min - $max $unit';
    } else if (capacityMax != null) {
      return '≤ ${_formatNum(capacityMax!)} $unit';
    }
    return 'N/A';
  }

  /// Kích thước dạng text: "1200 × 800 × 1600 mm"
  String get dimensionText {
    if (lengthMm != null && widthMm != null && heightMm != null) {
      return '${_formatNum(lengthMm!)} × ${_formatNum(widthMm!)} × ${_formatNum(heightMm!)} mm';
    }
    return 'N/A';
  }

  /// Nguồn điện dạng text: "AC 220V / 50Hz"
  String get powerText {
    final parts = <String>[];
    if (powerSystem != null) parts.add(powerSystem!);
    if (voltageV != null) parts.add('${_formatNum(voltageV!)}V');
    if (frequencyHz != null) parts.add('${_formatNum(frequencyHz!)}Hz');
    return parts.isEmpty ? 'N/A' : parts.join(' / ');
  }

  /// Áp suất khí nén dạng text: "0.4 - 0.6 MPa"
  String get airPressureText {
    if (airPressureMinMpa != null && airPressureMaxMpa != null) {
      return '${airPressureMinMpa!} - ${airPressureMaxMpa!} MPa';
    }
    return 'N/A';
  }

  /// Danh sách các đường dẫn ảnh (không null, không rỗng)
  List<String> get allImagePaths {
    return [
      imageMainPath,
      image2Path,
      imageBagPath,
      diagramImagePath,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  /// Ảnh dùng ở trang chi tiết: ưu tiên ảnh nền ngang, sau đó mới tới icon.
  ///
  /// `imageMainPath` vẫn là icon đại diện ở danh sách model. Tách thứ tự này
  /// giúp trang chi tiết không còn mở đầu bằng ảnh vuông bị phóng lớn.
  List<String> get detailImagePaths {
    return [
      image2Path,
      imageMainPath,
      imageBagPath,
      diagramImagePath,
    ].whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
  }

  /// Có ảnh chính hay không
  bool get hasMainImage => imageMainPath != null && imageMainPath!.isNotEmpty;

  /// Có catalog hay không
  bool get hasCatalog =>
      catalogAssetPath != null && catalogAssetPath!.isNotEmpty;

  // ─── Helper ────────────────────────────────────────────────────────────────

  /// Format số: bỏ .0 nếu là số nguyên
  static String _formatNum(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  String toString() => 'PackingMachine(model: $model, group: $productGroup)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackingMachine &&
          runtimeType == other.runtimeType &&
          model == other.model;

  @override
  int get hashCode => model.hashCode;
}
