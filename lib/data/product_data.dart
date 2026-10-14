// Dữ liệu sản phẩm đọc từ các file JSON trong assets/database/.
//
// Muốn sửa thông số máy: sửa file JSON tương ứng (xem
// assets/database/README.md), không sửa code ở đây. Dữ liệu được nạp một lần
// trong main() bằng ProductData.load(rootBundle.loadString) trước khi chạy app.
import 'dart:convert';

import '../models/acomp_spec_model.dart';
import '../models/color_sorter_errors.dart';
import '../models/material_model.dart';
import '../models/packing_machine.dart';

const _colorSorterDir = 'assets/database/color_sorter';
const _airCompressorDir = 'assets/database/air_compressor';
const _packingScaleDir = 'assets/database/packing_scale';

abstract final class ProductData {
  static const colorSorterRicePath = '$_colorSorterDir/sc_rice.json';
  static const colorSorterPaddyPath = '$_colorSorterDir/sf7_paddy.json';
  static const colorSorterTeaPath = '$_colorSorterDir/df_tea.json';
  static const colorSorterMineralPath = '$_colorSorterDir/sx8_mineral.json';
  static const colorSorterAgroPath = '$_colorSorterDir/h7_agro.json';
  static const auxEquipmentPath = '$_colorSorterDir/aux_equipment.json';
  static const teaAuxEquipmentPath = '$_colorSorterDir/tea_aux_equipment.json';
  static const powerConsumptionPath = '$_colorSorterDir/power_consumption.json';
  static const colorSorterErrorsPath = '$_colorSorterDir/common_errors.json';

  static const acompSpecsPath = '$_airCompressorDir/specs.json';
  static const acompMaterialsPath = '$_airCompressorDir/materials.json';
  static const acompMccbCablePath = '$_airCompressorDir/mccb_cable.json';
  static const acompPipeStandardPath = '$_airCompressorDir/pipe_standard.json';
  static const acompCommonErrorsPath = '$_airCompressorDir/common_errors.json';
  static const acompDs8011Path = '$_airCompressorDir/ds8011.json';

  static const packingMachinesPath = '$_packingScaleDir/machines.json';
  static const packingFeaturesPath = '$_packingScaleDir/features.json';

  static const assetPaths = [
    colorSorterRicePath,
    colorSorterPaddyPath,
    colorSorterTeaPath,
    colorSorterMineralPath,
    colorSorterAgroPath,
    auxEquipmentPath,
    teaAuxEquipmentPath,
    powerConsumptionPath,
    colorSorterErrorsPath,
    acompSpecsPath,
    acompMaterialsPath,
    acompMccbCablePath,
    acompPipeStandardPath,
    acompCommonErrorsPath,
    acompDs8011Path,
    packingMachinesPath,
    packingFeaturesPath,
  ];

  /// Nạp toàn bộ file JSON qua [readAsset] (trong app: rootBundle.loadString).
  static Future<void> load(
    Future<String> Function(String path) readAsset,
  ) async {
    final sources = <String, String>{};
    for (final path in assetPaths) {
      sources[path] = await readAsset(path);
    }
    loadFromStrings(sources);
  }

