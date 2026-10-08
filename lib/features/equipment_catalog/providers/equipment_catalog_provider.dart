import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../factory_location/utils/maps_link.dart' show normalizeForSearch;
import '../../grinding_machine/utils/grinding_format.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';

/// Dữ liệu 1 catalog đã nạp, kèm các hàm tra cứu. Dòng máy giữ đúng thứ tự
/// trong file; model trong 1 dòng sắp theo số tự nhiên như máy nghiền.
class LoadedEquipmentCatalog {
  LoadedEquipmentCatalog(EquipmentCatalog catalog)
    : criteria = catalog.criteria,
      series = catalog.series,
      _seriesByCode = {for (final s in catalog.series) s.seriesCode: s},
      machines = _sorted(catalog);

  final List<SelectorCriterion> criteria;
  final List<EquipmentSeries> series;
  final List<EquipmentMachine> machines;
  final Map<String, EquipmentSeries> _seriesByCode;

  Map<String, EquipmentSeries> get seriesByCode => _seriesByCode;

  static List<EquipmentMachine> _sorted(EquipmentCatalog catalog) {
    final order = {
      for (var i = 0; i < catalog.series.length; i++)
        catalog.series[i].seriesCode: i,
    };
    return [...catalog.machines]..sort((a, b) {
      final bySeries = (order[a.seriesCode] ?? 999).compareTo(
        order[b.seriesCode] ?? 999,
      );
      return bySeries != 0
          ? bySeries
          : GrindingFormat.compareModel(a.model, b.model);
    });
  }

  EquipmentSeries? seriesOf(String seriesCode) => _seriesByCode[seriesCode];

  List<EquipmentMachine> machinesOf(String seriesCode) =>
      machines.where((m) => m.seriesCode == seriesCode).toList();

  int machineCountOf(String seriesCode) =>
      machines.where((m) => m.seriesCode == seriesCode).length;

  EquipmentMachine? machineById(String machineId) {
    for (final machine in machines) {
      if (machine.machineId == machineId) return machine;
    }
    return null;
  }

  /// Ảnh riêng của model, không có thì dùng ảnh dòng máy.
  String? imageOf(EquipmentMachine machine) =>
      machine.image ?? _seriesByCode[machine.seriesCode]?.image;

  String? imageCaptionOf(EquipmentMachine machine) => machine.image != null
      ? machine.imageCaption
      : _seriesByCode[machine.seriesCode]?.imageCaption;

  /// Tìm theo model, mã / tên dòng máy và nội dung ứng dụng — không phân
  /// biệt hoa thường và dấu tiếng Việt ("tra tui loc" khớp "Trà túi lọc").
  List<EquipmentMachine> search(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return machines;
    return machines.where((machine) {
      final series = _seriesByCode[machine.seriesCode];
      final haystack = normalizeForSearch(
        [
          machine.model,
          series?.displayCode ?? '',
          series?.nameVi ?? '',
          series?.nameEn ?? '',
          series?.groupVi ?? '',
          series?.applicationVi ?? '',
        ].join(' '),
      );
      return haystack.contains(q);
    }).toList();
  }
}

/// Nạp các catalog thiết bị (asset JSON chỉ đọc) theo nhu cầu, mỗi catalog 1
/// lần, và giữ dữ liệu cho mọi màn hình catalog.
class EquipmentCatalogProvider extends ChangeNotifier {
  EquipmentCatalogProvider({
    Future<String> Function(String assetPath)? loadSource,
  }) : _loadSource = loadSource ?? rootBundle.loadString;

  final Future<String> Function(String assetPath) _loadSource;
  final Map<String, LoadedEquipmentCatalog> _loaded = {};
  final Map<String, String> _errors = {};
  final Map<String, Future<void>> _pending = {};

  LoadedEquipmentCatalog? catalog(EquipmentCatalogConfig config) =>
      _loaded[config.id];

  bool isLoaded(EquipmentCatalogConfig config) =>
      _loaded.containsKey(config.id);

  String? error(EquipmentCatalogConfig config) => _errors[config.id];

  Future<void> load(EquipmentCatalogConfig config) {
    if (_loaded.containsKey(config.id)) return Future.value();
    // Callback thân khối: trả về Future vừa xoá sẽ khiến whenComplete chờ
    // chính nó (treo vĩnh viễn).
    return _pending[config.id] ??= _load(config).whenComplete(() {
      _pending.remove(config.id);
    });
  }

  Future<void> _load(EquipmentCatalogConfig config) async {
    _errors.remove(config.id);
    try {
      final catalog = EquipmentCatalog.parse(
        await _loadSource(config.assetPath),
      );
      _loaded[config.id] = LoadedEquipmentCatalog(catalog);
    } catch (error) {
      _errors[config.id] = 'Không thể tải dữ liệu ${config.title}: $error';
    }
    notifyListeners();
  }
}
