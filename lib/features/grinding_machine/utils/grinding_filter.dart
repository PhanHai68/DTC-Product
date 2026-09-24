import '../models/grinding_machine.dart';
import 'grinding_fineness_converter.dart';

/// Khoảng công suất để lọc nhanh (mục 6 "Capacity") — đây là các mốc phân
/// loại UI, KHÔNG phải thông số của model nào, nên hard-code hợp lý (khác
/// với việc bịa thông số kỹ thuật của máy).
enum GrindingCapacityBucket {
  under100(null, 100, '< 100 kg/h'),
  r100to300(100, 300, '100 - 300 kg/h'),
  r300to500(300, 500, '300 - 500 kg/h'),
  r500to1000(500, 1000, '500 - 1000 kg/h'),
  over1000(1000, null, '> 1000 kg/h');

  const GrindingCapacityBucket(this.min, this.max, this.label);
  final double? min;
  final double? max;
  final String label;
}

/// Điều kiện lọc hiện tại — tất cả field null nghĩa là không áp dụng điều
/// kiện đó.
class GrindingFilterCriteria {
  const GrindingFilterCriteria({
    this.materialId,
    this.capacityBucket,
    this.finenessUnit,
    this.finenessValue,
  });

  final String? materialId;
  final GrindingCapacityBucket? capacityBucket;

  /// 'mm' | 'mesh' | 'µm' — phải đi kèm [finenessValue].
  final String? finenessUnit;
  final double? finenessValue;

  bool get isEmpty =>
      materialId == null && capacityBucket == null && finenessValue == null;

  GrindingFilterCriteria copyWith({
    String? materialId,
    bool clearMaterialId = false,
    GrindingCapacityBucket? capacityBucket,
    bool clearCapacityBucket = false,
    String? finenessUnit,
    double? finenessValue,
    bool clearFineness = false,
  }) {
    return GrindingFilterCriteria(
      materialId: clearMaterialId ? null : (materialId ?? this.materialId),
      capacityBucket: clearCapacityBucket
          ? null
          : (capacityBucket ?? this.capacityBucket),
      finenessUnit: clearFineness ? null : (finenessUnit ?? this.finenessUnit),
      finenessValue: clearFineness
          ? null
          : (finenessValue ?? this.finenessValue),
    );
  }
}

/// Áp điều kiện lọc lên danh sách model — thuần Dart, không đụng database
/// (danh sách máy nghiền chỉ ~60 dòng nên lọc trong bộ nhớ là đủ nhanh và
/// dễ test hơn build SQL WHERE động).
abstract final class GrindingFilterEngine {
  static List<GrindingMachine> apply(
    List<GrindingMachine> machines,
    GrindingFilterCriteria criteria, {
    /// Danh sách seriesCode tương thích nguyên liệu đã chọn (Verified) —
    /// truyền sẵn từ Provider vì cần query Material_Series_Map bất đồng bộ.
    Set<String>? compatibleSeriesCodes,
  }) {
    return machines.where((machine) {
      if (criteria.materialId != null) {
        if (compatibleSeriesCodes == null ||
            !compatibleSeriesCodes.contains(machine.seriesCode)) {
          return false;
        }
      }
      if (criteria.capacityBucket != null &&
          !_matchesCapacity(machine, criteria.capacityBucket!)) {
        return false;
      }
      if (criteria.finenessValue != null && criteria.finenessUnit != null) {
        if (!_matchesFineness(
          machine,
          criteria.finenessUnit!,
          criteria.finenessValue!,
        )) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  static bool _matchesCapacity(
    GrindingMachine machine,
    GrindingCapacityBucket bucket,
  ) {
    final min = machine.capacityMinKgH;
    final max = machine.capacityMaxKgH;
    if (min == null || max == null) return false;
    final bucketMin = bucket.min ?? double.negativeInfinity;
    final bucketMax = bucket.max ?? double.infinity;
    // Khớp nếu 2 khoảng [min,max] và [bucketMin,bucketMax] giao nhau.
    return min <= bucketMax && max >= bucketMin;
  }

  static bool _matchesFineness(
    GrindingMachine machine,
    String queryUnit,
    double queryValue,
  ) {
    final unit = machine.finenessUnit;
    final min = machine.finenessMin;
    final max = machine.finenessMax;
    if (unit == null || min == null || max == null) return false;

    if (unit == queryUnit) {
      return queryValue >= min && queryValue <= max;
    }
    // Chỉ quy đổi qua lại giữa mesh <-> µm (cùng bản chất phân loại hạt
    // mịn); đơn vị "mm" (nghiền thô) không quy đổi chéo.
    if (unit == 'mesh' && queryUnit == 'µm') {
      final meshValue = GrindingFinenessConverter.micronToMesh(queryValue);
      return meshValue >= min && meshValue <= max;
    }
    if (unit == 'µm' && queryUnit == 'mesh') {
      final micronValue = GrindingFinenessConverter.meshToMicron(queryValue);
      return micronValue >= min && micronValue <= max;
    }
    return false;
  }
}
