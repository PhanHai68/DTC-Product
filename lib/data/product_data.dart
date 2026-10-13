// Dữ liệu sản phẩm đọc từ các file JSON trong assets/database/.
//
// Muốn sửa thông số máy: sửa file JSON tương ứng (xem
// assets/database/README.md), không sửa code ở đây. Dữ liệu được nạp một lần
// trong main() bằng ProductData.load(rootBundle.loadString) trước khi chạy app.
import 'dart:convert';

const _colorSorterDir = 'assets/database/color_sorter';

abstract final class ProductData {
  static const colorSorterRicePath = '$_colorSorterDir/sc_rice.json';
  static const colorSorterPaddyPath = '$_colorSorterDir/sf7_paddy.json';
  static const colorSorterTeaPath = '$_colorSorterDir/df_tea.json';
  static const colorSorterMineralPath = '$_colorSorterDir/sx8_mineral.json';
  static const colorSorterAgroPath = '$_colorSorterDir/h7_agro.json';
  static const auxEquipmentPath = '$_colorSorterDir/aux_equipment.json';
  static const teaAuxEquipmentPath = '$_colorSorterDir/tea_aux_equipment.json';

  static const assetPaths = [
    colorSorterRicePath,
    colorSorterPaddyPath,
    colorSorterTeaPath,
    colorSorterMineralPath,
    colorSorterAgroPath,
    auxEquipmentPath,
    teaAuxEquipmentPath,
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
    final teaAux = [
      for (final item in decode(teaAuxEquipmentPath) as List)
        <String, dynamic>{
          for (final field in (item as Map).entries)
            field.key as String: field.value is List
                ? List<String>.unmodifiable(field.value as List)
                : field.value as String,
        },
    ];

    _colorSorterSpecs = rice;
    _paddyColorSorterSpecs = paddy;
    _teaColorSorterSpecs = tea;
    _mineralColorSorterSpecs = mineral;
    _agroColorSorterSpecs = agro;
    _auxEquipSpecsByModel = auxByModel;
    _teaAuxEquipData = teaAux;
  }

  static List<Map<String, String>> _toStringMapList(List items) => [
    for (final item in items)
      {
        for (final field in (item as Map).entries)
          field.key as String: field.value as String,
      },
  ];
}

List<Map<String, String>>? _colorSorterSpecs;
List<Map<String, String>>? _paddyColorSorterSpecs;
List<Map<String, String>>? _teaColorSorterSpecs;
List<Map<String, String>>? _mineralColorSorterSpecs;
List<Map<String, String>>? _agroColorSorterSpecs;
Map<String, List<Map<String, String>>>? _auxEquipSpecsByModel;
List<Map<String, dynamic>>? _teaAuxEquipData;

T _loaded<T>(T? value) {
  if (value == null) {
    throw StateError(
      'Chưa nạp dữ liệu sản phẩm: gọi ProductData.load() trước.',
    );
  }
  return value;
}

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
