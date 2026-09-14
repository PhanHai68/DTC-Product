enum SampleStreamType { rawMaterial, accepted, rejected }

extension SampleStreamTypeInfo on SampleStreamType {
  String get title => switch (this) {
    SampleStreamType.rawMaterial => 'Nguyên liệu đầu vào',
    SampleStreamType.accepted => 'Thành phẩm',
    SampleStreamType.rejected => 'Phế phẩm',
  };

  String get englishTitle => switch (this) {
    SampleStreamType.rawMaterial => 'Raw material',
    SampleStreamType.accepted => 'Accept',
    SampleStreamType.rejected => 'Reject',
  };
}

const sampleDefectLabels = <String>[
  '',
  '',
  '',
  '',
  '',
];

const sampleDefectEnglishLabels = <String>[
  '',
  '',
  '',
  '',
  '',
];

class SampleParameterItem {
  final String name;
  final double weightGram;
  final String? photoPath;

  const SampleParameterItem({
    required this.name,
    this.weightGram = 0,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'weightGram': weightGram,
    'photoPath': photoPath,
  };

  factory SampleParameterItem.fromJson(Map<String, dynamic> json) {
    return SampleParameterItem(
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      weightGram: (json['weightGram'] as num?)?.toDouble() ?? 0,
      photoPath: json['photoPath'] as String?,
    );
  }
}

List<SampleParameterItem> defaultSampleParameters(SampleStreamType type) =>
    const [
      SampleParameterItem(name: ''),
      SampleParameterItem(name: ''),
      SampleParameterItem(name: ''),
    ];

class SampleCategoryImageData {
  final String label;
  final String? photoPath;

  const SampleCategoryImageData({required this.label, this.photoPath});

  Map<String, dynamic> toJson() => {'label': label, 'photoPath': photoPath};

