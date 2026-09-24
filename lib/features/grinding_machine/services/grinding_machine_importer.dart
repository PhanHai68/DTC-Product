import 'dart:convert';

import '../models/grinding_ai_config.dart';
import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_material_series_map.dart';
import '../models/grinding_selection_tag.dart';
import '../models/grinding_series.dart';
import '../repositories/grinding_machine_repository.dart';

/// Parse dữ liệu database Máy nghiền từ JSON (đã convert 1 lần từ
/// DTC_Grinding_Machine_Database_AI_Ready.xlsx) thành [GrindingDatabaseSnapshot]
/// để `GrindingMachineRepository.importSnapshot` nạp vào SQLite.
///
/// Chỉ nhận input dạng JSON string (không tự đọc `rootBundle`/file) để có
/// thể unit test thuần Dart, không cần Flutter binding.
abstract final class GrindingMachineImporter {
  static GrindingDatabaseSnapshot parse(String jsonSource) {
    final root = jsonDecode(jsonSource) as Map<String, dynamic>;

    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = root[key] as List<dynamic>? ?? const [];
      return raw
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return GrindingDatabaseSnapshot(
      databaseVersion: root['databaseVersion'] as String? ?? '0',
      sourceDocument: root['sourceDocument'] as String?,
      series: listOf('series', GrindingSeries.fromJson),
      machines: listOf('models', GrindingMachine.fromJson),
      extraSpecs: listOf('extraSpecs', GrindingExtraSpec.fromJson),
      selectionTags: listOf('selectionTags', GrindingSelectionTag.fromJson),
      materials: listOf('materials', GrindingMaterial.fromJson),
      materialSeriesMap: listOf(
        'materialSeriesMap',
        GrindingMaterialSeriesMap.fromJson,
      ),
      aiConfig: listOf('aiConfig', GrindingAiConfig.fromJson),
    );
  }
}