  /// Nạp từ nội dung JSON có sẵn, theo đường dẫn asset. Dùng cho test.
  /// Giải mã hết rồi mới gán, nên một file sai không để lại dữ liệu nạp dở.
  static void loadFromStrings(Map<String, String> sources) {
    Object? decode(String path) {
      final source = sources[path];
      if (source == null) {
        throw StateError('Thiếu file dữ liệu sản phẩm: $path');
      }
      try {
        return jsonDecode(source);
      } on FormatException catch (error) {
        throw FormatException(
          'File $path không phải JSON hợp lệ: ${error.message}',
        );
      }
    }

    final rice = _toStringMapList(decode(colorSorterRicePath) as List);
    final paddy = _withRiceAirSystem(
      _toStringMapList(decode(colorSorterPaddyPath) as List),
      rice,
    );
    final tea = _toStringMapList(decode(colorSorterTeaPath) as List);
    final mineral = _toStringMapList(decode(colorSorterMineralPath) as List);
    final agro = _toStringMapList(decode(colorSorterAgroPath) as List);
    final auxByModel = {
      for (final entry in (decode(auxEquipmentPath) as Map).entries)
        entry.key as String: _toStringMapList(entry.value as List),
    };
    final teaAux = _toDynamicMapList(decode(teaAuxEquipmentPath) as List);
    final powerByModel = {
      for (final entry in (decode(powerConsumptionPath) as Map).entries)
        entry.key as String: _toStringMapList(entry.value as List),
    };
    // Máy thóc chưa có bảng điện năng riêng (để tính hoàn vốn): lấy của máy
    // gạo cùng số máng, thay năng suất và công suất máy tách màu bằng thông số
    // của chính máy thóc; không có máy gạo cùng số máng thì bỏ qua.
    final paddyRice = _sameChuteRiceModels(paddy, rice);
    for (final spec in paddy) {
      final model = spec['Model'];
      if (model == null || powerByModel.containsKey(model)) continue;
      final source = (paddyRice[model] ?? const <String>[])
          .where(powerByModel.containsKey)
          .firstOrNull;
      if (source == null) continue;
      powerByModel[model] = _paddyPowerRows(powerByModel[source]!, spec);
    }
    // Máy trà: công suất cả dây chuyền tính từ danh sách thiết bị phụ trợ
    // (tea_aux_equipment.json là dây chuyền của model máy tách màu có trong
    // danh sách, hiện là DF53 Pro).
    final teaLine = _teaLinePower(tea, teaAux);
    if (teaLine != null && !powerByModel.containsKey(teaLine.$1)) {
      powerByModel[teaLine.$1] = teaLine.$2;
    }
    final sorterErrors = ColorSorterErrors.fromJson(
      decode(colorSorterErrorsPath) as Map<String, dynamic>,
    );

    final materials = [
      for (final item in decode(acompMaterialsPath) as List)
        MaterialModel.fromJson(item as Map<String, dynamic>),
    ];
    final acompSpecs = [
      for (final item in decode(acompSpecsPath) as List)
        AcompSpecModel.fromJson(item as Map<String, dynamic>),
    ];
    final mccb = _toStringMapList(decode(acompMccbCablePath) as List);
    final pipes = _toDynamicMapList(decode(acompPipeStandardPath) as List);
    final errors = decode(acompCommonErrorsPath) as Map;
    final errorsGeneral = _toStringMapList(errors['general'] as List);
    final errorsController = _toStringMapList(errors['controller'] as List);
    final errorsOilLoss = _toStringMapList(errors['oilLoss'] as List);
    final ds8011 = _toDynamicMapList(decode(acompDs8011Path) as List);

    final packing = [
      for (final item in decode(packingMachinesPath) as List)
        PackingMachine.fromMap(item as Map<String, dynamic>),
    ]..sort((a, b) => (a.stt ?? 0).compareTo(b.stt ?? 0));
    final packingFeatures = {
      for (final entry in (decode(packingFeaturesPath) as Map).entries)
        entry.key as String: _toStringMapList(entry.value as List),
    };

    _colorSorterSpecs = rice;
    _paddyColorSorterSpecs = paddy;
    _teaColorSorterSpecs = tea;
    _mineralColorSorterSpecs = mineral;
    _agroColorSorterSpecs = agro;
    _auxEquipSpecsByModel = auxByModel;
    _teaAuxEquipData = teaAux;
    _powerConsumptionData = powerByModel;
    _paddyRiceModels = paddyRice;
    _colorSorterErrors = sorterErrors;
    _materialDataList = materials;
    _acompSpecData = acompSpecs;
    _acompModelsFlowData = [
      for (final spec in acompSpecs)
        {
          'model': spec.modelCode,
          'flow7bar': _formatFlow(spec.flow7Bar),
          'flow8bar': _formatFlow(spec.flow8Bar),
        },
    ];
    _acompMccbData = mccb;
    _pipeStandardData = pipes;
    _commonErrorsGeneral = errorsGeneral;
    _commonErrorsController = errorsController;
    _commonErrorsOilLoss = errorsOilLoss;
    _ds8011Parameters = ds8011;
    _packingMachines = List.unmodifiable(packing);
    _packingFeatureSets = packingFeatures;
  }

