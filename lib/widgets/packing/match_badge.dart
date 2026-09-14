/// Badge hiển thị mức độ phù hợp của máy: BEST MATCH / SUITABLE / OVERSIZED / NOT SUITABLE.
library;

import 'package:flutter/material.dart';

import '../../models/machine_match_result.dart';

class MatchBadge extends StatelessWidget {
  final MatchLevel level;
  final bool showStars;
  final bool compact; // Hiển thị dạng nhỏ gọn

  const MatchBadge({
    super.key,
    required this.level,
    this.showStars = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _levelColors(context, level);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          level.labelVi,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stars
          if (showStars) ...[
            _StarRating(count: level.starCount, color: colors.foreground),
            const SizedBox(height: 4),
          ],

          // Label
          Text(
            level.labelVi,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colors.foreground,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  _LevelColors _levelColors(BuildContext context, MatchLevel level) {
    switch (level) {
      case MatchLevel.bestMatch:
        return _LevelColors(
          background: Colors.green.shade50,
          foreground: Colors.green.shade800,
          border: Colors.green.shade200,
        );
      case MatchLevel.suitable:
        return _LevelColors(
          background: Colors.blue.shade50,
          foreground: Colors.blue.shade800,
          border: Colors.blue.shade200,
        );
      case MatchLevel.oversized:
        return _LevelColors(
          background: Colors.orange.shade50,
          foreground: Colors.orange.shade800,
          border: Colors.orange.shade200,
        );
      case MatchLevel.notSuitable:
        return _LevelColors(
          background: Colors.red.shade50,
          foreground: Colors.red.shade800,
          border: Colors.red.shade200,
        );
    }
  }
}

class _LevelColors {
  final Color background;
  final Color foreground;
  final Color border;

  const _LevelColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

class _StarRating extends StatelessWidget {
  final int count;
  final Color color;

  const _StarRating({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < count ? Icons.star : Icons.star_outline,
          size: 14,
          color: color,
        );
      }),
    );
  }
}

/// Widget hiển thị lý do phù hợp/không phù hợp
class MatchReasonsList extends StatelessWidget {
  final List<String> matchReasons;
  final List<String> mismatchReasons;

  const MatchReasonsList({
    super.key,
    required this.matchReasons,
    required this.mismatchReasons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...matchReasons.map(
          (reason) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        ...mismatchReasons.map(
          (reason) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
