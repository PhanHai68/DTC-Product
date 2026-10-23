import 'package:flutter/foundation.dart';

import '../models/technical_term.dart';
import '../repositories/technical_dictionary_repository.dart';
import '../utils/term_index.dart';

/// Lọc theo tiến độ học của người dùng.
enum ProgressFilter {
  notStarted('Chưa học'),
  learning('Đang học'),
  learned('Đã thuộc');

  const ProgressFilter(this.label);
  final String label;
}

/// Tiến độ của một nhóm máy (hoặc toàn bộ khi [group] là `null`).
class GroupProgress {
  const GroupProgress({
    required this.group,
    required this.total,
    required this.learning,
    required this.learned,
  });

  final String? group;
  final int total;
  final int learning;
  final int learned;

  double get ratio => total == 0 ? 0 : learned / total;
}

class TechnicalDictionaryProvider extends ChangeNotifier {
  TechnicalDictionaryProvider({TechnicalDictionaryRepository? repository})
    : _repository = repository ?? TechnicalDictionaryRepository();

  final TechnicalDictionaryRepository _repository;

  TechnicalDictionaryData? _data;
  TermIndex? _index;
  Map<int, TechnicalTerm> _byId = const {};
  final Map<String, TermProgress> _progress = {};
  bool _loading = false;
  String? _error;

  String _query = '';
  String? _group;
  String? _type;
  ProgressFilter? _progressFilter;
  List<TechnicalTerm>? _results;

  bool get loading => _loading;
  String? get error => _error;
  bool get ready => _data != null;
  List<String> get groups => _data?.groups ?? const [];
  List<String> get types => _data?.types ?? const [];
  List<TechnicalTerm> get terms => _data?.terms ?? const [];
  String get query => _query;
  String? get group => _group;
  String? get type => _type;
  ProgressFilter? get progressFilter => _progressFilter;
  bool get hasFilter =>
      _group != null || _type != null || _progressFilter != null;

  Future<void> init() async {
    if (_loading || _data != null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repository.loadDictionary();
      _data = data;
      _index = TermIndex(data.terms);
      _byId = {for (final term in data.terms) term.id: term};
      _progress
        ..clear()
        ..addAll(await _repository.loadProgress());
    } catch (e, stack) {
      debugPrint('Không tải được từ điển: $e\n$stack');
      _error = 'Không tải được từ điển. Vui lòng thử lại.';
    } finally {
      _loading = false;
      _results = null;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _data = null;
    await init();
  }

  TechnicalTerm? termById(int id) => _byId[id];

  /// Mục mà một tên trong "Từ liên quan" trỏ tới (null nếu chưa có).
  TechnicalTerm? lookup(String name) => _index?.lookup(name);

  TermProgress progressOf(TechnicalTerm term) =>
      _progress[term.key] ?? const TermProgress();

  /// Kết quả theo từ khóa và bộ lọc hiện tại (đã tính sẵn tới lần đổi sau).
  List<TechnicalTerm> get results {
    final index = _index;
    if (index == null) return const [];
    return _results ??= index.search(_query, terms.where(_matchesFilters));
  }

  bool _matchesFilters(TechnicalTerm term) {
    if (_group != null && term.group != _group) return false;
    if (_type != null && term.type != _type) return false;
    final filter = _progressFilter;
    if (filter == null) return true;
    final status = progressOf(term).status;
    return switch (filter) {
      ProgressFilter.notStarted => status == null,
      ProgressFilter.learning => status == TermStatus.learning,
      ProgressFilter.learned => status == TermStatus.learned,
    };
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _invalidate();
  }

  void setGroup(String? value) {
    if (value == _group) return;
    _group = value;
    _invalidate();
  }

  void setType(String? value) {
    if (value == _type) return;
    _type = value;
    _invalidate();
  }

  void setProgressFilter(ProgressFilter? value) {
    if (value == _progressFilter) return;
    _progressFilter = value;
    _invalidate();
  }

  void clearFilters() {
    if (!hasFilter) return;
    _group = null;
    _type = null;
    _progressFilter = null;
    _invalidate();
  }

  void _invalidate() {
    _results = null;
    notifyListeners();
  }

  Future<void> setStatus(TechnicalTerm term, TermStatus? status) =>
      _save(term, TermProgress(status: status, note: progressOf(term).note));

  Future<void> setNote(TechnicalTerm term, String note) {
    final current = progressOf(term);
    if (current.note == note.trim()) return Future.value();
    return _save(term, TermProgress(status: current.status, note: note.trim()));
  }

  Future<void> _save(TechnicalTerm term, TermProgress progress) async {
    if (progress.isEmpty) {
      _progress.remove(term.key);
    } else {
      _progress[term.key] = progress;
    }
    // Lọc theo trạng thái thì danh sách phải tính lại.
    if (_progressFilter != null) _results = null;
    if (!_disposed) notifyListeners();
    await _repository.saveProgress(term.key, progress);
  }

  // Ghi chú có thể được lưu nốt ngay sau khi rời module (provider đã hủy):
  // vẫn ghi xuống database nhưng không báo cập nhật nữa.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Tổng hợp tiến độ: dòng đầu là toàn bộ, sau đó từng nhóm máy.
  List<GroupProgress> progressSummary() {
    GroupProgress count(String? group) {
      var total = 0, learning = 0, learned = 0;
      for (final term in terms) {
        if (group != null && term.group != group) continue;
        total++;
        switch (progressOf(term).status) {
          case TermStatus.learning:
            learning++;
          case TermStatus.learned:
            learned++;
          case null:
            break;
        }
      }
      return GroupProgress(
        group: group,
        total: total,
        learning: learning,
        learned: learned,
      );
    }

    return [count(null), for (final group in groups) count(group)];
  }
}
