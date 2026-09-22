import 'package:flutter/material.dart';

import '../../models/daily_goal.dart';

/// Hộp thoại xác nhận trước khi tick hoàn thành/bỏ hoàn thành một mục tiêu —
/// tránh trường hợp bấm nhầm khi các dòng mục tiêu hiển thị khá sát nhau.
Future<bool> confirmToggleGoal(BuildContext context, DailyGoal goal) async {
  final markingDone = !goal.isCompleted;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        markingDone ? 'Hoàn thành mục tiêu?' : 'Bỏ đánh dấu hoàn thành?',
      ),
      content: Text(
        markingDone
            ? '"${goal.title}" sẽ được đánh dấu là đã hoàn thành.'
            : '"${goal.title}" sẽ được chuyển về trạng thái chưa hoàn thành.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
