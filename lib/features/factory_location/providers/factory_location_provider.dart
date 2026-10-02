import 'package:flutter/foundation.dart';

import '../models/factory_location.dart';
import '../repositories/factory_location_repository.dart';
import '../utils/maps_link.dart';

class FactoryLocationProvider extends ChangeNotifier {
  FactoryLocationProvider({FactoryLocationRepository? repository})
    : _repository = repository ?? FactoryLocationRepository();

  final FactoryLocationRepository _repository;

  bool _isLoading = false;
  bool _loaded = false;
  String? _error;
  String _query = '';
  List<FactoryLocation> _items = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;
  List<FactoryLocation> get items => List.unmodifiable(_items);

  List<FactoryLocation> get filtered {
    final keyword = normalizeForSearch(_query);
    if (keyword.isEmpty) return items;
    return _items
        .where((item) => normalizeForSearch(item.name).contains(keyword))
        .toList();
  }

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repository.getAll();
      _loaded = true;
    } catch (error, stackTrace) {
      _error = 'Không thể tải danh sách nhà máy.';
      debugPrint('FactoryLocationProvider.load: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  bool hasDuplicateName(String name, {int? excludeId}) {
    final normalized = normalizeForSearch(name);
    if (normalized.isEmpty) return false;
    return _items.any(
      (item) =>
          item.id != excludeId && normalizeForSearch(item.name) == normalized,
    );
  }

  Future<void> save(FactoryLocation location) async {
    await _repository.save(location);
    await load(force: true);
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await load(force: true);
  }
}
