import '../models/grinding_ai_config.dart';
import '../models/grinding_database_snapshot.dart';
import '../models/grinding_extra_spec.dart';
import '../models/grinding_import_report.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_material_series_map.dart';
import '../models/grinding_selection_tag.dart';
import '../models/grinding_series.dart';

/// Schema import, không chứa thông số kỹ thuật của bất kỳ model máy nào.
abstract final class GrindingImportSchema {
  static const sheets = {
    'series': 'Series',
    'models': 'Models',
    'extraSpecs': 'Extra_Specs',
    'selectionTags': 'Selection_Tags',
    'materials': 'Materials',
    'materialSeriesMap': 'Material_Series_Map',
    'aiConfig': 'AI_Config',
  };
  // id = text bắt buộc; integerId = khóa SQLite tùy chọn.
  static const fields = <String, Map<String, String>>{
    'series': {
      'seriesCode': 'id',
      'displayCode': 'text',
      'nameVi': 'text',
      'nameEn': 'text',
      'technology': 'text',
      'pdfPages': 'text',
      'applicationVi': 'text',
      'workingPrincipleVi': 'text',
      'notes': 'text',
    },
    'models': {
      'machineId': 'id',
      'seriesCode': 'id',
      'model': 'id',
      'active': 'requiredBool',
      'pdfPage': 'integer',
      'capacityMinKgH': 'number',
      'capacityMaxKgH': 'number',
      'inputSizeMaxMm': 'number',
      'inputSizeNote': 'text',
      'finenessMin': 'number',
      'finenessMax': 'number',
      'finenessUnit': 'text',
      'mainMotorKwMin': 'number',
      'mainMotorKwMax': 'number',
      'speedRpmMin': 'number',
      'speedRpmMax': 'number',
      'lengthMm': 'number',
      'widthMm': 'number',
      'heightMm': 'number',
      'weightKg': 'number',
      'sourceDocument': 'text',
      'editNote': 'text',
    },
    'extraSpecs': {
      'id': 'integerId',
      'machineId': 'id',
      'specKey': 'id',
      'specValueNumber': 'signedNumber',
      'specValueText': 'text',
      'unit': 'text',
      'sourcePdfPage': 'integer',
      'note': 'text',
    },
    'selectionTags': {
      'id': 'integerId',
      'seriesCode': 'id',
      'tag': 'id',
      'note': 'text',
    },
    'materials': {
      'materialId': 'id',
      'nameVi': 'id',
      'nameEn': 'text',
      'category': 'text',
      'hardness': 'text',
      'fibrous': 'bool',
      'oily': 'bool',
      'stickyOrPaste': 'bool',
      'wet': 'bool',
      'heatSensitive': 'bool',
      'brittle': 'bool',
      'crystalline': 'bool',
      'sourceCandidateSeries': 'text',
      'sourceBasis': 'text',
      'status': 'id',
      'notes': 'text',
    },
    'materialSeriesMap': {
      'id': 'integerId',
      'materialId': 'id',
      'seriesCode': 'id',
      'scoreAdjustment': 'requiredNumber',
      'basisType': 'text',
      'reasonVi': 'text',
      'sourceBasis': 'text',
      'status': 'id',
    },
    'aiConfig': {
      'key': 'id',
      'value': 'value',
      'unit': 'text',
      'category': 'text',
      'description': 'text',
      'editable': 'requiredBool',
    },
  };

  static String header(String field) =>
      field.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

abstract final class GrindingDatabaseValidator {
  static bool validVersion(Object? v) =>
      v is String && v.length <= 40 && RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(v);

  static int compareVersions(String a, String b) {
    final left = a.split('.').map(BigInt.parse).toList();
    final right = b.split('.').map(BigInt.parse).toList();
    for (var i = 0; i < left.length || i < right.length; i++) {
      final c = (i < left.length ? left[i] : BigInt.zero).compareTo(
        i < right.length ? right[i] : BigInt.zero,
      );
      if (c != 0) return c;
    }
    return 0;
  }

