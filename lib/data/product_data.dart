// Dữ liệu sản phẩm đọc từ các file JSON trong assets/database/.
//
// Muốn sửa thông số máy: sửa file JSON tương ứng (xem
// assets/database/README.md), không sửa code ở đây. Dữ liệu được nạp một lần
// trong main() bằng ProductData.load(rootBundle.loadString) trước khi chạy app.
import 'dart:convert';

import '../models/acomp_spec_model.dart';

const _colorSorterDir = 'assets/database/color_sorter';
const _airCompressorDir = 'assets/database/air_compressor';

abstract final class ProductData {
  static const colorSorterRicePath = '$_colorSorterDir/sc_rice.json';
  static const colorSorterPaddyPath = '$_colorSorterDir/sf7_paddy.json';
  static const colorSorterTeaPath = '$_colorSorterDir/df_tea.json';
  static const colorSorterMineralPath = '$_colorSorterDir/sx8_mineral.json';
  static const colorSorterAgroPath = '$_colorSorterDir/h7_agro.json';
  static const auxEquipmentPath = '$_colorSorterDir/aux_equipment.json';
  static const teaAuxEquipmentPath = '$_colorSorterDir/tea_aux_equipment.json';

  static const acompSpecsPath = '$_airCompressorDir/specs.json';
  static const acompMccbCablePath = '$_airCompressorDir/mccb_cable.json';
  static const acompPipeStandardPath = '$_airCompressorDir/pipe_standard.json';
  static const acompCommonErrorsPath = '$_airCompressorDir/common_errors.json';
  static const acompDs8011Path = '$_airCompressorDir/ds8011.json';
  static const acompManualPath = '$_airCompressorDir/operation_manual.json';

  static const assetPaths = [
    colorSorterRicePath,
    colorSorterPaddyPath,
    colorSorterTeaPath,
    colorSorterMineralPath,
    colorSorterAgroPath,
    auxEquipmentPath,
    teaAuxEquipmentPath,
    acompSpecsPath,
    acompMccbCablePath,
    acompPipeStandardPath,
    acompCommonErrorsPath,
    acompDs8011Path,
    acompManualPath,
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
    final paddy = _toStringMapList(decode(colorSorterPaddyPath) as List);
    final tea = _toStringMapList(decode(colorSorterTeaPath) as List);
    final mineral = _toStringMapList(decode(colorSorterMineralPath) as List);
    final agro = _toStringMapList(decode(colorSorterAgroPath) as List);
    final auxByModel = {
      for (final entry in (decode(auxEquipmentPath) as Map).entries)
        entry.key as String: _toStringMapList(entry.value as List),
    };
    final teaAux = _toDynamicMapList(decode(teaAuxEquipmentPath) as List);

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
    final manual = _toDynamicMapList(decode(acompManualPath) as List);

    _colorSorterSpecs = rice;
    _paddyColorSorterSpecs = paddy;
    _teaColorSorterSpecs = tea;
    _mineralColorSorterSpecs = mineral;
    _agroColorSorterSpecs = agro;
    _auxEquipSpecsByModel = auxByModel;
    _teaAuxEquipData = teaAux;
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
    _manualSummary = manual;
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
List<AcompSpecModel>? _acompSpecData;
List<Map<String, dynamic>>? _acompModelsFlowData;
List<Map<String, String>>? _acompMccbData;
List<Map<String, dynamic>>? _pipeStandardData;
List<Map<String, String>>? _commonErrorsGeneral;
List<Map<String, String>>? _commonErrorsController;
List<Map<String, String>>? _commonErrorsOilLoss;
List<Map<String, dynamic>>? _ds8011Parameters;
List<Map<String, dynamic>>? _manualSummary;

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

/// Máy tách màu nông sản H7 — `color_sorter/h7_agro.json`.
List<Map<String, String>> get agroColorSorterSpecs =>
    _loaded(_agroColorSorterSpecs);

/// Thiết bị phụ trợ theo model máy gạo/thóc — `color_sorter/aux_equipment.json`.
Map<String, List<Map<String, String>>> get auxEquipSpecsByModel =>
    _loaded(_auxEquipSpecsByModel);

/// Thiết bị phụ trợ dây chuyền trà — `color_sorter/tea_aux_equipment.json`.
List<Map<String, dynamic>> get teaAuxEquipData => _loaded(_teaAuxEquipData);

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

/// Tóm tắt hướng dẫn vận hành — `air_compressor/operation_manual.json`.
List<Map<String, dynamic>> get manualSummary => _loaded(_manualSummary);