  /// Các trường khí nén máy thóc lấy theo máy gạo.
  static const _riceAirKeys = [
    'Áp suất khí nén',
    'Lưu lượng khí tiêu thụ',
    'Máy nén khí đồng bộ',
    'Bình tích khí đồng bộ',
  ];

  /// Máy thóc dùng hệ thống khí nén của máy gạo cùng số máng (cùng 96
  /// ejector/máng); không có máy gạo cùng số máng thì lấy máy gần nhất,
  /// cách đều hai bên thì lấy máy ít máng hơn (VD 8 máng → SC10 7 máng).
  static List<Map<String, String>> _withRiceAirSystem(
    List<Map<String, String>> paddy,
    List<Map<String, String>> rice,
  ) {
    final riceByChutes = [
      for (final spec in rice)
        if (int.tryParse(spec['Số máng'] ?? '') case final chutes?)
          (chutes, spec),
    ];
    if (riceByChutes.isEmpty) return paddy;
    return [
      for (final spec in paddy)
        switch (int.tryParse(spec['Số máng'] ?? '')) {
          null => spec,
          final chutes => {
            ...spec,
            for (final MapEntry(:key, :value)
                in _nearestByChutes(riceByChutes, chutes).entries)
              if (_riceAirKeys.contains(key) && value.isNotEmpty) key: value,
          },
        },
    ];
  }

  /// Model máy thóc → các model máy gạo có đúng cùng số máng (theo thứ tự
  /// trong sc_rice.json). Máy thóc không có máy gạo cùng số máng thì không có
  /// trong kết quả.
  static Map<String, List<String>> _sameChuteRiceModels(
    List<Map<String, String>> paddy,
    List<Map<String, String>> rice,
  ) {
    final result = <String, List<String>>{};
    for (final spec in paddy) {
      final model = spec['Model'];
      final chutes = spec['Số máng'];
      if (model == null || chutes == null) continue;
      final riceModels = [
        for (final r in rice)
          if (r['Số máng'] == chutes && r['Model'] != null) r['Model']!,
      ];
      if (riceModels.isNotEmpty) result[model] = riceModels;
    }
    return result;
  }

  static const _capacityRow = 'Năng suất (Tấn/h)';
  static const _sorterPowerRow = 'Máy tách màu (kW)';
  static const _maxPowerRow = 'Công suất tối đa (kW)';
  static const _avgPowerRow = 'Công suất trung bình (kW)';

  /// Bảng điện năng máy thóc từ bảng của máy gạo cùng số máng: năng suất =
  /// trung bình mức thấp nhất và cao nhất của máy thóc, công suất máy tách
  /// màu theo máy thóc; công suất tối đa = tổng các thiết bị, trung bình =
  /// 80% tối đa (cùng cách tính trong power_consumption.json).
  static List<Map<String, String>> _paddyPowerRows(
    List<Map<String, String>> riceRows,
    Map<String, String> paddySpec,
  ) {
    final range = (paddySpec['Năng suất (tấn/giờ)'] ?? '')
        .split('-')
        .map((part) => double.tryParse(part.trim()))
        .nonNulls
        .toList();
    final capacity = range.isEmpty
        ? null
        : (range.first + range.last) / 2;
    final sorterPower = paddySpec['Công suất điện (kW)'];

    final rows = [
      for (final row in riceRows)
        {
          ...row,
          if (row['Tiêu chí'] == _capacityRow && capacity != null)
            'Thông số': _formatFlow(capacity),
          if (row['Tiêu chí'] == _sorterPowerRow && sorterPower != null)
            'Thông số': sorterPower,
        },
    ];
    var maxPower = 0.0;
    for (final row in rows) {
      final name = row['Tiêu chí'];
      if (name == _capacityRow || name == _maxPowerRow || name == _avgPowerRow) {
        continue;
      }
      maxPower += double.tryParse(row['Thông số'] ?? '') ?? 0;
    }
    return [
      for (final row in rows)
        switch (row['Tiêu chí']) {
          _maxPowerRow => {...row, 'Thông số': maxPower.toStringAsFixed(2)},
          _avgPowerRow => {
            ...row,
            'Thông số': (maxPower * 0.8).toStringAsFixed(2),
          },
          _ => row,
        },
    ];
  }

