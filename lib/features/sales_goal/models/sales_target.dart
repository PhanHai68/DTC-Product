enum SalesTargetPeriod { month, quarter }

class SalesTarget {
  const SalesTarget({
    this.id,
    required this.period,
    required this.year,
    required this.periodNumber,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final SalesTargetPeriod period;
  final int year;
  final int periodNumber;
  final int amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'periodType': period.name,
    'year': year,
    'periodNumber': periodNumber,
    'targetAmount': amount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SalesTarget.fromMap(Map<String, Object?> map) => SalesTarget(
    id: map['id'] as int?,
    period: SalesTargetPeriod.values.firstWhere(
      (value) => value.name == map['periodType'],
    ),
    year: map['year'] as int,
    periodNumber: map['periodNumber'] as int,
    amount: map['targetAmount'] as int,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
