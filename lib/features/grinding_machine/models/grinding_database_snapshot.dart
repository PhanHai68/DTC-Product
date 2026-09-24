import 'grinding_ai_config.dart';
import 'grinding_extra_spec.dart';
import 'grinding_machine.dart';
import 'grinding_material.dart';
import 'grinding_material_series_map.dart';
import 'grinding_selection_tag.dart';
import 'grinding_series.dart';

/// Một bản catalog đầy đủ, dùng chung cho seed, Excel và JSON.
class GrindingDatabaseSnapshot {
  final String databaseVersion;
  final String? sourceDocument;
  final List<GrindingSeries> series;
  final List<GrindingMachine> machines;
  final List<GrindingExtraSpec> extraSpecs;
  final List<GrindingSelectionTag> selectionTags;
  final List<GrindingMaterial> materials;
  final List<GrindingMaterialSeriesMap> materialSeriesMap;
  final List<GrindingAiConfig> aiConfig;

  const GrindingDatabaseSnapshot({
    required this.databaseVersion,
    this.sourceDocument,
    required this.series,
    required this.machines,
    required this.extraSpecs,
    required this.selectionTags,
    required this.materials,
    required this.materialSeriesMap,
    required this.aiConfig,
  });

  Map<String, dynamic> toJson() => {
    'databaseVersion': databaseVersion,
    'sourceDocument': sourceDocument,
    'series': series.map((v) => v.toJson()).toList(),
    'models': machines.map((v) => v.toJson()).toList(),
    'extraSpecs': extraSpecs.map((v) => v.toJson()).toList(),
    'selectionTags': selectionTags.map((v) => v.toJson()).toList(),
    'materials': materials.map((v) => v.toJson()).toList(),
    'materialSeriesMap': materialSeriesMap.map((v) => v.toJson()).toList(),
    'aiConfig': aiConfig
        .map(
          (v) => {
            'key': v.key,
            'value': v.value,
            'unit': v.unit,
            'category': v.category,
            'description': v.description,
            'editable': v.editable,
          },
        )
        .toList(),
  };
}
