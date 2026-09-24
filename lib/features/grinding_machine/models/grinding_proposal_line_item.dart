/// Loại dòng chi phí trong Proposal — accessory (phụ kiện/option) hoặc
/// additional cost (Shipping/Installation/Training/Other, tính trước VAT
/// theo công thức Phase 8).
enum GrindingProposalLineItemKind {
  accessory,
  additionalCost;

  String get value => switch (this) {
    GrindingProposalLineItemKind.accessory => 'accessory',
    GrindingProposalLineItemKind.additionalCost => 'additional_cost',
  };

  static GrindingProposalLineItemKind fromValue(String? value) =>
      value == 'additional_cost'
      ? GrindingProposalLineItemKind.additionalCost
      : GrindingProposalLineItemKind.accessory;
}

/// 1 dòng Accessory/Additional Cost trong Proposal — [quantity]/[unitPrice]
/// `null` nghĩa là CHƯA CÓ GIÁ, không được suy đoán/mặc định 0.
class GrindingProposalLineItem {
  const GrindingProposalLineItem({
    this.id,
    this.proposalId,
    required this.kind,
    required this.name,
    this.quantity,
    this.unitPrice,
    this.note,
    this.sortOrder = 0,
  });

  final int? id;
  final int? proposalId;
  final GrindingProposalLineItemKind kind;
  final String name;
  final double? quantity;
  final double? unitPrice;
  final String? note;
  final int sortOrder;

  /// `null` nếu thiếu quantity HOẶC unitPrice — KHÔNG coi là 0 khi cộng tổng
  /// (xem GrindingProposalCalculator).
  double? get lineTotal =>
      (quantity == null || unitPrice == null) ? null : quantity! * unitPrice!;

  GrindingProposalLineItem copyWith({
    int? id,
    int? proposalId,
    GrindingProposalLineItemKind? kind,
    String? name,
    double? quantity,
    bool clearQuantity = false,
    double? unitPrice,
    bool clearUnitPrice = false,
    String? note,
    bool clearNote = false,
    int? sortOrder,
  }) {
    return GrindingProposalLineItem(
      id: id ?? this.id,
      proposalId: proposalId ?? this.proposalId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unitPrice: clearUnitPrice ? null : (unitPrice ?? this.unitPrice),
      note: clearNote ? null : (note ?? this.note),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory GrindingProposalLineItem.fromRow(Map<String, Object?> row) =>
      GrindingProposalLineItem(
        id: row['id'] as int?,
        proposalId: row['proposalId'] as int?,
        kind: GrindingProposalLineItemKind.fromValue(row['kind'] as String?),
        name: row['name'] as String,
        quantity: (row['quantity'] as num?)?.toDouble(),
        unitPrice: (row['unitPrice'] as num?)?.toDouble(),
        note: row['note'] as String?,
        sortOrder: (row['sortOrder'] as int?) ?? 0,
      );

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    if (proposalId != null) 'proposalId': proposalId,
    'kind': kind.value,
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'note': note,
    'sortOrder': sortOrder,
  };
}