  static GrindingImportReport validate(
    Map<String, dynamic> source, {
    Map<String, List<int>> rowNumbers = const {},
  }) {
    final issues = <GrindingImportIssue>[];
    void issue(String at, String message, {bool warning = false}) =>
        issues.add(GrindingImportIssue(at, message, isError: !warning));
    final version = source['databaseVersion'];
    if (!validVersion(version)) {
      issue(
        'databaseVersion',
        'Phiên bản phải là các số phân cách bằng dấu chấm (ví dụ 1.2).',
      );
    }
    if (source['sourceDocument'] != null &&
        source['sourceDocument'] is! String) {
      issue('sourceDocument', 'Nguồn tài liệu phải là văn bản.');
    }
    final tables = <String, List<Map<String, dynamic>>>{};
    String location(String table, int i, [String? field]) {
      final row = rowNumbers[table]?[i] ?? i + 2;
      return '${GrindingImportSchema.sheets[table]} · dòng $row${field == null ? '' : ' · $field'}';
    }

    for (final table in GrindingImportSchema.fields.entries) {
      final raw = source[table.key];
      if (raw is! List) {
        issue(
          GrindingImportSchema.sheets[table.key]!,
          'Thiếu danh sách dữ liệu; cần import một bản catalog đầy đủ.',
        );
        tables[table.key] = [];
        continue;
      }
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < raw.length; i++) {
        if (raw[i] is! Map<String, dynamic>) {
          issue(location(table.key, i), 'Bản ghi phải là một đối tượng.');
          rows.add({});
          continue;
        }
        final row = Map<String, dynamic>.from(raw[i] as Map);
        for (final f in table.value.entries) {
          var v = row[f.key];
          if (v is String) {
            v = v.trim();
            if (v.isEmpty) v = null;
            row[f.key] = v;
          }
          final required = [
            'id',
            'requiredBool',
            'requiredNumber',
          ].contains(f.value);
          if (v == null) {
            if (required) {
              issue(location(table.key, i, f.key), 'Thiếu giá trị bắt buộc.');
            }
            continue;
          }
          bool valid;
          switch (f.value) {
            case 'id':
            case 'text':
              valid = v is String;
            case 'bool':
            case 'requiredBool':
              valid = v is bool || v == 0 || v == 1;
              if (valid) row[f.key] = v == true || v == 1;
            case 'integer':
            case 'integerId':
              valid = v is num && v.isFinite && v > 0 && v == v.roundToDouble();
              if (valid) row[f.key] = (v).toInt();
            case 'number':
              valid = v is num && v.isFinite && v >= 0;
            case 'signedNumber':
            case 'requiredNumber':
              valid = v is num && v.isFinite;
            default:
              valid = v is String || v is bool || (v is num && v.isFinite);
          }
          if (!valid) {
            issue(
              location(table.key, i, f.key),
              'Sai kiểu hoặc giá trị không hợp lệ (${f.value}).',
            );
          }
        }
        if (row['finenessUnit'] == 'μm' ||
            row['finenessUnit'] == 'um' ||
            row['finenessUnit'] == 'micron') {
          row['finenessUnit'] = 'µm';
        }
        rows.add(row);
      }
      tables[table.key] = rows;
    }
    // Chỉ kiểm tra quan hệ sau khi kiểu dữ liệu đã hợp lệ.
    if (issues.any((i) => i.isError)) {
      return GrindingImportReport(issues: issues);
    }
    for (final key in ['series', 'models', 'materials', 'aiConfig']) {
      if (tables[key]!.isEmpty) {
        issue(GrindingImportSchema.sheets[key]!, 'Danh sách không được rỗng.');
      }
    }
    void unique(String table, List<String> fields) {
      final seen = <String>{};
      for (var i = 0; i < tables[table]!.length; i++) {
        final row = tables[table]![i];
        if (fields.any((f) => row[f] == null)) continue;
        final key = fields.map((f) => '${row[f]}'.toLowerCase()).join('\u0000');
        if (!seen.add(key)) {
          issue(
            location(table, i, fields.join('/')),
            'Bản ghi trùng: ${fields.map((f) => row[f]).join(' / ')}.',
          );
        }
      }
    }

