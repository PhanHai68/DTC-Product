/// 1 dòng máy trong danh mục của Ngân hàng lỗi (VD "SC16 Pro").
class FaultMachineModel {
  const FaultMachineModel({
    required this.id,
    required this.name,
    this.manufacturer,
    this.equipmentGroup,
  });

  /// `<mã kỹ sư>-<uuid>` — ổn định để gộp file của nhiều kỹ sư.
  final String id;
  final String name;

  /// Hãng sản xuất (tùy chọn).
  final String? manufacturer;

  /// Nhóm thiết bị, VD "Máy tách màu" (tùy chọn).
  final String? equipmentGroup;

  factory FaultMachineModel.fromMap(Map<String, Object?> map) =>
      FaultMachineModel(
        id: map['id'] as String,
        name: map['name'] as String,
        manufacturer: map['manufacturer'] as String?,
        equipmentGroup: map['equipment_group'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is FaultMachineModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