  static const _linePeakPowerRow = 'Công suất lớn nhất (kW)';

  /// Bảng điện năng dây chuyền trà từ danh sách thiết bị phụ trợ: model là
  /// máy tách màu trong danh sách; mỗi thiết bị một dòng (công suất × số
  /// lượng); công suất lớn nhất = tổng; năng suất = năng suất tối đa của model.
  /// Không có công suất trung bình — tính tiền điện dùng công suất lớn nhất.
  static (String, List<Map<String, String>>)? _teaLinePower(
    List<Map<String, String>> tea,
    List<Map<String, dynamic>> teaAux,
  ) {
    final sorterModel = teaAux
        .where((item) => item['name'] == 'Máy tách màu')
        .map((item) => (item['model'] as String? ?? '').toLowerCase())
        .firstOrNull;
    final spec = tea
        .where((s) => (s['model'] ?? '').toLowerCase() == sorterModel)
        .firstOrNull;
    if (spec == null) return null;

    final rows = <Map<String, String>>[];
    final capacityKg = double.tryParse(spec['capacity_max_kg_h'] ?? '');
    if (capacityKg != null) {
      rows.add({
        'Tiêu chí': _capacityRow,
        'Thông số': _formatFlow(capacityKg / 1000),
      });
    }
    var total = 0.0;
    for (final item in teaAux) {
      final power = double.tryParse(
        (item['power'] as String? ?? '').replaceAll('kW', '').trim(),
      );
      if (power == null) continue;
      final quantity = int.tryParse(item['quantity'] as String? ?? '') ?? 1;
      final linePower = power * quantity;
      total += linePower;
      rows.add({
        'Tiêu chí': quantity > 1
            ? '${item['name']} × $quantity (kW)'
            : '${item['name']} (kW)',
        'Thông số': _formatFlow(double.parse(linePower.toStringAsFixed(2))),
      });
    }
    rows.add({
      'Tiêu chí': _linePeakPowerRow,
      'Thông số': total.toStringAsFixed(2),
    });
    return (spec['model']!, rows);
  }

  static Map<String, String> _nearestByChutes(
    List<(int, Map<String, String>)> riceByChutes,
    int chutes,
  ) {
    var best = riceByChutes.first;
    for (final candidate in riceByChutes.skip(1)) {
      final diff = (candidate.$1 - chutes).abs();
      final bestDiff = (best.$1 - chutes).abs();
      if (diff < bestDiff || (diff == bestDiff && candidate.$1 < best.$1)) {
        best = candidate;
      }
    }
    return best.$2;
  }

  static List<Map<String, String>> _toStringMapList(List items) => [
    for (final item in items)
      {
        for (final field in (item as Map).entries)
          field.key as String: field.value as String,
      },
  ];

  static List<Map<String, dynamic>> _toDynamicMapList(List items) => [
    for (final item in items) _toDynamicMap(item as Map),
  ];

  /// Đổi Map/List từ jsonDecode sang kiểu màn hình đang ép: danh sách chuỗi
  /// thành `List<String>`, danh sách object thành `List<Map<String, dynamic>>`.
  static Map<String, dynamic> _toDynamicMap(Map map) => {
    for (final field in map.entries)
      field.key as String: switch (field.value) {
        final Map value => _toDynamicMap(value),
        final List value when value.every((e) => e is String) =>
          List<String>.unmodifiable(value),
        final List value when value.every((e) => e is Map) => _toDynamicMapList(
          value,
        ),
        final value => value,
      },
  };

