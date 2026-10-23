import 'dart:math';

import '../models/technical_term.dart';

/// Chọn từ cho thẻ "Từ vựng hôm nay": ngẫu nhiên nhưng có chủ đích.
///
/// - Chỉ lấy trong [groups] (rỗng = mọi nhóm).
/// - Ưu tiên từ đang học (khoảng một nửa số lần, nếu có), còn lại là từ chưa
///   học. Từ đã thuộc chỉ hiện lại để ôn với xác suất [reviewChance] khi
///   [reviewLearned] bật.
/// - Tránh các từ trong [recent] (mới gặp gần đây) và [exclude] (từ đang hiện).
abstract final class DailyWordPicker {
  static const learningChance = 0.5;
  static const reviewChance = 0.1;

  /// Số từ gần nhất cần tránh lặp lại.
  static const historySize = 60;

  static TechnicalTerm? pick({
    required List<TechnicalTerm> terms,
    required TermStatus? Function(TechnicalTerm term) statusOf,
    required Set<String> groups,
    required bool reviewLearned,
    required Random random,
    List<String> recent = const [],
    String? exclude,
  }) {
    var pool = [
      for (final term in terms)
        if (groups.isEmpty || groups.contains(term.group)) term,
    ];
    // Nhóm đã chọn không còn trong từ điển: lấy mọi nhóm thay vì để trống.
    if (pool.isEmpty) pool = terms;
    if (pool.isEmpty) return null;

    final learning = <TechnicalTerm>[];
    final notStarted = <TechnicalTerm>[];
    final learned = <TechnicalTerm>[];
    for (final term in pool) {
      switch (statusOf(term)) {
        case TermStatus.learning:
          learning.add(term);
        case TermStatus.learned:
          learned.add(term);
        case null:
          notStarted.add(term);
      }
    }

    // Nhóm ít từ thì nhớ ít lại, để vẫn còn từ mà chọn.
    final avoid = {
      ...recent.reversed.take(min(historySize, pool.length ~/ 2)),
      ?exclude,
    };
    List<TechnicalTerm> fresh(List<TechnicalTerm> list) =>
        list.where((t) => !avoid.contains(t.key)).toList();

    final ordered = <List<TechnicalTerm>>[
      if (reviewLearned && random.nextDouble() < reviewChance) fresh(learned),
      if (random.nextDouble() < learningChance) fresh(learning),
      fresh(notStarted),
      fresh(learning),
      if (reviewLearned) fresh(learned),
      // Đã gặp hết: chấp nhận lặp, chỉ tránh đúng từ đang hiện.
      [
        for (final t in pool)
          if (t.key != exclude && (reviewLearned || statusOf(t) != TermStatus.learned)) t,
      ],
      [for (final t in pool) if (t.key != exclude) t],
      pool,
    ];
    final candidates = ordered.firstWhere((list) => list.isNotEmpty);
    return candidates[random.nextInt(candidates.length)];
  }
}
