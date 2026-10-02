import '../utils/maps_link.dart';

class FactoryLocation {
  const FactoryLocation({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final double latitude;
  final double longitude;

  /// Bán kính sai số (mét); null khi tọa độ lấy từ link dán thủ công.
  final double? accuracy;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get mapsUrl => buildMapsUrl(latitude, longitude);

  String get shareText => [
    name,
    if (note.trim().isNotEmpty) 'Ghi chú: ${note.trim()}',
    mapsUrl,
  ].join('\n');

  FactoryLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool clearAccuracy = false,
    String? note,
    DateTime? updatedAt,
  }) => FactoryLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracy: clearAccuracy ? null : accuracy ?? this.accuracy,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FactoryLocation.fromMap(Map<String, Object?> map) => FactoryLocation(
    id: map['id'] as int?,
    name: map['name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    accuracy: (map['accuracy'] as num?)?.toDouble(),
    note: map['note'] as String? ?? '',
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