  /// 5.0 → "5", 30.25 → "30.25" (giống cách bảng lưu lượng cũ ghi số).
  static String _formatFlow(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

List<Map<String, String>>? _colorSorterSpecs;
List<Map<String, String>>? _paddyColorSorterSpecs;
List<Map<String, String>>? _teaColorSorterSpecs;
List<Map<String, String>>? _mineralColorSorterSpecs;
List<Map<String, String>>? _agroColorSorterSpecs;
Map<String, List<Map<String, String>>>? _auxEquipSpecsByModel;
List<Map<String, dynamic>>? _teaAuxEquipData;
Map<String, List<Map<String, String>>>? _powerConsumptionData;
ColorSorterErrors? _colorSorterErrors;
Map<String, List<String>>? _paddyRiceModels;
List<MaterialModel>? _materialDataList;
List<AcompSpecModel>? _acompSpecData;
List<Map<String, dynamic>>? _acompModelsFlowData;
List<Map<String, String>>? _acompMccbData;
List<Map<String, dynamic>>? _pipeStandardData;
List<Map<String, String>>? _commonErrorsGeneral;
List<Map<String, String>>? _commonErrorsController;
List<Map<String, String>>? _commonErrorsOilLoss;
List<Map<String, dynamic>>? _ds8011Parameters;
List<PackingMachine>? _packingMachines;
Map<String, List<Map<String, String>>>? _packingFeatureSets;

T _loaded<T>(T? value) {
  if (value == null) {
    throw StateError(
      'Chưa nạp dữ liệu sản phẩm: gọi ProductData.load() trước.',
    );
  }
  return value;
}

// ── Máy tách màu ────────────────────────────────────────────────────────────

/// Máy tách màu gạo dòng SC — `color_sorter/sc_rice.json`.
List<Map<String, String>> get colorSorterSpecs => _loaded(_colorSorterSpecs);

/// Máy tách màu thóc SF7 — `color_sorter/sf7_paddy.json`.
List<Map<String, String>> get paddyColorSorterSpecs =>
    _loaded(_paddyColorSorterSpecs);

/// Máy tách màu trà dòng DF — `color_sorter/df_tea.json`.
List<Map<String, String>> get teaColorSorterSpecs =>
    _loaded(_teaColorSorterSpecs);

/// Máy tách màu khoáng sản SX8 — `color_sorter/sx8_mineral.json`.
List<Map<String, String>> get mineralColorSorterSpecs =>
    _loaded(_mineralColorSorterSpecs);

/// Máy tách màu nông sản dòng H (H1…H12) — `color_sorter/h7_agro.json`.
List<Map<String, String>> get agroColorSorterSpecs =>
    _loaded(_agroColorSorterSpecs);

/// Thiết bị phụ trợ theo model máy gạo/thóc — `color_sorter/aux_equipment.json`.
Map<String, List<Map<String, String>>> get auxEquipSpecsByModel =>
    _loaded(_auxEquipSpecsByModel);

/// Thiết bị phụ trợ dây chuyền trà — `color_sorter/tea_aux_equipment.json`.
List<Map<String, dynamic>> get teaAuxEquipData => _loaded(_teaAuxEquipData);

/// Điện năng tiêu thụ cả dây chuyền theo model SC —
/// `color_sorter/power_consumption.json`.
Map<String, List<Map<String, String>>> get powerConsumptionData =>
    _loaded(_powerConsumptionData);

/// Dòng máy tách màu dùng chung luồng phân tích hoàn vốn.
enum ColorSorterLine { rice, paddy, tea }

/// Công suất dùng để tính tiền điện của [model]: công suất trung bình; model
/// không có công suất trung bình (dây chuyền trà) dùng công suất lớn nhất.
double? billingPowerKw(String model) {
  final rows = powerConsumptionData[model];
  if (rows == null) return null;
  String? value(String name) =>
      rows.where((r) => r['Tiêu chí'] == name).firstOrNull?['Thông số'];
  final raw =
      value('Công suất trung bình (kW)') ?? value('Công suất lớn nhất (kW)');
  return raw == null ? null : double.tryParse(raw);
}

/// Các model có bảng điện năng (dùng trong phân tích hoàn vốn) của [line].
/// Máy thóc lấy bảng của máy gạo cùng số máng (xem [riceModelForPaddy]);
/// máy trà chỉ có model có danh sách thiết bị dây chuyền (DF53 Pro).
List<String> powerConsumptionModels(ColorSorterLine line) {
  final lineModels = {
    for (final spec in switch (line) {
      ColorSorterLine.rice => colorSorterSpecs,
      ColorSorterLine.paddy => paddyColorSorterSpecs,
      ColorSorterLine.tea => teaColorSorterSpecs,
    })
      ?(spec['Model'] ?? spec['model']),
  };
  return [
    for (final model in powerConsumptionData.keys)
      if (lineModels.contains(model)) model,
  ];
}

/// Máy gạo cùng số máng với [paddyModel] (đầu tiên theo thứ tự sc_rice.json)
/// có trong [available]; `null` nếu không có máy gạo cùng số máng.
String? riceModelForPaddy(String paddyModel, Iterable<String> available) {
  final candidates = _loaded(_paddyRiceModels)[paddyModel] ?? const [];
  final keys = available.toSet();
  return candidates.where(keys.contains).firstOrNull;
}

/// Tra cứu lỗi máy tách màu (dùng chung mọi dòng máy) —
/// `color_sorter/common_errors.json`.
ColorSorterErrors get colorSorterErrors => _loaded(_colorSorterErrors);

// ── Máy nén khí ACOMP ───────────────────────────────────────────────────────

/// Thông số máy nén khí — `air_compressor/specs.json`.
List<AcompSpecModel> get acompSpecData => _loaded(_acompSpecData);

/// Lưu lượng 7/8 bar theo model, sinh từ `air_compressor/specs.json`
/// (dùng cho màn tính ống khí nén và thời gian nạp bình).
List<Map<String, dynamic>> get acompModelsFlowData =>
    _loaded(_acompModelsFlowData);

/// MCCB và cáp điện theo model — `air_compressor/mccb_cable.json`.
List<Map<String, String>> get acompMccbData => _loaded(_acompMccbData);

/// Bảng ống tiêu chuẩn DN/mm — `air_compressor/pipe_standard.json`.
List<Map<String, dynamic>> get pipeStandardData => _loaded(_pipeStandardData);

/// Lỗi thường gặp: chung — `air_compressor/common_errors.json` (`general`).
List<Map<String, String>> get commonErrorsGeneral =>
    _loaded(_commonErrorsGeneral);

/// Lỗi bộ điều khiển — `air_compressor/common_errors.json` (`controller`).
List<Map<String, String>> get commonErrorsController =>
    _loaded(_commonErrorsController);

/// Lỗi hao dầu — `air_compressor/common_errors.json` (`oilLoss`).
List<Map<String, String>> get commonErrorsOilLoss =>
    _loaded(_commonErrorsOilLoss);

/// Tham số cài đặt bộ điều khiển DS8011 — `air_compressor/ds8011.json`.
List<Map<String, dynamic>> get ds8011Parameters => _loaded(_ds8011Parameters);

/// Nguyên liệu và hệ số khí cho màn chọn máy nén khí theo máy tách màu —
/// `air_compressor/materials.json`.
List<MaterialModel> get materialDataList => _loaded(_materialDataList);

// ── Cân đóng gói ────────────────────────────────────────────────────────────

/// Máy cân đóng gói, sắp theo `stt` — `packing_scale/machines.json`.
List<PackingMachine> get packingMachines => _loaded(_packingMachines);

/// Các bộ đặc điểm nổi bật theo tên bộ — `packing_scale/features.json`.
/// Mỗi máy chọn bộ của mình qua trường `feature_set`.
Map<String, List<Map<String, String>>> get packingFeatureSets =>
    _loaded(_packingFeatureSets);
