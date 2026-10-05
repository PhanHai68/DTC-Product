import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../factory_location/utils/maps_link.dart' show normalizeForSearch;
import '../../grinding_machine/utils/grinding_format.dart';
import '../models/packing_catalog.dart';

const _catalogAssetPath = 'assets/database/packing_machine_catalog.json';

/// Nạp catalog Máy đóng gói (asset JSON chỉ đọc) 1 lần và giữ danh sách dòng
/// máy / model cho các màn hình. Dòng máy giữ đúng thứ tự trong catalog;
/// model trong 1 dòng sắp theo số tự nhiên như máy nghiền.
class PackingMachineProvider extends ChangeNotifier {
  PackingMachineProvider({Future<String> Function()? loadSource})
    : _loadSource =
          loadSource ?? (() => rootBundle.loadString(_catalogAssetPath));

  final Future<String> Function() _loadSource;

  List<PackingSeries> _series = const [];
  List<PackingMachine> _machines = const [];
  Map<String, PackingSeries> _seriesByCode = const {};
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;
  Future<void>? _pending;

  List<PackingSeries> get series => _series;
  List<PackingMachine> get machines => _machines;
  bool get isLoading => _isLoading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> load() {
    if (_loaded) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final catalog = PackingCatalog.parse(await _loadSource());
      final order = {
        for (var i = 0; i < catalog.series.length; i++)
          catalog.series[i].seriesCode: i,
      };
      _series = catalog.series;
      _seriesByCode = {for (final s in catalog.series) s.seriesCode: s};
      _machines = [...catalog.machines]
        ..sort((a, b) {
          final bySeries = (order[a.seriesCode] ?? 999).compareTo(
            order[b.seriesCode] ?? 999,
          );
          return bySeries != 0
              ? bySeries
              : GrindingFormat.compareModel(a.model, b.model);
        });
      _loaded = true;
    } catch (error) {
      _error = 'Không thể tải dữ liệu Máy đóng gói: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  PackingSeries? seriesOf(String seriesCode) => _seriesByCode[seriesCode];

  List<PackingMachine> machinesOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).toList();

  int machineCountOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).length;

  PackingMachine? machineById(String machineId) {
    for (final machine in _machines) {
      if (machine.machineId == machineId) return machine;
    }
    return null;
  }

  /// Ảnh riêng của model, không có thì dùng ảnh dòng máy.
  String? imageOf(PackingMachine machine) =>
      machine.image ?? _seriesByCode[machine.seriesCode]?.image;

  String? imageCaptionOf(PackingMachine machine) => machine.image != null
      ? machine.imageCaption
      : _seriesByCode[machine.seriesCode]?.imageCaption;

  /// Tìm theo model, mã / tên dòng máy và nội dung ứng dụng — không phân
  /// biệt hoa thường và dấu tiếng Việt ("tra tui loc" khớp "Trà túi lọc").
  List<PackingMachine> search(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return _machines;
    return _machines.where((machine) {
      final series = _seriesByCode[machine.seriesCode];
      final haystack = normalizeForSearch(
        [
          machine.model,
          series?.displayCode ?? '',
          series?.nameVi ?? '',
          series?.nameEn ?? '',
          series?.applicationVi ?? '',
        ].join(' '),
      );
      return haystack.contains(q);
    }).toList();
  }
}