  factory SampleCategoryImageData.fromJson(Map<String, dynamic> json) {
    return SampleCategoryImageData(
      label: json['label'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
    );
  }
}

List<SampleCategoryImageData> defaultSampleCategoryImages(
  SampleStreamType type,
) => const [
    SampleCategoryImageData(label: ''),
    SampleCategoryImageData(label: ''),
    SampleCategoryImageData(label: ''),
  ];

double parseSampleNumber(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

class SampleStreamData {
  final SampleStreamType type;
  final double measuredWeightKg;
  final int minutes;
  final int seconds;
  final double sampleWeightGram;
  final List<String> defectLabels;
  final List<double> defectWeightsGram;
  final String? photoPath;
  final List<SampleCategoryImageData> categoryImages;
  final List<SampleParameterItem> items;

  const SampleStreamData({
    required this.type,
    this.measuredWeightKg = 0,
    this.minutes = 0,
    this.seconds = 0,
    this.sampleWeightGram = 0,
    this.defectLabels = sampleDefectLabels,
    this.defectWeightsGram = const [0, 0, 0, 0, 0],
    this.photoPath,
    this.categoryImages = const [],
    this.items = const [],
  });

  int get totalSeconds => minutes * 60 + seconds;

  double get capacityTonPerHour =>
      totalSeconds <= 0 ? 0 : (measuredWeightKg / totalSeconds) * 3.6;

  List<SampleParameterItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    final res = <SampleParameterItem>[];
    for (var i = 0; i < defectLabels.length; i++) {
      final label = defectLabels[i];
      final weight = i < defectWeightsGram.length ? defectWeightsGram[i] : 0.0;
      final photo = i < categoryImages.length ? categoryImages[i].photoPath : null;
      res.add(SampleParameterItem(name: label, weightGram: weight, photoPath: photo));
    }
    return res.isEmpty ? defaultSampleParameters(type) : res;
  }

  double get totalDefectWeight {
    if (items.isNotEmpty) {
      if (type == SampleStreamType.rejected) {
        return items.isNotEmpty ? items.first.weightGram : 0;
      }
      return items.where((item) => !item.name.toLowerCase().contains('tốt') && !item.name.toLowerCase().contains('đạt')).fold(0.0, (a, b) => a + b.weightGram);
    }
    return defectWeightsGram.fold(0, (a, b) => a + b);
  }

  double get defectPercentage =>
      sampleWeightGram <= 0 ? 0 : totalDefectWeight / sampleWeightGram * 100;

  double get goodPercentage {
    if (sampleWeightGram <= 0) return 0;
    if (items.isNotEmpty) {
      final goodItems = items.where((item) => item.name.toLowerCase().contains('tốt') || item.name.toLowerCase().contains('đạt'));
      if (goodItems.isNotEmpty) {
        return (goodItems.fold<double>(0, (a, b) => a + b.weightGram) / sampleWeightGram * 100).clamp(0, 100);
      }
    }
    return (100 - defectPercentage).clamp(0, 100);
  }

  bool get hasValidProductivity =>
      measuredWeightKg > 0 && totalSeconds > 0 && seconds >= 0 && seconds < 60;

  bool get hasValidAnalysis {
    if (sampleWeightGram <= 0) return false;
    final effective = effectiveItems;
    if (effective.any((item) => item.weightGram < 0)) return false;
    final totalW = effective.fold<double>(0, (a, b) => a + b.weightGram);
    return totalW <= sampleWeightGram * 1.001;
  }

  bool get hasAllCategoryPhotos {
    if (categoryImages.isNotEmpty) {
      return categoryImages
          .where((image) => image.label.trim().isNotEmpty)
          .every((image) => (image.photoPath ?? '').isNotEmpty);
    }
    final effective = effectiveItems;
    final active = effective.where((image) => image.name.trim().isNotEmpty);
    if (active.isEmpty) return true;
    return active.every((image) => (image.photoPath ?? '').isNotEmpty);
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'measuredWeightKg': measuredWeightKg,
    'minutes': minutes,
    'seconds': seconds,
    'sampleWeightGram': sampleWeightGram,
    'defectLabels': defectLabels.isNotEmpty
        ? defectLabels
        : effectiveItems.map((e) => e.name).toList(),
    'defectWeightsGram': defectWeightsGram.isNotEmpty
        ? defectWeightsGram
        : effectiveItems.map((e) => e.weightGram).toList(),
    'photoPath': photoPath,
    'categoryImages':
        (categoryImages.isNotEmpty
                ? categoryImages
                : effectiveItems.map(
                    (e) => SampleCategoryImageData(
                      label: e.name,
                      photoPath: e.photoPath,
                    ),
                  ))
            .map((e) => e.toJson())
            .toList(),
    'items': effectiveItems.map((e) => e.toJson()).toList(),
  };

  factory SampleStreamData.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = SampleStreamType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SampleStreamType.rawMaterial,
    );
    final itemsJson = (json['items'] as List?)
        ?.whereType<Map>()
        .map(
          (value) =>
              SampleParameterItem.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList();
    final categoryJson = (json['categoryImages'] as List?)
        ?.whereType<Map>()
        .map(
          (value) => SampleCategoryImageData.fromJson(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList();
    final labels =
        (json['defectLabels'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        sampleDefectLabels;
    final weights =
        (json['defectWeightsGram'] as List?)
            ?.map((value) => (value as num).toDouble())
            .toList() ??
        const [0, 0, 0, 0, 0];

    final parsedItems =
        itemsJson ??
        (labels.isNotEmpty
            ? List.generate(labels.length, (i) {
                final name = labels[i];
                final weight = i < weights.length ? weights[i] : 0.0;
                final photo = categoryJson != null && i < categoryJson.length
                    ? categoryJson[i].photoPath
                    : null;
                return SampleParameterItem(
                  name: name,
                  weightGram: weight,
                  photoPath: photo,
                );
              })
            : defaultSampleParameters(type));

    return SampleStreamData(
      type: type,
      measuredWeightKg: (json['measuredWeightKg'] as num?)?.toDouble() ?? 0,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      sampleWeightGram: (json['sampleWeightGram'] as num?)?.toDouble() ?? 0,
      defectLabels: labels,
      defectWeightsGram: weights,
      photoPath: json['photoPath'] as String?,
      categoryImages:
          categoryJson ??
          parsedItems
              .map(
                (e) => SampleCategoryImageData(
                  label: e.name,
                  photoPath: e.photoPath,
                ),
              )
              .toList(),
      items: parsedItems,
    );
  }
}

class SampleRecordData {
  final String factoryName;
  final String materialName;
  final String tagName;
  final String machineOperator;
  final String preparedBy;
  final DateTime createdAt;
  final List<SampleStreamData> streams;
  final String conclusion;
  final String note;

  const SampleRecordData({
    this.factoryName = '',
    this.materialName = 'Gạo',
    this.tagName = '',
    this.machineOperator = '',
    this.preparedBy = '',
    required this.createdAt,
    this.streams = const [],
    this.conclusion = '',
    this.note = '',
  });

  bool get hasAllPhotos =>
      streams.length == SampleStreamType.values.length &&
      streams.every(
        (stream) =>
            (stream.photoPath ?? '').isNotEmpty && stream.hasAllCategoryPhotos,
      );

  bool get isComplete =>
      factoryName.trim().isNotEmpty &&
      materialName.trim().isNotEmpty &&
      tagName.trim().isNotEmpty &&
      machineOperator.trim().isNotEmpty &&
      preparedBy.trim().isNotEmpty &&
      conclusion.trim().isNotEmpty &&
      streams.length == SampleStreamType.values.length &&
      streams.every(
        (stream) => stream.hasValidProductivity && stream.hasValidAnalysis,
      ) &&
      hasAllPhotos;

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'materialName': materialName,
    'tagName': tagName,
    'machineOperator': machineOperator,
    'preparedBy': preparedBy,
    'createdAt': createdAt.toIso8601String(),
    'streams': streams.map((stream) => stream.toJson()).toList(),
    'conclusion': conclusion,
    'note': note,
  };

  factory SampleRecordData.fromJson(Map<String, dynamic> json) {
    return SampleRecordData(
      factoryName: json['factoryName'] as String? ?? '',
      materialName: json['materialName'] as String? ?? 'Gạo',
      tagName: json['tagName'] as String? ?? '',
      machineOperator: json['machineOperator'] as String? ?? '',
      preparedBy: json['preparedBy'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      streams:
          (json['streams'] as List?)
              ?.whereType<Map>()
              .map(
                (value) =>
                    SampleStreamData.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList() ??
          const [],
      conclusion: json['conclusion'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}
