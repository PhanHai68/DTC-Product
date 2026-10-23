import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/settings_provider.dart';
import '../models/technical_term.dart';
import '../repositories/technical_dictionary_repository.dart';
import 'daily_word_picker.dart';

/// Cài đặt của thẻ, lấy từ [SettingsProvider]. So sánh được để biết khi nào
/// phải chọn lại từ.
@immutable
class DailyWordOptions {
  DailyWordOptions({
    required this.mode,
    required Iterable<String> groups,
    required this.reviewLearned,
  }) : groups = Set.unmodifiable(groups);

  factory DailyWordOptions.fromSettings(SettingsProvider settings) =>
      DailyWordOptions(
        mode: settings.homeDailyWordMode,
        groups: settings.homeDailyWordGroups,
        reviewLearned: settings.homeDailyWordReviewLearned,
      );

  final DailyWordMode mode;
  final Set<String> groups;
  final bool reviewLearned;

  @override
  bool operator ==(Object other) =>
      other is DailyWordOptions &&
      other.mode == mode &&
      other.reviewLearned == reviewLearned &&
      setEquals(other.groups, groups);

  @override
  int get hashCode =>
      Object.hash(mode, reviewLearned, Object.hashAllUnordered(groups));
}

/// Giữ từ đang hiện trên thẻ "Từ vựng hôm nay".
///
/// - [DailyWordMode.perDay]: lưu "ngày|từ" vào cài đặt máy, cả ngày một từ.
/// - [DailyWordMode.perLaunch]: nhớ trong bộ nhớ, đổi khi mở lại app; quay về
///   Home trong cùng lần mở vẫn là từ cũ.
class DailyWordController extends ChangeNotifier {
  DailyWordController({
    TechnicalDictionaryRepository? repository,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    Random? random,
  }) : _repository = repository ?? TechnicalDictionaryRepository(),
       _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  static const historyKey = 'daily_word_history';
  static const todayKey = 'daily_word_today';

  /// Từ của lần mở app hiện tại (chế độ [DailyWordMode.perLaunch]).
  static String? _launchWord;

  @visibleForTesting
  static void debugResetLaunchWord() => _launchWord = null;

  final TechnicalDictionaryRepository _repository;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final Random _random;

  static final _dayFormat = DateFormat('yyyy-MM-dd');

  TechnicalDictionaryData? _data;
  Map<String, TermProgress> _progress = const {};
  DailyWordOptions? _options;
  TechnicalTerm? _current;
  bool _applying = false;
  bool _failed = false;
  bool _disposed = false;

  TechnicalTerm? get current => _current;

  /// Áp dụng cài đặt: lần đầu thì nạp từ điển và lấy lại từ đang có; cài đặt
  /// đổi mà từ hiện tại không còn hợp thì chọn từ mới.
  Future<void> apply(DailyWordOptions options) async {
    // Gọi lại mỗi lần thẻ dựng lại: cùng cài đặt mà đã có từ (hoặc đang nạp)
    // thì thôi.
    if (options == _options && (_current != null || _applying || _failed)) {
      return;
    }
    _options = options;
    _applying = true;
    _failed = false;
    try {
      _data ??= await _repository.loadDictionary();
      await _reloadProgress();
      if (_options != options) return; // Cài đặt đã đổi tiếp trong lúc chờ.
      final prefs = await _prefs();
      final saved = _savedKey(prefs, options.mode);
      final term = saved == null ? null : _byKey(saved);
      if (term != null && _fits(term, options)) {
        _setCurrent(term);
      } else {
        await _pickNew(prefs, options);
      }
    } catch (e, stack) {
      // Không nạp được (VD thiếu database trên nền tảng lạ): ẩn thẻ, không
      // làm hỏng trang chủ.
      debugPrint('Từ vựng hôm nay: $e\n$stack');
      _failed = true;
    } finally {
      if (_options == options) _applying = false;
    }
  }

  /// Nút "Từ khác".
  Future<void> next() async {
    final options = _options;
    if (options == null || _data == null) return;
    await _reloadProgress();
    await _pickNew(await _prefs(), options, exclude: _current?.key);
  }

  /// Menu "Đã thuộc từ này": đánh dấu rồi chuyển sang từ khác.
  Future<void> markLearned() async {
    final term = _current;
    if (term == null) return;
    final note = _progress[term.key]?.note ?? '';
    await _repository.saveProgress(
      term.key,
      TermProgress(status: TermStatus.learned, note: note),
    );
    await next();
  }

  Future<void> _reloadProgress() async {
    try {
      _progress = await _repository.loadProgress();
    } catch (e) {
      // Chưa có trạng thái học vẫn chọn được từ.
      debugPrint('Từ vựng hôm nay: không đọc được tiến độ học: $e');
    }
  }

  String? _savedKey(SharedPreferences prefs, DailyWordMode mode) {
    switch (mode) {
      case DailyWordMode.perLaunch:
        return _launchWord;
      case DailyWordMode.perDay:
        final saved = prefs.getString(todayKey);
        if (saved == null) return null;
        final separator = saved.indexOf('|');
        if (separator < 0) return null;
        return saved.substring(0, separator) == _today()
            ? saved.substring(separator + 1)
            : null;
    }
  }

  Future<void> _pickNew(
    SharedPreferences prefs,
    DailyWordOptions options, {
    String? exclude,
  }) async {
    final history = prefs.getStringList(historyKey) ?? const <String>[];
    final term = DailyWordPicker.pick(
      terms: _data!.terms,
      statusOf: (t) => _progress[t.key]?.status,
      groups: options.groups,
      reviewLearned: options.reviewLearned,
      random: _random,
      recent: history,
      exclude: exclude,
    );
    if (term == null) return;
    _setCurrent(term);
    final updated = [...history.where((k) => k != term.key), term.key];
    await Future.wait([
      prefs.setStringList(
        historyKey,
        updated.sublist(max(0, updated.length - DailyWordPicker.historySize)),
      ),
      if (options.mode == DailyWordMode.perDay)
        prefs.setString(todayKey, '${_today()}|${term.key}'),
    ]);
  }

  bool _fits(TechnicalTerm term, DailyWordOptions options) =>
      options.groups.isEmpty || options.groups.contains(term.group);

  TechnicalTerm? _byKey(String key) =>
      _data!.terms.where((t) => t.key == key).firstOrNull;

  String _today() => _dayFormat.format(_now());

  void _setCurrent(TechnicalTerm term) {
    _current = term;
    // Nhớ cho cả lần mở app này: đổi sang chế độ "mỗi lần mở app" vẫn giữ từ
    // đang hiện thay vì đổi ngay.
    _launchWord = term.key;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