    unique('series', ['seriesCode']);
    unique('models', ['machineId']);
    unique('models', ['seriesCode', 'model']);
    unique('materials', ['materialId']);
    unique('aiConfig', ['key']);
    unique('extraSpecs', ['machineId', 'specKey']);
    unique('selectionTags', ['seriesCode', 'tag']);
    unique('materialSeriesMap', ['materialId', 'seriesCode']);
    for (final table in ['extraSpecs', 'selectionTags', 'materialSeriesMap']) {
      unique(table, ['id']);
    }
    final seriesIds = tables['series']!.map((r) => r['seriesCode']).toSet();
    final machineIds = tables['models']!.map((r) => r['machineId']).toSet();
    final materialIds = tables['materials']!
        .map((r) => r['materialId'])
        .toSet();
    for (final table in tables.entries) {
      for (var i = 0; i < table.value.length; i++) {
        final row = table.value[i];
        for (final relation in {
          'seriesCode': seriesIds,
          'machineId': machineIds,
          'materialId': materialIds,
        }.entries) {
          if (row[relation.key] != null &&
              !relation.value.contains(row[relation.key])) {
            issue(
              location(table.key, i, relation.key),
              'Không tìm thấy bản ghi được tham chiếu: ${row[relation.key]}.',
            );
          }
        }
        if (table.key == 'materials' || table.key == 'materialSeriesMap') {
          if (!['Verified', 'Needs validation'].contains(row['status'])) {
            issue(
              location(table.key, i, 'status'),
              'Chỉ nhận Verified hoặc Needs validation.',
            );
          }
        }
      }
    }
    for (var i = 0; i < tables['models']!.length; i++) {
      final row = tables['models']![i];
      for (final pair in const [
        ('capacityMinKgH', 'capacityMaxKgH'),
        ('finenessMin', 'finenessMax'),
        ('mainMotorKwMin', 'mainMotorKwMax'),
        ('speedRpmMin', 'speedRpmMax'),
      ]) {
        final min = row[pair.$1] as num?;
        final max = row[pair.$2] as num?;
        if (min != null && max != null && min > max) {
          issue(
            location('models', i, pair.$1),
            'Giá trị nhỏ nhất vượt giá trị lớn nhất.',
          );
        }
      }
      final unit = row['finenessUnit'];
      if ((unit != null && !['mesh', 'µm', 'mm'].contains(unit)) ||
          (unit == null &&
              (row['finenessMin'] != null || row['finenessMax'] != null))) {
        issue(
          location('models', i, 'finenessUnit'),
          'Độ mịn phải có đơn vị mesh, µm hoặc mm.',
        );
      }
      if ([
        'capacityMinKgH',
        'capacityMaxKgH',
        'finenessMin',
        'finenessMax',
        'finenessUnit',
      ].any((f) => row[f] == null)) {
        issue(
          location('models', i),
          '${row['model']}: thiếu thông số năng suất/độ mịn; có thể không xuất hiện khi chọn máy.',
          warning: true,
        );
      }
    }
    for (var i = 0; i < tables['extraSpecs']!.length; i++) {
      final row = tables['extraSpecs']![i];
      if (row['specValueNumber'] == null && row['specValueText'] == null) {
        issue(
          location('extraSpecs', i, 'specKey'),
          '${row['machineId']} / ${row['specKey']}: thông số trống, giữ nguyên là chưa có dữ liệu.',
          warning: true,
        );
      }
      if (row['specValueNumber'] != null && row['unit'] == null) {
        issue(
          location('extraSpecs', i, 'unit'),
          'Thông số số chưa có đơn vị; cần kiểm tra nguồn.',
          warning: true,
        );
      }
    }
    final configs = {
      for (final row in tables['aiConfig']!) row['key'] as String: row,
    };
    for (final key in const [
      'capacity_weight',
      'input_size_weight',
      'fineness_weight',
      'candidate_threshold',
      'material_adjustment_min',
      'material_adjustment_max',
    ]) {
      final value = configs[key]?['value'];
      final min = key == 'material_adjustment_min' ? -100 : 0;
      if (value is! num || !value.isFinite || value < min || value > 100) {
        issue('AI_Config · $key', 'Cần giá trị số trong khoảng $min–100.');
      }
    }
    final lower = configs['material_adjustment_min']?['value'];
    final upper = configs['material_adjustment_max']?['value'];
    if (lower is num && upper is num && lower > upper) {
      issue(
        'AI_Config',
        'Giới hạn điều chỉnh nhỏ nhất vượt giới hạn lớn nhất.',
      );
    }
    for (final key in const [
      'ask_if_capacity_missing',
      'ask_if_fineness_missing',
      'allow_unknown_input_size',
      'no_hallucinated_specs',
      'candidate_not_confirmation',
    ]) {
      final row = configs[key];
      final value = row?['value'];
      if (value != true && value != 1) {
        issue(
          'AI_Config · $key',
          'Phiên bản ứng dụng hiện tại yêu cầu cấu hình này bằng true / 1.',
        );
      } else {
        row!['value'] = true;
      }
    }
    if (issues.any((i) => i.isError)) {
      return GrindingImportReport(issues: issues);
    }
    return GrindingImportReport(
      issues: issues,
      snapshot: GrindingDatabaseSnapshot(
        databaseVersion: version as String,
        sourceDocument: source['sourceDocument'] as String?,
        series: List.unmodifiable(
          tables['series']!.map(GrindingSeries.fromJson),
        ),
        machines: List.unmodifiable(
          tables['models']!.map(GrindingMachine.fromJson),
        ),
        extraSpecs: List.unmodifiable(
          tables['extraSpecs']!.map(GrindingExtraSpec.fromJson),
        ),
        selectionTags: List.unmodifiable(
          tables['selectionTags']!.map(GrindingSelectionTag.fromJson),
        ),
        materials: List.unmodifiable(
          tables['materials']!.map(GrindingMaterial.fromJson),
        ),
        materialSeriesMap: List.unmodifiable(
          tables['materialSeriesMap']!.map(GrindingMaterialSeriesMap.fromJson),
        ),
        aiConfig: List.unmodifiable(
          tables['aiConfig']!.map(GrindingAiConfig.fromJson),
        ),
      ),
    );
  }
}
