enum SalesOpportunityStatus {
  tracking('Đang theo dõi'),
  negotiating('Đang đàm phán'),
  won('Đã thắng'),
  lost('Đã mất');

  const SalesOpportunityStatus(this.label);
  final String label;

  bool get isOpen =>
      this == SalesOpportunityStatus.tracking ||
      this == SalesOpportunityStatus.negotiating;
}

class SalesOpportunity {
  const SalesOpportunity({
    this.id,
    required this.customerOrProject,
    this.productOrMachine = '',
    required this.estimatedValue,
    required this.probability,
    required this.expectedCloseDate,
    this.notes = '',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String customerOrProject;
  final String productOrMachine;
  final int estimatedValue;
  final int probability;
  final DateTime expectedCloseDate;
  final String notes;
  final SalesOpportunityStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesOpportunity copyWith({
    int? id,
    String? customerOrProject,
    String? productOrMachine,
    int? estimatedValue,
    int? probability,
    DateTime? expectedCloseDate,
    String? notes,
    SalesOpportunityStatus? status,
    DateTime? updatedAt,
  }) => SalesOpportunity(
    id: id ?? this.id,
    customerOrProject: customerOrProject ?? this.customerOrProject,
    productOrMachine: productOrMachine ?? this.productOrMachine,
    estimatedValue: estimatedValue ?? this.estimatedValue,
    probability: probability ?? this.probability,
    expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'customerOrProject': customerOrProject,
    'productOrMachine': productOrMachine,
    'estimatedValue': estimatedValue,
    'probability': probability,
    'expectedCloseDate': _dateOnly(expectedCloseDate),
    'notes': notes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SalesOpportunity.fromMap(Map<String, Object?> map) =>
      SalesOpportunity(
        id: map['id'] as int?,
        customerOrProject: map['customerOrProject'] as String,
        productOrMachine: map['productOrMachine'] as String? ?? '',
        estimatedValue: map['estimatedValue'] as int,
        probability: map['probability'] as int,
        expectedCloseDate: DateTime.parse(map['expectedCloseDate'] as String),
        notes: map['notes'] as String? ?? '',
        status: SalesOpportunityStatus.values.firstWhere(
          (value) => value.name == map['status'],
        ),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
