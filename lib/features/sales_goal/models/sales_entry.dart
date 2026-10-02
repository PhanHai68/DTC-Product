class SalesEntry {
  const SalesEntry({
    this.id,
    required this.saleDate,
    required this.amount,
    this.customerOrProject = '',
    this.productOrMachine = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final DateTime saleDate;
  final int amount;
  final String customerOrProject;
  final String productOrMachine;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesEntry copyWith({
    int? id,
    DateTime? saleDate,
    int? amount,
    String? customerOrProject,
    String? productOrMachine,
    String? notes,
    DateTime? updatedAt,
  }) => SalesEntry(
    id: id ?? this.id,
    saleDate: saleDate ?? this.saleDate,
    amount: amount ?? this.amount,
    customerOrProject: customerOrProject ?? this.customerOrProject,
    productOrMachine: productOrMachine ?? this.productOrMachine,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'saleDate': _dateOnly(saleDate),
    'amount': amount,
    'customerOrProject': customerOrProject,
    'productOrMachine': productOrMachine,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SalesEntry.fromMap(Map<String, Object?> map) => SalesEntry(
    id: map['id'] as int?,
    saleDate: DateTime.parse(map['saleDate'] as String),
    amount: map['amount'] as int,
    customerOrProject: map['customerOrProject'] as String? ?? '',
    productOrMachine: map['productOrMachine'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
