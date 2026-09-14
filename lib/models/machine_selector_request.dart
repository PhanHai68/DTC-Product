/// Model đại diện cho yêu cầu chọn máy của người dùng
/// Dùng trong Machine Selector screen
library;

class MachineSelectorRequest {
  final String? bagMaterial; // PE / PP / null (tất cả)
  final String? bagEdges; // 2 cạnh / 6 cạnh / 2 & 6 cạnh / null
  final String? automationLevel; // Bán tự động / Hoàn toàn tự động / null
  final double? requestedWeightKg; // Khối lượng mỗi túi (kg)
  final double? requestedCapacity; // Năng suất yêu cầu
  final String? capacityUnit; // túi/giờ / tấn/giờ

  const MachineSelectorRequest({
    this.bagMaterial,
    this.bagEdges,
    this.automationLevel,
    this.requestedWeightKg,
    this.requestedCapacity,
    this.capacityUnit,
  });

  /// Có ít nhất một tiêu chí để lọc không?
  bool get hasAnyFilter =>
      bagMaterial != null ||
      bagEdges != null ||
      automationLevel != null ||
      requestedWeightKg != null ||
      requestedCapacity != null;

  MachineSelectorRequest copyWith({
    String? bagMaterial,
    String? bagEdges,
    String? automationLevel,
    double? requestedWeightKg,
    double? requestedCapacity,
    String? capacityUnit,
    bool clearBagMaterial = false,
    bool clearBagEdges = false,
    bool clearAutomationLevel = false,
    bool clearWeight = false,
    bool clearCapacity = false,
  }) {
    return MachineSelectorRequest(
      bagMaterial: clearBagMaterial ? null : (bagMaterial ?? this.bagMaterial),
      bagEdges: clearBagEdges ? null : (bagEdges ?? this.bagEdges),
      automationLevel: clearAutomationLevel
          ? null
          : (automationLevel ?? this.automationLevel),
      requestedWeightKg: clearWeight
          ? null
          : (requestedWeightKg ?? this.requestedWeightKg),
      requestedCapacity: clearCapacity
          ? null
          : (requestedCapacity ?? this.requestedCapacity),
      capacityUnit: capacityUnit ?? this.capacityUnit,
    );
  }
}
