/// 1 dòng vật tư/phụ tùng đã sử dụng (Parts Used / Spare Parts & Consumables).
class MaintenancePart {
  final String id;
  final String reportId;
  final String partName;
  final String partNumber;
  final double quantity;
  final String unit;
  final String note;
  final int orderIndex;

  const MaintenancePart({
    required this.id,
    required this.reportId,
    required this.partName,
    this.partNumber = '',
    this.quantity = 1,
    this.unit = 'pcs',
    this.note = '',
    this.orderIndex = 0,
  });

  factory MaintenancePart.fromJson(Map<String, dynamic> json) =>
      MaintenancePart(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        partName: json['partName'] as String? ?? '',
        partNumber: json['partNumber'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'pcs',
        note: json['note'] as String? ?? '',
        orderIndex: json['orderIndex'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'partName': partName,
    'partNumber': partNumber,
    'quantity': quantity,
    'unit': unit,
    'note': note,
    'orderIndex': orderIndex,
  };
}
